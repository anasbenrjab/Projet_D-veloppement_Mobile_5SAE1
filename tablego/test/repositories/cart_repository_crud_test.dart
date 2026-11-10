// CartRepository (Module 2) — cart_items: create (add), read (per client and
// restaurant), update (quantity), delete (remove / clear); constraints.

import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/features/commande/data/repositories/cart_repository.dart';

import 'support.dart';

void main() {
  setUpAll(initFfi);

  late TestDb t;
  late CartRepository repo;
  late int clientId, otherClient, restaurantId, otherRestaurantId;
  late int tajine, soupe, burger;

  setUp(() async {
    t = await TestDb.open();
    repo = CartRepository(t.helper);
    clientId = await t.client('c@test.com');
    otherClient = await t.client('d@test.com');
    (_, restaurantId) = await t.restaurant('r@test.com', 'R');
    (_, otherRestaurantId) = await t.restaurant('r2@test.com', 'R2');
    tajine = await t.dish(restaurantId, 'Tajine', price: 20);
    soupe = await t.dish(restaurantId, 'Soupe', price: 8);
    burger = await t.dish(otherRestaurantId, 'Burger', price: 12);
  });

  Future<int> count(int user, int restaurant) =>
      repo.getCartCount(userId: user, restaurantId: restaurant);

  test('create: adding a dish twice increments its quantity', () async {
    await repo.addToCart(userId: clientId, dishId: tajine);
    await repo.addToCart(userId: clientId, dishId: tajine);
    await repo.addToCart(userId: clientId, dishId: soupe);
    final items =
        await repo.getCartItems(userId: clientId, restaurantId: restaurantId);
    expect({for (final i in items) i.dish!.name: i.quantity},
        {'Tajine': 2, 'Soupe': 1});
    expect(items.fold<double>(0, (s, i) => s + i.subtotal), 48);
    expect(await count(clientId, restaurantId), 3);
  });

  test('read: one cart per client and per restaurant', () async {
    await repo.addToCart(userId: clientId, dishId: tajine);
    await repo.addToCart(userId: clientId, dishId: burger);
    await repo.addToCart(userId: otherClient, dishId: soupe);
    expect((await repo.getCartItems(
            userId: clientId, restaurantId: restaurantId))
        .map((i) => i.dish!.name), ['Tajine']);
    expect((await repo.getCartItems(
            userId: clientId, restaurantId: otherRestaurantId))
        .map((i) => i.dish!.name), ['Burger']);
    expect(await repo.getCartItemByDishId(userId: otherClient, dishId: tajine),
        isNull);
  });

  test('update: set quantity; 0 or less removes the line', () async {
    await repo.addToCart(userId: clientId, dishId: tajine);
    final line =
        (await repo.getCartItemByDishId(userId: clientId, dishId: tajine))!;
    await repo.updateQuantity(line.id!, 5);
    expect(await count(clientId, restaurantId), 5);
    await repo.updateQuantity(line.id!, 0);
    expect(await count(clientId, restaurantId), 0);
  });

  test('delete: remove one line; clear empties only that restaurant',
      () async {
    await repo.addToCart(userId: clientId, dishId: tajine);
    await repo.addToCart(userId: clientId, dishId: soupe);
    await repo.addToCart(userId: clientId, dishId: burger);
    await repo.addToCart(userId: otherClient, dishId: tajine);

    final soupeLine =
        (await repo.getCartItemByDishId(userId: clientId, dishId: soupe))!;
    await repo.removeFromCart(soupeLine.id!);
    expect(await count(clientId, restaurantId), 1);

    await repo.clearCart(userId: clientId, restaurantId: restaurantId);
    expect(await count(clientId, restaurantId), 0);
    expect(await count(clientId, otherRestaurantId), 1); // other restaurant
    expect(await count(otherClient, restaurantId), 1); // other client
  });

  group('constraints', () {
    test('unknown dish or user → foreign key error', () async {
      expect(repo.addToCart(userId: clientId, dishId: 999), throwsConstraint);
      expect(repo.addToCart(userId: 999, dishId: tajine), throwsConstraint);
    });

    test('one line per (user, dish); quantity must be > 0', () async {
      await t.db.insert('cart_items', {'user_id': clientId, 'dish_id': tajine});
      expect(t.db.insert('cart_items', {'user_id': clientId, 'dish_id': tajine}),
          throwsConstraint);
      expect(
          t.db.insert('cart_items',
              {'user_id': clientId, 'dish_id': soupe, 'quantity': 0}),
          throwsConstraint);
    });

    test('a deleted dish leaves the cart (cascade)', () async {
      await repo.addToCart(userId: clientId, dishId: tajine);
      await t.db.delete('dishes', where: 'id = ?', whereArgs: [tajine]);
      expect(await count(clientId, restaurantId), 0);
    });
  });
}
