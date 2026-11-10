// OrderRepository (Module 2) — orders + order_items: create (one
// transaction), read (per client, per restaurant, by status, by id), update
// (status); rollback, constraints, cascades and the order_history view.

import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/core/data/validation_exception.dart';
import 'package:tablego/features/commande/data/models/cart_item_model.dart';
import 'package:tablego/features/commande/data/models/order_model.dart';
import 'package:tablego/features/commande/data/repositories/cart_repository.dart';
import 'package:tablego/features/commande/data/repositories/order_repository.dart';

import 'support.dart';

void main() {
  setUpAll(initFfi);

  late TestDb t;
  late OrderRepository repo;
  late CartRepository cart;
  late int alice, bob, ownerId, restaurantId, otherRestaurantId;
  late int tajine, soupe;

  setUp(() async {
    t = await TestDb.open();
    repo = OrderRepository(t.helper);
    cart = CartRepository(t.helper);
    alice = await t.client('alice@test.com');
    bob = await t.client('bob@test.com');
    (ownerId, restaurantId) = await t.restaurant('r@test.com', 'R');
    (_, otherRestaurantId) = await t.restaurant('r2@test.com', 'R2');
    tajine = await t.dish(restaurantId, 'Tajine', price: 20);
    soupe = await t.dish(restaurantId, 'Soupe', price: 8);
  });

  Future<OrderModel> order(int user,
      {List<int>? dishes, String type = OrderType.dineIn}) async {
    for (final d in dishes ?? [tajine]) {
      await cart.addToCart(userId: user, dishId: d);
    }
    return repo.placeOrder(
      userId: user,
      restaurantId: restaurantId,
      cartItems:
          await cart.getCartItems(userId: user, restaurantId: restaurantId),
      orderType: type,
      note: 'sans oignons',
      clientName: 'Client $user',
    );
  }

  group('create (placeOrder)', () {
    test('order + one line per cart item, total, cart emptied', () async {
      final o = await order(alice, dishes: [tajine, tajine, soupe]);
      expect(o.totalPrice, 48);
      final stored = (await repo.getOrderById(o.id!))!;
      expect(stored.userId, alice);
      expect(stored.restaurantId, restaurantId);
      expect(stored.status, OrderStatus.received);
      expect(stored.note, 'sans oignons');
      expect({for (final i in stored.items) i.dishName: i.quantity},
          {'Tajine': 2, 'Soupe': 1});
      expect(await cart.getCartCount(userId: alice, restaurantId: restaurantId),
          0);
    });

    test('empty cart → error, nothing written', () async {
      await expectLater(
          repo.placeOrder(userId: alice, restaurantId: restaurantId,
              cartItems: const [], orderType: OrderType.dineIn),
          throwsA(isA<StateError>()));
      expect(await t.count('orders'), 0);
    });

    test('a failing line rolls the whole order back (transaction)', () async {
      await cart.addToCart(userId: alice, dishId: tajine);
      final items =
          await cart.getCartItems(userId: alice, restaurantId: restaurantId);
      final broken = [
        ...items,
        CartItemModel(dishId: 999, addedAt: DateTime.now()), // no such dish
      ];
      await expectLater(
          repo.placeOrder(userId: alice, restaurantId: restaurantId,
              cartItems: broken, orderType: OrderType.dineIn),
          throwsConstraint);
      expect(await t.count('orders'), 0);
      expect(await t.count('order_items'), 0);
      expect(await cart.getCartCount(userId: alice, restaurantId: restaurantId),
          1); // cart kept
    });

    test('unknown client or restaurant → foreign key error', () async {
      await cart.addToCart(userId: alice, dishId: tajine);
      final items =
          await cart.getCartItems(userId: alice, restaurantId: restaurantId);
      await expectLater(
          repo.placeOrder(userId: 999, restaurantId: restaurantId,
              cartItems: items, orderType: OrderType.dineIn),
          throwsConstraint);
      await expectLater(
          repo.placeOrder(userId: alice, restaurantId: 999,
              cartItems: items, orderType: OrderType.dineIn),
          throwsConstraint);
      expect(await t.count('orders'), 0);
    });
  });

  group('read', () {
    test('per client (all restaurants) and per restaurant', () async {
      final a = await order(alice);
      await order(bob, type: OrderType.takeaway);
      expect((await repo.getClientOrders(userId: alice)).single.id, a.id);
      expect((await repo.getAllOrders(restaurantId: restaurantId))
          .map((o) => o.userId).toSet(), {alice, bob});
      expect(await repo.getAllOrders(restaurantId: otherRestaurantId), isEmpty);
      expect(await repo.restaurantIdForUser(ownerId), restaurantId);
      expect(await repo.getOrderById(999), isNull);
    });

    test('order_history view: one row per order line, read-only', () async {
      await order(alice, dishes: [tajine, soupe]);
      final rows = await t.db.query('order_history');
      expect(rows.map((r) => r['dish_id']).toSet(), {tajine, soupe});
      expect(rows.every((r) => r['user_id'] == alice), isTrue);
      expect(
          t.db.insert('order_history', {'user_id': alice,
              'restaurant_id': restaurantId}),
          throwsA(isA<DatabaseException>())); // a view cannot be written
    });
  });

  group('update (status)', () {
    test('advance: reçue → en préparation → prête, then stays', () async {
      final o = await order(alice);
      for (final expected in [
        OrderStatus.preparing, OrderStatus.ready, OrderStatus.ready,
      ]) {
        await repo.advanceStatus(o.id!);
        expect((await repo.getOrderById(o.id!))!.status, expected);
      }
    });

    test('set a status; filter by status', () async {
      final o = await order(alice);
      await order(bob);
      await repo.updateStatus(o.id!, OrderStatus.ready);
      expect((await repo.getOrdersByStatus(OrderStatus.ready,
              restaurantId: restaurantId))
          .single
          .id, o.id);
      expect((await repo.getOrdersByStatus(OrderStatus.received,
              restaurantId: restaurantId))
          .single
          .userId, bob);
    });
  });

  group('delete (no repository method: cascades only)', () {
    test('deleting an order deletes its lines', () async {
      final o = await order(alice, dishes: [tajine, soupe]);
      await t.db.delete('orders', where: 'id = ?', whereArgs: [o.id]);
      expect(await t.count('order_items'), 0);
      expect(await t.count('order_history'), 0);
    });

    test('a quantity must be > 0', () async {
      final o = await order(alice);
      expect(
          t.db.insert('order_items', {'order_id': o.id, 'dish_id': tajine,
              'dish_name': 'T', 'dish_price': 1.0, 'quantity': 0}),
          throwsConstraint);
    });
  });

  group('safety rules', () {
    test('only reçue / en préparation / prête are accepted', () async {
      final o = await order(alice);
      for (final bad in ['livrée', 'READY', '', 'recue']) {
        await expectLater(repo.updateStatus(o.id!, bad),
            throwsA(isA<ValidationException>()), reason: bad);
      }
      expect((await repo.getOrderById(o.id!))!.status, OrderStatus.received);
      for (final ok in OrderStatus.all) {
        await repo.updateStatus(o.id!, ok);
        expect((await repo.getOrderById(o.id!))!.status, ok);
      }
    });
  });
}
