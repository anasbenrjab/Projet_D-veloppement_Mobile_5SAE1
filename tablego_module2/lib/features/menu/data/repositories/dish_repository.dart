import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../models/dish_model.dart';

class DishRepository {
  DishRepository(this._db);
  final DatabaseHelper _db;

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<DishModel>> getAllDishes({int restaurantId = 1}) async {
    final rows = await _db.query(
      'dishes',
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(DishModel.fromMap).toList();
  }

  Future<List<DishModel>> getAvailableDishes({int restaurantId = 1}) async {
    final rows = await _db.query(
      'dishes',
      where: 'restaurant_id = ? AND is_available = 1',
      whereArgs: [restaurantId],
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(DishModel.fromMap).toList();
  }

  Future<List<DishModel>> getDishesByCategory(String category,
      {int restaurantId = 1}) async {
    final rows = await _db.query(
      'dishes',
      where: 'restaurant_id = ? AND category = ? AND is_available = 1',
      whereArgs: [restaurantId, category],
      orderBy: 'name ASC',
    );
    return rows.map(DishModel.fromMap).toList();
  }

  Future<DishModel?> getDishById(int id) async {
    final rows = await _db.query('dishes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return DishModel.fromMap(rows.first);
  }

  Future<List<DishModel>> searchDishes(String query,
      {int restaurantId = 1}) async {
    final pattern = '%${query.toLowerCase()}%';
    final rows = await _db.rawQuery(
      '''SELECT * FROM dishes
         WHERE restaurant_id = ?
           AND is_available = 1
           AND (LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(category) LIKE ?)
         ORDER BY name ASC''',
      [restaurantId, pattern, pattern, pattern],
    );
    return rows.map(DishModel.fromMap).toList();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<DishModel> createDish(DishModel dish) async {
    final id = await _db.insert('dishes', dish.toMap());
    return dish.copyWith(id: id);
  }

  Future<DishModel> updateDish(DishModel dish) async {
    await _db.update(
      'dishes',
      dish.toMap(),
      where: 'id = ?',
      whereArgs: [dish.id],
    );
    return dish;
  }

  Future<void> toggleAvailability(int id, bool isAvailable) async {
    await _db.update(
      'dishes',
      {'is_available': isAvailable ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDish(int id) async {
    await _db.delete('dishes', where: 'id = ?', whereArgs: [id]);
  }
}

final dishRepositoryProvider = Provider<DishRepository>(
  (ref) => DishRepository(DatabaseHelper.instance),
);
