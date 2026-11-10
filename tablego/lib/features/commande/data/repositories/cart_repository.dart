import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../menu/data/models/dish_model.dart';
import '../models/cart_item_model.dart';

/// Cart of the logged-in client ([userId] = `users.id`), seen per restaurant:
/// each restaurant the client browses has its own cart, so an order always
/// goes to a single restaurant.
class CartRepository {
  CartRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;
  final DatabaseHelper _db;

  Future<Database> get _database => _db.database;

  Future<List<CartItemModel>> getCartItems({
    required int userId,
    required int restaurantId,
  }) async {
    // JOIN cart_items with dishes to get full dish data
    final rows = await (await _database).rawQuery(
      '''SELECT ci.id AS cart_id, ci.quantity, ci.added_at, d.*
         FROM cart_items ci
         INNER JOIN dishes d ON ci.dish_id = d.id
         WHERE ci.user_id = ? AND d.restaurant_id = ?
         ORDER BY ci.added_at ASC, ci.id ASC''',
      [userId, restaurantId],
    );

    return rows.map((row) {
      final dish = DishModel.fromMap(row);
      return CartItemModel(
        id: row['cart_id'] as int,
        dishId: dish.id!,
        quantity: row['quantity'] as int,
        addedAt: DateTime.parse(row['added_at'] as String),
        dish: dish,
      );
    }).toList();
  }

  Future<CartItemModel?> getCartItemByDishId({
    required int userId,
    required int dishId,
  }) async {
    final rows = await (await _database).query(
      'cart_items',
      where: 'user_id = ? AND dish_id = ?',
      whereArgs: [userId, dishId],
    );
    if (rows.isEmpty) return null;
    return CartItemModel.fromMap(rows.first);
  }

  Future<void> addToCart({required int userId, required int dishId}) async {
    final existing = await getCartItemByDishId(userId: userId, dishId: dishId);
    if (existing != null) {
      await updateQuantity(existing.id!, existing.quantity + 1);
    } else {
      await (await _database).insert('cart_items', {
        'user_id': userId,
        'dish_id': dishId,
        'quantity': 1,
        'added_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }
    await (await _database).update(
      'cart_items',
      {'quantity': quantity},
      where: 'id = ?',
      whereArgs: [cartItemId],
    );
  }

  Future<void> removeFromCart(int cartItemId) async {
    await (await _database).delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [cartItemId],
    );
  }

  /// Empties the client's cart for [restaurantId] only.
  Future<void> clearCart({
    required int userId,
    required int restaurantId,
  }) async {
    await clearCartIn(
      await _database,
      userId: userId,
      restaurantId: restaurantId,
    );
  }

  /// [clearCart] on any executor (used inside the checkout transaction).
  static Future<void> clearCartIn(
    DatabaseExecutor db, {
    required int userId,
    required int restaurantId,
  }) async {
    await db.delete(
      'cart_items',
      where:
          'user_id = ? AND dish_id IN '
          '(SELECT id FROM dishes WHERE restaurant_id = ?)',
      whereArgs: [userId, restaurantId],
    );
  }

  Future<int> getCartCount({
    required int userId,
    required int restaurantId,
  }) async {
    final rows = await (await _database).rawQuery(
      '''SELECT SUM(ci.quantity) AS total FROM cart_items ci
           JOIN dishes d ON d.id = ci.dish_id
           WHERE ci.user_id = ? AND d.restaurant_id = ?''',
      [userId, restaurantId],
    );
    final total = rows.first['total'];
    return total == null ? 0 : (total as num).toInt();
  }
}

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(),
);
