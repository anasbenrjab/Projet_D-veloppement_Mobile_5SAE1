import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/favorites/data/repositories/favorites_repository.dart';
import 'package:tablego/features/favorites/domain/favorites_exception.dart';

import '../auth/helpers/db_test_helper.dart';

// ── Fake storage ──────────────────────────────────────────────────────────────

class _FakeStorage extends Fake implements FlutterSecureStorage {
  final _m = <String, String>{};
  @override
  Future<void> write({required String key, required String? value,
      IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async =>
      value == null ? _m.remove(key) : _m[key] = value;
  @override
  Future<String?> read({required String key, IOSOptions? iOptions,
      AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async => _m[key];
  @override
  Future<void> delete({required String key, IOSOptions? iOptions,
      AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async => _m.remove(key);
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _q        = 'Question ?';
const _a        = 'Réponse';
const _password = 'SecurePass1!';

// ── Fixture helper ────────────────────────────────────────────────────────────

Future<({AuthRepository auth, FavoritesRepository favs, int clientId,
    int restaurantId, int rpId})>
    _buildFixture() async {
  final helper  = await buildTestDb();
  final storage = _FakeStorage();
  final auth    = AuthRepository(dbHelper: helper, storage: storage);
  final favs    = FavoritesRepository(dbHelper: helper);

  // Register client
  final client = await auth.register(
    email: 'client@fav.test', password: _password, userType: 'client',
    resetQuestion: _q, resetAnswer: _a,
  );

  // Register restaurant
  final resto = await auth.register(
    email: 'resto@fav.test', password: _password, userType: 'restaurant',
    resetQuestion: _q, resetAnswer: _a, restaurantName: 'Test Resto',
  );

  // Look up restaurant_profiles.id (not users.id)
  final db   = await helper.database;
  final rows = await db.query('restaurant_profiles',
      columns: ['id'], where: 'user_id = ?', whereArgs: [resto.id], limit: 1);
  final rpId = rows.first['id'] as int;

  return (
    auth: auth, favs: favs,
    clientId: client.id, restaurantId: resto.id, rpId: rpId,
  );
}

/// Insert a minimal dish row and return its id.
Future<int> _insertDish(AuthRepository auth, int rpId) async {
  final db = await auth.dbHelperForTesting.database;
  return db.insert('dishes', {
    'restaurant_id': rpId,
    'name':          'Test Dish',
    'price':         9.90,
    'is_available':  1,
    'tags':          '["halal"]',
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── Favorite restaurants ───────────────────────────────────────────────────
  group('FavoritesRepository — restaurants', () {
    test('add and list favorite restaurant', () async {
      final f = await _buildFixture();
      await f.favs.addFavoriteRestaurant(f.clientId, f.rpId);
      final list = await f.favs.getFavoriteRestaurants(f.clientId);
      expect(list.length, equals(1));
      expect(list.first.id, equals(f.rpId));
      expect(list.first.name, equals('Test Resto'));
    });

    test('remove favorite restaurant', () async {
      final f = await _buildFixture();
      await f.favs.addFavoriteRestaurant(f.clientId, f.rpId);
      await f.favs.removeFavoriteRestaurant(f.clientId, f.rpId);
      final list = await f.favs.getFavoriteRestaurants(f.clientId);
      expect(list, isEmpty);
    });

    test('duplicate add is ignored (no throw)', () async {
      final f = await _buildFixture();
      await f.favs.addFavoriteRestaurant(f.clientId, f.rpId);
      await expectLater(
        f.favs.addFavoriteRestaurant(f.clientId, f.rpId),
        completes,
      );
      final list = await f.favs.getFavoriteRestaurants(f.clientId);
      expect(list.length, equals(1)); // still only one entry
    });

    test('removing a non-favorite does not throw', () async {
      final f = await _buildFixture();
      await expectLater(
        f.favs.removeFavoriteRestaurant(f.clientId, f.rpId),
        completes,
      );
    });

    test('list JOIN returns correct restaurant name and address', () async {
      final f = await _buildFixture();
      await f.favs.addFavoriteRestaurant(f.clientId, f.rpId);
      final list = await f.favs.getFavoriteRestaurants(f.clientId);
      expect(list.first.name, equals('Test Resto'));
    });

    test('restaurant user cannot get favorite restaurants', () {
      expect(
        () async {
          final f = await _buildFixture();
          await f.favs.getFavoriteRestaurants(f.restaurantId);
        },
        throwsA(isA<FavoritesException>()),
      );
    });

    test('restaurant user cannot add favorite restaurant', () {
      expect(
        () async {
          final f = await _buildFixture();
          await f.favs.addFavoriteRestaurant(f.restaurantId, f.rpId);
        },
        throwsA(isA<FavoritesException>()),
      );
    });
  });

  // ── Favorite dishes ────────────────────────────────────────────────────────
  group('FavoritesRepository — dishes', () {
    test('add and list favorite dish', () async {
      final f      = await _buildFixture();
      final dishId = await _insertDish(f.auth, f.rpId);
      await f.favs.addFavoriteDish(f.clientId, dishId);
      final list = await f.favs.getFavoriteDishes(f.clientId);
      expect(list.length, equals(1));
      expect(list.first.id, equals(dishId));
      expect(list.first.name, equals('Test Dish'));
    });

    test('remove favorite dish', () async {
      final f      = await _buildFixture();
      final dishId = await _insertDish(f.auth, f.rpId);
      await f.favs.addFavoriteDish(f.clientId, dishId);
      await f.favs.removeFavoriteDish(f.clientId, dishId);
      final list = await f.favs.getFavoriteDishes(f.clientId);
      expect(list, isEmpty);
    });

    test('duplicate dish add is ignored', () async {
      final f      = await _buildFixture();
      final dishId = await _insertDish(f.auth, f.rpId);
      await f.favs.addFavoriteDish(f.clientId, dishId);
      await expectLater(
          f.favs.addFavoriteDish(f.clientId, dishId), completes);
      final list = await f.favs.getFavoriteDishes(f.clientId);
      expect(list.length, equals(1));
    });

    test('removing a non-favorite dish does not throw', () async {
      final f      = await _buildFixture();
      final dishId = await _insertDish(f.auth, f.rpId);
      await expectLater(
          f.favs.removeFavoriteDish(f.clientId, dishId), completes);
    });

    test('dish JOIN returns restaurant_name from restaurant_profiles', () async {
      final f      = await _buildFixture();
      final dishId = await _insertDish(f.auth, f.rpId);
      await f.favs.addFavoriteDish(f.clientId, dishId);
      final list = await f.favs.getFavoriteDishes(f.clientId);
      expect(list.first.restaurantName, equals('Test Resto'));
    });

    test('restaurant user cannot get favorite dishes', () {
      expect(
        () async {
          final f = await _buildFixture();
          await f.favs.getFavoriteDishes(f.restaurantId);
        },
        throwsA(isA<FavoritesException>()),
      );
    });
  });
}
