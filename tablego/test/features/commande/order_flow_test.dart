// Module 2 (menu + commande) on the shared TableGo database: dishes in the
// shared `dishes` table, carts per client and restaurant, orders as the
// single source of truth read by the recommender through the
// `order_history` view.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/features/commande/data/models/order_model.dart';
import 'package:tablego/features/commande/data/repositories/cart_repository.dart';
import 'package:tablego/features/commande/data/repositories/order_repository.dart';
import 'package:tablego/features/menu/data/models/dish_model.dart';
import 'package:tablego/features/menu/data/repositories/dish_repository.dart';
import 'package:tablego/features/recommendations/data/recommendation_data_source.dart';
import 'package:tablego/features/recommendations/domain/recommendation_models.dart';

import '../auth/helpers/db_test_helper.dart';

class _Fixture {
  _Fixture(this.helper, this.db);

  final DatabaseHelper helper;
  final Database db;
  late final int clientId, otherClientId, ownerId, restaurantId, otherRestoId;

  DishRepository get dishes => DishRepository(helper);
  CartRepository get cart => CartRepository(helper);
  OrderRepository get orders => OrderRepository(helper);

  static Future<_Fixture> create() async {
    final helper = await buildTestDb();
    final f = _Fixture(helper, await helper.database);
    Future<int> user(String email, String type) => f.db.insert('users', {
      'email': email,
      'password_hash': 'h',
      'salt': 's',
      'password_iterations': 1,
      'user_type': type,
    });
    f.clientId = await user('client@m2.test', 'client');
    f.otherClientId = await user('other@m2.test', 'client');
    f.ownerId = await user('resto@m2.test', 'restaurant');
    final otherOwner = await user('resto2@m2.test', 'restaurant');
    f.restaurantId = await f.db.insert('restaurant_profiles', {
      'user_id': f.ownerId,
      'name': 'Dar Test',
    });
    f.otherRestoId = await f.db.insert('restaurant_profiles', {
      'user_id': otherOwner,
      'name': 'Autre',
    });
    return f;
  }

  Future<DishModel> addDish(
    String name, {
    int? restaurant,
    double price = 10,
    String allergens = 'Aucun',
  }) => dishes.createDish(
    DishModel(
      name: name,
      description: '',
      price: price,
      category: 'Plat principal',
      allergens: allergens,
      restaurantId: restaurant ?? restaurantId,
      createdAt: DateTime.now(),
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DishModel ↔ shared dishes table', () {
    test('allergen labels are stored as the normalised JSON the recommender '
        'reads, and read back as labels', () async {
      expect(
        DishModel.allergensToDb('Gluten, Lait, Œuf'),
        '["gluten","lactose","oeufs"]',
      );
      expect(DishModel.allergensToDb('Aucun'), '[]');
      expect(DishModel.allergensToDb(''), isNull); // not declared
      expect(
        DishModel.allergensFromDb('["gluten","lactose"]'),
        'Gluten, Lactose',
      );
      expect(DishModel.allergensFromDb('[]'), 'Aucun');
      expect(DishModel.allergensFromDb(null), '');
    });

    test('a dish created by Module 2 is seen by the recommender', () async {
      final f = await _Fixture.create();
      final dish = await f.addDish('Couscous', allergens: 'Gluten, Lait');
      final row = (await f.db.query(
        'dishes',
        where: 'id = ?',
        whereArgs: [dish.id],
      )).single;
      expect(row['category'], 'Plat principal');
      expect(row['allergens'], '["gluten","lactose"]');

      final snapshot = await RecommendationDataSource(dbHelper: f.helper)
          .load(f.clientId);
      final seen = snapshot.dishes.singleWhere((d) => d.id == dish.id);
      expect(seen.allergens, {'gluten', 'lactose'});
      expect(seen.restaurantId, f.restaurantId);
    });

    test(
      'restaurantIdForUser maps the logged-in owner to its restaurant',
      () async {
        final f = await _Fixture.create();
        expect(await f.dishes.restaurantIdForUser(f.ownerId), f.restaurantId);
        expect(await f.dishes.restaurantIdForUser(f.clientId), isNull);
      },
    );
  });

  group('cart', () {
    test('is per client and per restaurant', () async {
      final f = await _Fixture.create();
      final a = await f.addDish('A');
      final b = await f.addDish('B', restaurant: f.otherRestoId);

      await f.cart.addToCart(userId: f.clientId, dishId: a.id!);
      await f.cart.addToCart(userId: f.clientId, dishId: a.id!);
      await f.cart.addToCart(userId: f.clientId, dishId: b.id!);
      await f.cart.addToCart(userId: f.otherClientId, dishId: a.id!);

      final mine = await f.cart.getCartItems(
        userId: f.clientId,
        restaurantId: f.restaurantId,
      );
      expect(mine.single.dishId, a.id);
      expect(mine.single.quantity, 2);
      expect(mine.single.dish!.name, 'A');
      expect(
        await f.cart.getCartCount(
          userId: f.clientId,
          restaurantId: f.otherRestoId,
        ),
        1,
      );
    });
  });

