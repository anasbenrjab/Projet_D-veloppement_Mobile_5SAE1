import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';

class OrderRepository {
  OrderRepository(this._db);
  final DatabaseHelper _db;

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<OrderModel> placeOrder({
    required List<CartItemModel> cartItems,
    required String orderType,
    String note = '',
    String clientName = 'Client',
    int restaurantId = 1,
  }) async {
    final total = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final now = DateTime.now();

    // Insert the order
    final orderId = await _db.insert('orders', {
      'order_type': orderType,
      'status': OrderStatus.received,
      'total_price': total,
      'note': note,
      'client_name': clientName,
      'restaurant_id': restaurantId,
      'created_at': now.toIso8601String(),
    });

    // Insert order items
    for (final item in cartItems) {
      await _db.insert('order_items', {
        'order_id': orderId,
        'dish_id': item.dishId,
        'dish_name': item.dish?.name ?? 'Plat supprimé',
        'dish_price': item.dish?.price ?? 0.0,
        'quantity': item.quantity,
      });
    }

    // Clear the cart
    await _db.delete('cart_items', where: '1', whereArgs: []);

    return OrderModel(
      id: orderId,
      orderType: orderType,
      status: OrderStatus.received,
      totalPrice: total,
      note: note,
      clientName: clientName,
      restaurantId: restaurantId,
      createdAt: now,
      items: cartItems
          .map((ci) => OrderItemModel(
                orderId: orderId,
                dishId: ci.dishId,
                dishName: ci.dish?.name ?? 'Plat supprimé',
                dishPrice: ci.dish?.price ?? 0.0,
                quantity: ci.quantity,
              ))
          .toList(),
    );
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<OrderModel>> getAllOrders({int restaurantId = 1}) async {
    final rows = await _db.query(
      'orders',
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
      orderBy: 'created_at DESC',
    );
    return _attachItems(rows);
  }

  Future<List<OrderModel>> getOrdersByStatus(String status,
      {int restaurantId = 1}) async {
    final rows = await _db.query(
      'orders',
      where: 'restaurant_id = ? AND status = ?',
      whereArgs: [restaurantId, status],
      orderBy: 'created_at DESC',
    );
    return _attachItems(rows);
  }

  Future<OrderModel?> getOrderById(int id) async {
    final rows =
        await _db.query('orders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final orders = await _attachItems(rows);
    return orders.first;
  }

  Future<List<OrderModel>> _attachItems(
      List<Map<String, dynamic>> orderRows) async {
    final result = <OrderModel>[];
    for (final row in orderRows) {
      final orderId = row['id'] as int;
      final itemRows = await _db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      final items = itemRows.map(OrderItemModel.fromMap).toList();
      result.add(OrderModel.fromMap(row, items: items));
    }
    return result;
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  Future<void> updateStatus(int orderId, String newStatus) async {
    await _db.update(
      'orders',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> advanceStatus(int orderId) async {
    final order = await getOrderById(orderId);
    if (order == null) return;
    final next = OrderStatus.nextStatus(order.status);
    await updateStatus(orderId, next);
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(DatabaseHelper.instance),
);
