import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/recommendation_service.dart';
import '../../../favorites/data/models/restaurant_summary_model.dart';
import '../../../profile/data/models/restaurant_profile_model.dart';

class RecommendationsRepository {
  RecommendationsRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;
  Future<Database> get _database => _db.database;

  Future<List<ScoredRestaurant>> getRecommendations(int userId) async {
    final db = await _database;

    // 1. User dietary preferences
    final prefRows = await db.query(
      'client_profiles',
      columns: ['dietary_preferences'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    final prefRaw = prefRows.isNotEmpty
        ? prefRows.first['dietary_preferences']
        : null;
    final prefs = RestaurantProfileModel.decodeList(prefRaw);

    // 2. Order history frequencies: restaurantId → count
    final historyRows = await db.rawQuery(
      '''
      SELECT restaurant_id, COUNT(*) AS order_count
        FROM order_history
       WHERE user_id = ?
       GROUP BY restaurant_id
      ''',
      [userId],
    );
    final orderFreq = <int, int>{};
    for (final r in historyRows) {
      orderFreq[r['restaurant_id'] as int] = r['order_count'] as int;
    }

    // 3. Favorite restaurant ids
    final favRows = await db.query(
      'favorite_restaurants',
      columns: ['restaurant_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final favIds = favRows.map((r) => r['restaurant_id'] as int).toSet();

    // 4. All active restaurants (same SELECT as backend)
    final restRows = await db.rawQuery(
      '''
      SELECT rp.id, rp.name, rp.address, rp.latitude, rp.longitude,
             rp.cuisine_type, rp.photo_paths, rp.description,
             rp.opening_hours,
             '' AS favorited_at
        FROM restaurant_profiles rp
        JOIN users u ON u.id = rp.user_id AND u.is_active = 1
      ''',
    );
    final restaurants = restRows
        .map((r) =>
            RestaurantSummaryModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();

    // 5. All available dishes
    final dishRows = await db.query(
      'dishes',
      columns: ['id', 'restaurant_id', 'name', 'price', 'photo_path', 'tags'],
      where: 'is_available = 1',
    );
    final dishes = dishRows.map((r) {
      final map = Map<String, dynamic>.from(r);
      return DishForScoring(
        id:           map['id']           as int,
        restaurantId: map['restaurant_id'] as int,
        name:         (map['name']        as String?) ?? '',
        price:        _toDouble(map['price']),
        photoPath:    map['photo_path']   as String?,
        tags:         RestaurantProfileModel.decodeList(map['tags']),
      );
    }).toList();

    return RecommendationService.score(
      restaurants:    restaurants,
      allDishes:      dishes,
      userPreferences: prefs,
      orderFrequency: orderFreq,
      favoriteIds:    favIds,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

final recommendationsRepositoryProvider =
    Provider<RecommendationsRepository>((_) => RecommendationsRepository());
