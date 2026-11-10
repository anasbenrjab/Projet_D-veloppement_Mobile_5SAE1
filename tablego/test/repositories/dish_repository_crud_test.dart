// DishRepository (Module 2) — dishes in the shared `dishes` table: create,
// read (by id, menu, available, category, search), update (incl. the edit
// form case), toggle, delete; FK constraints and cascades.

import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/core/data/validation_exception.dart';
import 'package:tablego/features/menu/data/models/dish_model.dart';
import 'package:tablego/features/menu/data/repositories/dish_repository.dart';

import 'support.dart';

void main() {
  setUpAll(initFfi);

  late TestDb t;
  late DishRepository repo;
  late int ownerId, restaurantId, otherRestaurantId;

  setUp(() async {
    t = await TestDb.open();
    repo = DishRepository(t.helper);
    (ownerId, restaurantId) = await t.restaurant('r@test.com', 'R');
    (_, otherRestaurantId) = await t.restaurant('r2@test.com', 'R2');
  });

  DishModel dish(String name,
          {int? restaurant,
          String category = 'Plat principal',
          double price = 12,
          bool available = true,
          String allergens = 'Gluten, Lait'}) =>
      DishModel(
        name: name,
        description: 'Desc $name',
        price: price,
        category: category,
        isAvailable: available,
        allergens: allergens,
        restaurantId: restaurant ?? restaurantId,
        createdAt: DateTime.utc(2026, 11, 1),
      );

  group('create', () {
    test('stores every column in the shared format', () async {
      final created = await repo.createDish(dish('Pizza'));
      expect(created.id, isNotNull);
      final row = (await t.db.query('dishes',
          where: 'id = ?', whereArgs: [created.id])).single;
      expect(row['restaurant_id'], restaurantId);
      expect(row['category'], 'Plat principal');
      expect(row['allergens'], '["gluten","lactose"]'); // normalised JSON
      expect(row['is_available'], 1);
    });

    test('allergens: "Aucun" → [] (declared none), "" → NULL (unknown)',
        () async {
      final none = await repo.createDish(dish('Eau', allergens: 'Aucun'));
      final unknown = await repo.createDish(dish('Mystère', allergens: ''));
      expect((await repo.getDishById(none.id!))!.allergens, 'Aucun');
      expect((await repo.getDishById(unknown.id!))!.allergens, '');
      final rows = await t.db.query('dishes',
          columns: ['allergens'], where: 'id = ?', whereArgs: [unknown.id]);
      expect(rows.single['allergens'], isNull);
    });

    test('unknown restaurant → foreign key error', () async {
      expect(repo.createDish(dish('X', restaurant: 999)), throwsConstraint);
    });
  });

  group('read', () {
    setUp(() async {
      await repo.createDish(dish('Soupe', category: 'Entrée'));
      await repo.createDish(dish('Couscous'));
      await repo.createDish(dish('Glace', category: 'Dessert',
          available: false));
      await repo.createDish(dish('Burger', restaurant: otherRestaurantId));
    });

    test('menu of one restaurant (all / available only)', () async {
      expect((await repo.getAllDishes(restaurantId: restaurantId))
          .map((d) => d.name), ['Glace', 'Soupe', 'Couscous']); // by category
      expect((await repo.getAvailableDishes(restaurantId: restaurantId))
          .map((d) => d.name), unorderedEquals(['Soupe', 'Couscous']));
    });

    test('by category, by id, search (name / description / category)',
        () async {
      expect((await repo.getDishesByCategory('Entrée',
              restaurantId: restaurantId))
          .single
          .name, 'Soupe');
      final couscous = (await repo.searchDishes('cous',
              restaurantId: restaurantId))
          .single;
      expect((await repo.getDishById(couscous.id!))!.name, 'Couscous');
      expect(await repo.searchDishes('burger', restaurantId: restaurantId),
          isEmpty); // other restaurant
      expect(await repo.searchDishes('glace', restaurantId: restaurantId),
          isEmpty); // unavailable
      expect(await repo.getDishById(999), isNull);
    });
  });

  group('update', () {
    test('changes the fields, keeps id / restaurant / created_at', () async {
      final d = await repo.createDish(dish('Tajine'));
      await repo.updateDish(d.copyWith(
          name: 'Tajine royal', price: 24.5, category: 'Spécialité',
          allergens: 'Aucun'));
      final row = (await t.db.query('dishes',
          where: 'id = ?', whereArgs: [d.id])).single;
      expect(row['name'], 'Tajine royal');
      expect(row['price'], 24.5);
      expect(row['category'], 'Spécialité');
      expect(row['allergens'], '[]');
      expect(row['restaurant_id'], restaurantId);
    });

    test('the edit form case: a dish rebuilt without its restaurant still '
        'updates (regression: restaurant_id = 0 hit the FK)', () async {
      final d = await repo.createDish(dish('Tajine'));
      await repo.updateDish(DishModel(
        id: d.id, name: 'Tajine 2', description: '', price: 1,
        category: 'Entrée', createdAt: DateTime.now(),
      ));
      final row = (await t.db.query('dishes',
          where: 'id = ?', whereArgs: [d.id])).single;
      expect(row['name'], 'Tajine 2');
      expect(row['restaurant_id'], restaurantId);
    });

    test('toggle availability', () async {
      final d = await repo.createDish(dish('Plat'));
      await repo.toggleAvailability(d.id!, false);
      expect((await repo.getDishById(d.id!))!.isAvailable, isFalse);
      expect(await repo.getAvailableDishes(restaurantId: restaurantId),
          isEmpty);
    });
  });

  group('delete', () {
    test('removes the dish, its cart lines and favorites; past orders keep '
        'their snapshot', () async {
      final d = await repo.createDish(dish('Plat', price: 9));
      final client = await t.client('c@test.com');
      await t.db.insert('cart_items', {'user_id': client, 'dish_id': d.id});
      await t.db.insert('favorite_dishes', {'user_id': client, 'dish_id': d.id});
      final orderId = await t.db.insert('orders', {
        'user_id': client, 'restaurant_id': restaurantId,
        'order_type': 'sur place',
      });
      await t.db.insert('order_items', {
        'order_id': orderId, 'dish_id': d.id, 'dish_name': 'Plat',
        'dish_price': 9.0,
      });

      await repo.deleteDish(d.id!);
      expect(await repo.getDishById(d.id!), isNull);
      expect(await t.count('cart_items'), 0);
      expect(await t.count('favorite_dishes'), 0);
      final line = (await t.db.query('order_items')).single;
      expect(line['dish_id'], isNull);
      expect(line['dish_name'], 'Plat');
    });

    test('deleting the restaurant deletes its menu', () async {
      await repo.createDish(dish('A'));
      await t.db.delete('restaurant_profiles',
          where: 'id = ?', whereArgs: [restaurantId]);
      expect(await repo.getAllDishes(restaurantId: restaurantId), isEmpty);
    });
  });

  test('restaurantIdForUser: owner → its restaurant, others → null',
      () async {
    expect(await repo.restaurantIdForUser(ownerId), restaurantId);
    expect(await repo.restaurantIdForUser(await t.client('c@test.com')),
        isNull);
  });

  test('NOT NULL columns are enforced by SQLite', () async {
    expect(t.db.insert('dishes', {'restaurant_id': restaurantId, 'price': 1}),
        throwsConstraint); // no name
  });

  group('safety rules', () {
    test('blank name or negative price → ValidationException, nothing '
        'written', () async {
      for (final bad in [
        dish('   '),
        dish(''),
        dish('Plat', price: -0.5),
        dish('Plat', price: double.nan),
      ]) {
        await expectLater(
            repo.createDish(bad), throwsA(isA<ValidationException>()));
      }
      expect(await t.count('dishes'), 0);
    });

    test('a free dish (price 0) is allowed', () async {
      expect((await repo.createDish(dish('Pain', price: 0))).id, isNotNull);
    });

    test('update refuses the same invalid data; the row is unchanged',
        () async {
      final d = await repo.createDish(dish('Tajine', price: 20));
      await expectLater(repo.updateDish(d.copyWith(name: ' ')),
          throwsA(isA<ValidationException>()));
      await expectLater(repo.updateDish(d.copyWith(price: -1)),
          throwsA(isA<ValidationException>()));
      final row = (await repo.getDishById(d.id!))!;
      expect(row.name, 'Tajine');
      expect(row.price, 20);
    });

    test('the message is French (shown as-is by the screens)', () async {
      await expectLater(
          repo.createDish(dish(' ')),
          throwsA(predicate(
              (e) => '$e' == 'Le nom du plat est obligatoire.')));
    });
  });
}
