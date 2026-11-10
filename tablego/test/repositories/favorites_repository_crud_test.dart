// FavoritesRepository — favorite restaurants and dishes: create (add),
// read, delete (remove); idempotence, FK constraints and cascades.

import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/features/favorites/data/repositories/favorites_repository.dart';
import 'package:tablego/features/favorites/domain/favorites_exception.dart';

import 'support.dart';

void main() {
  setUpAll(initFfi);

  late TestDb t;
  late FavoritesRepository repo;
  late int clientId, restaurantId, dishId;

  setUp(() async {
    t = await TestDb.open();
    repo = FavoritesRepository(dbHelper: t.helper);
    clientId = await t.client('c@test.com');
    (_, restaurantId) = await t.restaurant('r@test.com', 'Chez R');
    dishId = await t.dish(restaurantId, 'Tajine', price: 18);
  });

  group('favorite restaurants', () {
    test('add, read, remove', () async {
      await repo.addFavoriteRestaurant(clientId, restaurantId);
      final list = await repo.getFavoriteRestaurants(clientId);
      expect(list.single.id, restaurantId);
      expect(list.single.name, 'Chez R');

      await repo.removeFavoriteRestaurant(clientId, restaurantId);
      expect(await repo.getFavoriteRestaurants(clientId), isEmpty);
    });

    test('adding twice is a no-op; removing a missing favorite too', () async {
      await repo.addFavoriteRestaurant(clientId, restaurantId);
      await repo.addFavoriteRestaurant(clientId, restaurantId);
      expect(await t.count('favorite_restaurants'), 1);
      await repo.removeFavoriteRestaurant(clientId, 999);
      expect(await t.count('favorite_restaurants'), 1);
    });

    test('unknown restaurant → foreign key error', () async {
      expect(repo.addFavoriteRestaurant(clientId, 999), throwsConstraint);
    });

    test('deleting the restaurant removes it from favorites', () async {
      await repo.addFavoriteRestaurant(clientId, restaurantId);
      await t.db.delete('restaurant_profiles',
          where: 'id = ?', whereArgs: [restaurantId]);
      expect(await repo.getFavoriteRestaurants(clientId), isEmpty);
    });
  });

  group('favorite dishes', () {
    test('add, read (with restaurant name), remove', () async {
      await repo.addFavoriteDish(clientId, dishId);
      final list = await repo.getFavoriteDishes(clientId);
      expect(list.single.id, dishId);
      expect(list.single.name, 'Tajine');
      expect(list.single.price, 18);

      await repo.removeFavoriteDish(clientId, dishId);
      expect(await repo.getFavoriteDishes(clientId), isEmpty);
    });

    test('unknown dish → foreign key error', () async {
      expect(repo.addFavoriteDish(clientId, 999), throwsConstraint);
    });

    test('deleting the dish removes it from favorites (cascade)', () async {
      await repo.addFavoriteDish(clientId, dishId);
      await t.db.delete('dishes', where: 'id = ?', whereArgs: [dishId]);
      expect(await repo.getFavoriteDishes(clientId), isEmpty);
    });
  });

  group('who can have favorites', () {
    test('restaurant accounts, inactive and unknown users are refused',
        () async {
      final owner = await t.user('owner2@test.com', type: 'restaurant');
      final inactive = await t.user('old@test.com', active: false);
      for (final user in [owner, inactive, 999]) {
        await expectLater(repo.addFavoriteRestaurant(user, restaurantId),
            throwsA(isA<FavoritesException>()), reason: '$user');
        await expectLater(repo.getFavoriteDishes(user),
            throwsA(isA<FavoritesException>()), reason: '$user');
      }
      expect(await t.count('favorite_restaurants'), 0);
    });

    test('favorites are per client', () async {
      final other = await t.client('other@test.com');
      await repo.addFavoriteDish(clientId, dishId);
      expect(await repo.getFavoriteDishes(other), isEmpty);
    });
  });
}
