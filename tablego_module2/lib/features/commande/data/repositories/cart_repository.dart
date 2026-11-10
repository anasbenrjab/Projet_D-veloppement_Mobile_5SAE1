import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../menu/data/models/dish_model.dart';
import '../models/cart_item_model.dart';

class CartRepository {
  CartRepository(this._db);
  final DatabaseHelper _db;

  Future<List<CartItemModel>> getCartItems() async {
    // JOIN cart_items with dishes to get full dish data
    final rows = await _db.rawQuery(
      '''SELECT ci.id, ci.dish_id, ci.quantity, ci.added_at,
                d.name, d.description, d.price, d.category,
                d.image_path, d.is_available, d.allergens,
                d.restaurant_id, d.created_at as dish_created_at
         FROM cart_items ci
         INNER JOIN dishes d ON ci.dish_id = d.id
         ORDER BY ci.added_at ASC''',
      [],
    );

    return rows.map((row) {
      final dish = DishModel(
        id: row['dish_id'] as int,
        name: row['name'] as String,
        description: row['description'] as String? ?? '',
        price: (row['price'] as num).toDouble(),
        category: row['category'] as String,
        imagePath: row['image_path'] as String?,
        isAvailable: (row['is_available'] as int) == 1,
        allergens: row['allergens'] as String? ?? '',
        restaurantId: row['restaurant_id'] as int? ?? 1,
        createdAt: DateTime.parse(row['dish_created_at'] as String),
      );
      return CartItemModel(
        id: row['id'] as int,
        dishId: row['dish_id'] as int,
        quantity: row['quantity'] as int,
        addedAt: DateTime.parse(row['added_at'] as String),
        dish: dish,
      );
    }).toList();
  }

  Future<CartItemModel?> getCartItemByDishId(int dishId) async {
    final rows = await _db.query(
      'cart_items',
      where: 'dish_id = ?',
      whereArgs: [dishId],
    );
    if (rows.isEmpty) return null;
    return CartItemModel.fromMap(rows.first);
  }

  Future<void> addToCart(int dishId) async {
    final existing = await getCartItemByDishId(dishId);
    if (existing != null) {
      await updateQuantity(existing.id!, existing.quantity + 1);
    } else {
      await _db.insert('cart_items', {
        'dish_id': dishId,
        'quantity': 1,
        'added_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }
    await _db.update(
      'cart_items',
      {'quantity': quantity},
      where: 'id = ?',
      whereArgs: [cartItemId],
    );
  }

  Future<void> removeFromCart(int cartItemId) async {
    await _db.delete('cart_items', where: 'id = ?', whereArgs: [cartItemId]);
  }

  Future<void> clearCart() async {
    await _db.delete('cart_items', where: '1', whereArgs: []);
  }

  Future<int> getCartCount() async {
    final rows = await _db.rawQuery(
        'SELECT SUM(quantity) as total FROM cart_items', []);
    final total = rows.first['total'];
    return total == null ? 0 : (total as num).toInt();
  }
}

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(DatabaseHelper.instance),
);