  group('orders', () {
    test('placeOrder stores the order and its lines and empties only that '
        "restaurant's cart", () async {
      final f = await _Fixture.create();
      final a = await f.addDish('A', price: 12.5);
      final b = await f.addDish('B', restaurant: f.otherRestoId);
      await f.cart.addToCart(userId: f.clientId, dishId: a.id!);
      await f.cart.addToCart(userId: f.clientId, dishId: a.id!);
      await f.cart.addToCart(userId: f.clientId, dishId: b.id!);

      final items = await f.cart.getCartItems(
        userId: f.clientId,
        restaurantId: f.restaurantId,
      );
      final order = await f.orders.placeOrder(
        userId: f.clientId,
        restaurantId: f.restaurantId,
        cartItems: items,
        orderType: OrderType.takeaway,
        clientName: 'Alice',
      );

      expect(order.totalPrice, 25.0);
      final stored = (await f.orders.getOrderById(order.id!))!;
      expect(stored.userId, f.clientId);
      expect(stored.status, OrderStatus.received);
      expect(stored.items.single.quantity, 2);
      expect(stored.items.single.dishName, 'A');
      expect(
        await f.cart.getCartCount(
          userId: f.clientId,
          restaurantId: f.restaurantId,
        ),
        0,
      );
      expect(
        await f.cart.getCartCount(
          userId: f.clientId,
          restaurantId: f.otherRestoId,
        ),
        1,
      );
    });

    test(
      'the client sees its orders, the restaurant the orders it received',
      () async {
        final f = await _Fixture.create();
        final a = await f.addDish('A');
        for (final user in [f.clientId, f.otherClientId]) {
          await f.cart.addToCart(userId: user, dishId: a.id!);
          await f.orders.placeOrder(
            userId: user,
            restaurantId: f.restaurantId,
            cartItems: await f.cart.getCartItems(
              userId: user,
              restaurantId: f.restaurantId,
            ),
            orderType: OrderType.dineIn,
          );
        }

        expect(
          await f.orders.getClientOrders(userId: f.clientId),
          hasLength(1),
        );
        final received = await f.orders.getAllOrders(
          restaurantId: f.restaurantId,
        );
        expect(received.map((o) => o.userId).toSet(), {
          f.clientId,
          f.otherClientId,
        });
        expect(
          await f.orders.getAllOrders(restaurantId: f.otherRestoId),
          isEmpty,
        );

        await f.orders.advanceStatus(received.first.id!);
        expect(
          (await f.orders.getOrderById(received.first.id!))!.status,
          OrderStatus.preparing,
        );
      },
    );

    test('deleting a dish keeps past orders readable', () async {
      final f = await _Fixture.create();
      final a = await f.addDish('A', price: 9);
      await f.cart.addToCart(userId: f.clientId, dishId: a.id!);
      final order = await f.orders.placeOrder(
        userId: f.clientId,
        restaurantId: f.restaurantId,
        cartItems: await f.cart.getCartItems(
          userId: f.clientId,
          restaurantId: f.restaurantId,
        ),
        orderType: OrderType.dineIn,
      );

      await f.dishes.deleteDish(a.id!);

      final line = (await f.orders.getOrderById(order.id!))!.items.single;
      expect(line.dishName, 'A');
      expect(line.dishPrice, 9);
    });

    test('the recommender sees an order placed through Module 2', () async {
      final f = await _Fixture.create();
      final a = await f.addDish('Tajine');
      await f.cart.addToCart(userId: f.clientId, dishId: a.id!);
      final order = await f.orders.placeOrder(
        userId: f.clientId,
        restaurantId: f.restaurantId,
        cartItems: await f.cart.getCartItems(
          userId: f.clientId,
          restaurantId: f.restaurantId,
        ),
        orderType: OrderType.dineIn,
      );

      final snapshot = await RecommendationDataSource(dbHelper: f.helper)
          .load(f.clientId);
      final orders = snapshot.interactions
          .where((i) => i.kind == InteractionKind.order)
          .toList();
      expect(orders, hasLength(1));
      expect(orders.single.userId, f.clientId);
      expect(orders.single.restaurantId, f.restaurantId);
      expect(orders.single.dishId, a.id);
      expect(
        orders.single.at?.toUtc(),
        DateTime.parse(
          (await f.db.query(
                'orders',
                where: 'id = ?',
                whereArgs: [order.id],
              )).single['created_at']!
              as String,
        ),
      );
    });
  });
}
