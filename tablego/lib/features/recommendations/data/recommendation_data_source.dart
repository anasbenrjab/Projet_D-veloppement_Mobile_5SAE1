import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../favorites/data/models/restaurant_summary_model.dart';
import '../../profile/data/uploaded_photos.dart';
import '../domain/food_labels.dart';
import '../domain/recommendation_models.dart';

/// The ONLY place the recommender reads data owned by other modules.
///
/// When Module 2 (Menu / Commande) is merged, only this class should need
/// to change.  The full contract, in French, is in
/// `docs/integration-recommandations.md`.
///
/// ## Contract
///
/// | Table                  | Columns read                                   |
/// |------------------------|------------------------------------------------|
/// | `client_profiles`      | `user_id`, `dietary_preferences`, `allergies`   |
/// | `restaurant_profiles`  | `id`, `user_id`, `name`, `address`, `latitude`, `longitude`, `cuisine_type`, `photo_paths`, `description`, `opening_hours` |
/// | `users`                | `id`, `user_type`, `is_active`                  |
/// | `dishes`               | `id`, `restaurant_id`, `name`, `description`, `price`, `photo_path`, `is_available`, `tags`, `allergens` |
/// | `order_history`        | `user_id`, `restaurant_id`, `dish_id`, `ordered_at` |
/// | `favorite_restaurants` | `user_id`, `restaurant_id`, `created_at`        |
/// | `favorite_dishes`      | `user_id`, `dish_id`, `created_at`              |
///
/// ## Formats
/// * `tags`, `allergens`, `dietary_preferences`, `allergies`: JSON arrays of
///   strings.  Values are normalised on read (`FoodLabels.canonical`), so
///   `"Végétarien"`, `"vegetarian"` and `"vegetarien"` are the same label.
/// * `dishes.allergens`: `NULL` = not declared (unsafe for clients with
///   allergies); `[]` = declared, no allergen.  A malformed value counts as
///   `NULL`.
/// * Dates: ISO-8601 (`2026-11-02T18:30:00Z`); unparsable dates count as
///   "now" (full weight).
/// * Only active `client` users' orders and favorites are read.
class RecommendationDataSource {
  RecommendationDataSource({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<RecommendationSnapshot> load(int userId) async {
    final db = await _db.database;
    return RecommendationSnapshot(
      profile: await _profile(db, userId),
      restaurants: await _restaurants(db),
      dishes: await _dishes(db),
      interactions: [
        ...await _orders(db),
        ...await _favoriteRestaurants(db),
        ...await _favoriteDishes(db),
      ],
    );
  }

  // ── Client profile ────────────────────────────────────────────────────────

  Future<RecoClientProfile> _profile(Database db, int userId) async {
    final rows = await db.query(
      'client_profiles',
      columns: ['dietary_preferences', 'allergies'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return RecoClientProfile(userId: userId);
    return RecoClientProfile(
      userId: userId,
      diets: _labels(rows.first['dietary_preferences']) ?? const {},
      allergens: _labels(rows.first['allergies']) ?? const {},
    );
  }

  // ── Restaurants ───────────────────────────────────────────────────────────

  Future<List<RestaurantSummaryModel>> _restaurants(Database db) async {
    final rows = await db.rawQuery('''
      SELECT rp.id, rp.user_id, rp.name, rp.address, rp.latitude,
             rp.longitude, rp.cuisine_type, rp.photo_paths, rp.description,
             rp.opening_hours,
             '' AS favorited_at
        FROM restaurant_profiles rp
        JOIN users u ON u.id = rp.user_id AND u.is_active = 1
    ''');
    // Include photos uploaded on web, which are not in `photo_paths`.
    final withUploads = await UploadedPhotos.withRestaurantUploads(db, rows);
    return withUploads.map(RestaurantSummaryModel.fromMap).toList();
  }

  // ── Dishes ────────────────────────────────────────────────────────────────

  Future<List<RecoDish>> _dishes(Database db) async {
    final rows = await db.query(
      'dishes',
      columns: [
        'id', 'restaurant_id', 'name', 'description', 'price', 'photo_path',
        'is_available', 'tags', 'allergens',
      ],
    );
    return [
      for (final r in rows)
        RecoDish(
          id: r['id']! as int,
          restaurantId: r['restaurant_id']! as int,
          name: (r['name'] as String?) ?? '',
          description: r['description'] as String?,
          price: _toDouble(r['price']),
          photoPath: r['photo_path'] as String?,
          isAvailable: r['is_available'] != 0,
          tags: _labels(r['tags']) ?? const {},
          allergens: _labels(r['allergens']),
        ),
    ];
  }

  // ── Interactions (all active clients) ─────────────────────────────────────

  static const _activeClient =
      "JOIN users u ON u.id = x.user_id AND u.user_type = 'client' "
      'AND u.is_active = 1';

  Future<List<RecoInteraction>> _orders(Database db) async {
    final rows = await db.rawQuery(
      'SELECT x.user_id, x.restaurant_id, x.dish_id, x.ordered_at '
      'FROM order_history x $_activeClient',
    );
    return [
      for (final r in rows)
        RecoInteraction(
          userId: r['user_id']! as int,
          kind: InteractionKind.order,
          restaurantId: r['restaurant_id'] as int?,
          dishId: r['dish_id'] as int?,
          at: _date(r['ordered_at']),
        ),
    ];
  }

  Future<List<RecoInteraction>> _favoriteRestaurants(Database db) async {
    final rows = await db.rawQuery(
      'SELECT x.user_id, x.restaurant_id, x.created_at '
      'FROM favorite_restaurants x $_activeClient',
    );
    return [
      for (final r in rows)
        RecoInteraction(
          userId: r['user_id']! as int,
          kind: InteractionKind.favoriteRestaurant,
          restaurantId: r['restaurant_id'] as int?,
          at: _date(r['created_at']),
        ),
    ];
  }

  Future<List<RecoInteraction>> _favoriteDishes(Database db) async {
    final rows = await db.rawQuery(
      'SELECT x.user_id, x.dish_id, x.created_at '
      'FROM favorite_dishes x $_activeClient',
    );
    return [
      for (final r in rows)
        RecoInteraction(
          userId: r['user_id']! as int,
          kind: InteractionKind.favoriteDish,
          dishId: r['dish_id'] as int?,
          at: _date(r['created_at']),
        ),
    ];
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Canonical labels from a JSON array, or null when the value is NULL or
  /// not a JSON array of strings.
  static Set<String>? _labels(Object? value) {
    if (value == null) return null;
    Object? decoded = value;
    if (value is String) {
      if (value.trim().isEmpty) return null;
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (decoded is! List) return null;
    return FoodLabels.canonicalSet(decoded.whereType<String>());
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static double _toDouble(Object? v) => switch (v) {
        double d => d,
        int i => i.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };
}
