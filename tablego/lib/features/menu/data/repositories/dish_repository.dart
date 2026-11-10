import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/data/current_restaurant.dart' as current;
import '../../../../core/data/validation_exception.dart';
import '../../../../core/database/database_helper.dart';
import '../models/dish_model.dart';

class DishRepository {
  DishRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;
  final DatabaseHelper _db;

  Future<Database> get _database => _db.database;

  /// `restaurant_profiles.id` of the logged-in restaurant user [userId].
  Future<int?> restaurantIdForUser(int userId) async =>
      current.restaurantIdForUser(await _database, userId);

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<DishModel>> getAllDishes({required int restaurantId}) async {
    final rows = await (await _database).query(
      'dishes',
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(DishModel.fromMap).toList();
  }

  Future<List<DishModel>> getAvailableDishes({
    required int restaurantId,
  }) async {
    final rows = await (await _database).query(
      'dishes',
      where: 'restaurant_id = ? AND is_available = 1',
      whereArgs: [restaurantId],
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(DishModel.fromMap).toList();
  }

  Future<List<DishModel>> getDishesByCategory(
    String category, {
    required int restaurantId,
  }) async {
    final rows = await (await _database).query(
      'dishes',
      where: 'restaurant_id = ? AND category = ? AND is_available = 1',
      whereArgs: [restaurantId, category],
      orderBy: 'name ASC',
    );
    return rows.map(DishModel.fromMap).toList();
  }

  Future<DishModel?> getDishById(int id) async {
    final rows = await (await _database).query(
      'dishes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return DishModel.fromMap(rows.first);
  }

  Future<List<DishModel>> searchDishes(
    String query, {
    required int restaurantId,
  }) async {
    final pattern = '%${query.toLowerCase()}%';
    final rows = await (await _database).rawQuery(
      '''SELECT * FROM dishes
         WHERE restaurant_id = ?
           AND is_available = 1
           AND (LOWER(name) LIKE ? OR LOWER(description) LIKE ?
                OR LOWER(category) LIKE ?)
         ORDER BY name ASC''',
      [restaurantId, pattern, pattern, pattern],
    );
    return rows.map(DishModel.fromMap).toList();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Safety rules (integration): a dish needs a name and a price >= 0.
  static void _validate(DishModel dish) {
    if (dish.name.trim().isEmpty) {
      throw const ValidationException('Le nom du plat est obligatoire.');
    }
    if (dish.price.isNaN || dish.price < 0) {
      throw const ValidationException(
          'Le prix du plat doit être positif ou nul.');
    }
  }

  Future<DishModel> createDish(DishModel dish) async {
    _validate(dish);
    final id = await (await _database).insert('dishes', dish.toMap());
    return dish.copyWith(id: id);
  }

  Future<DishModel> updateDish(DishModel dish) async {
    _validate(dish);
    // A dish never changes restaurant, and keeps its creation date.
    final map = dish.toMap()
      ..remove('id')
      ..remove('created_at')
      ..remove('restaurant_id');
    await (await _database).update(
      'dishes',
      map,
      where: 'id = ?',
      whereArgs: [dish.id],
    );
    return dish;
  }

  Future<void> toggleAvailability(int id, bool isAvailable) async {
    await (await _database).update(
      'dishes',
      {'is_available': isAvailable ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes the dish.  Past orders keep their name/price snapshot
  /// (`order_items.dish_id` becomes NULL); cart lines and favorites go.
  Future<void> deleteDish(int id) async {
    await (await _database).delete('dishes', where: 'id = ?', whereArgs: [id]);
  }
}

final dishRepositoryProvider = Provider<DishRepository>(
  (ref) => DishRepository(),
);
