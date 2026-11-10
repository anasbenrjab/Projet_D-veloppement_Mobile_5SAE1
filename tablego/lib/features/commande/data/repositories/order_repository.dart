import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/data/current_restaurant.dart' as current;
import '../../../../core/database/database_helper.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';
import 'cart_repository.dart';

/// Orders are the single source of truth for what clients ordered: the
/// recommender reads them through the `order_history` view
/// (see `MenuTables.replaceOrderHistoryWithView`).
class OrderRepository {
  OrderRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;
  final DatabaseHelper _db;

  Future<Database> get _database => _db.database;

  /// `restaurant_profiles.id` of the logged-in restaurant user [userId].
  Future<int?> restaurantIdForUser(int userId) async =>
      current.restaurantIdForUser(await _database, userId);

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Places the order of client [userId] at [restaurantId]: inserts the
  /// order and its lines, then empties that restaurant's cart — all in one
  /// transaction, so a failure leaves neither a half order nor a lost cart.
  Future<OrderModel> placeOrder({
    required int userId,
    required int restaurantId,
    required List<CartItemModel> cartItems,
    required String orderType,
    String note = '',
    String clientName = 'Client',
  }) async {
    if (cartItems.isEmpty) {
      throw StateError('Le panier est vide.');
    }
    final total = cartItems.fold<double>(0, (s, i) => s + i.subtotal);
    final now = DateTime.now();
    final items = <OrderItemModel>[];

    final orderId = await (await _database).transaction((txn) async {
      final orderId = await txn.insert('orders', {
        'user_id': userId,
        'order_type': orderType,
        'status': OrderStatus.received,
        'total_price': total,
        'note': note,
        'client_name': clientName,
        'restaurant_id': restaurantId,
        'created_at': now.toUtc().toIso8601String(),
      });

      for (final item in cartItems) {
        final line = OrderItemModel(
          orderId: orderId,
          dishId: item.dishId,
          dishName: item.dish?.name ?? 'Plat supprimé',
          dishPrice: item.dish?.price ?? 0.0,
          quantity: item.quantity,
        );
        await txn.insert('order_items', line.toMap());
        items.add(line);
      }

      await CartRepository.clearCartIn(
        txn,
        userId: userId,
        restaurantId: restaurantId,
      );
      return orderId;
    });

    return OrderModel(
      id: orderId,
      userId: userId,
      orderType: orderType,
      status: OrderStatus.received,
      totalPrice: total,
      note: note,
      clientName: clientName,
      restaurantId: restaurantId,
      createdAt: now,
      items: items,
    );
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Orders received by restaurant [restaurantId] (restaurant side).
  Future<List<OrderModel>> getAllOrders({required int restaurantId}) async {
    final rows = await (await _database).query(
      'orders',
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
      orderBy: 'created_at DESC, id DESC',
    );
    return _attachItems(rows);
  }

  /// Orders placed by client [userId], all restaurants (client side).
  Future<List<OrderModel>> getClientOrders({required int userId}) async {
    final rows = await (await _database).query(
      'orders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
    );
    return _attachItems(rows);
  }

  Future<List<OrderModel>> getOrdersByStatus(
    String status, {
    required int restaurantId,
  }) async {
    final rows = await (await _database).query(
      'orders',
      where: 'restaurant_id = ? AND status = ?',
      whereArgs: [restaurantId, status],
      orderBy: 'created_at DESC, id DESC',
    );
    return _attachItems(rows);
  }

  Future<OrderModel?> getOrderById(int id) async {
    final rows = await (await _database).query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final orders = await _attachItems(rows);
    return orders.first;
  }

  Future<List<OrderModel>> _attachItems(
    List<Map<String, dynamic>> orderRows,
  ) async {
    final db = await _database;
    final result = <OrderModel>[];
    for (final row in orderRows) {
      final orderId = row['id'] as int;
      final itemRows = await db.query(
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
    await (await _database).update(
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
  (ref) => OrderRepository(),
);
