import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/favorites/data/models/restaurant_summary_model.dart';
import 'package:tablego/features/recommendations/data/repositories/recommendations_repository.dart';
import 'package:tablego/features/recommendations/domain/recommendation_service.dart';

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

// ── Helpers ───────────────────────────────────────────────────────────────────

RestaurantSummaryModel _resto(int id, String name) => RestaurantSummaryModel(
      id: id, name: name, address: '', cuisineType: '', favoritedAt: '');

DishForScoring _dish(int id, int restaurantId, List<String> tags) =>
    DishForScoring(
        id: id, restaurantId: restaurantId, name: 'Dish $id',
        price: 10, tags: tags);

// ── RecommendationService unit tests ─────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('RecommendationService.score', () {
    test('returns empty list when no restaurants', () {
      final result = RecommendationService.score(
        restaurants: [], allDishes: [], userPreferences: [],
        orderFrequency: {}, favoriteIds: {},
      );
      expect(result, isEmpty);
    });

    test('order frequency adds +3 per order', () {
      final restaurants = [_resto(1, 'A'), _resto(2, 'B')];
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: [],
        userPreferences: [], orderFrequency: {1: 3}, favoriteIds: {},
      );
      expect(result.first.restaurant.id, equals(1));
      expect(result.first.score, equals(9)); // 3 orders × 3
    });

    test('favorite adds +5', () {
      final restaurants = [_resto(1, 'A'), _resto(2, 'B')];
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: [],
        userPreferences: [], orderFrequency: {}, favoriteIds: {2},
      );
      expect(result.first.restaurant.id, equals(2));
      expect(result.first.score, equals(5));
    });

    test('tag match adds +2 per matching preference', () {
      final restaurants = [_resto(1, 'A')];
      final dishes = [_dish(1, 1, ['halal', 'vegan']), _dish(2, 1, ['halal'])];
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: dishes,
        userPreferences: ['halal', 'vegan'], orderFrequency: {},
        favoriteIds: {},
      );
      // dish1: halal(+2)+vegan(+2)=4 ; dish2: halal(+2)=2 → total 6
      expect(result.first.score, equals(6));
    });

    test('combined score: order + favorite + tags', () {
      final restaurants = [_resto(1, 'A'), _resto(2, 'B')];
      final dishes = [_dish(1, 1, ['halal'])];
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: dishes,
        userPreferences: ['halal'], orderFrequency: {1: 2},
        favoriteIds: {1},
      );
      // resto 1: 2×3=6 + 5 + 2 = 13
      expect(result.first.id, equals(1));
      expect(result.first.score, equals(13));
    });

    test('sorted descending by score', () {
      final restaurants = [_resto(1, 'Low'), _resto(2, 'High'), _resto(3, 'Mid')];
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: [],
        userPreferences: [], orderFrequency: {1: 0, 2: 5, 3: 2},
        favoriteIds: {},
      );
      expect(result.map((r) => r.restaurant.id).toList(), equals([2, 3, 1]));
    });

    test('returns max 10 results', () {
      final restaurants =
          List.generate(15, (i) => _resto(i + 1, 'R${i + 1}'));
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: [],
        userPreferences: [], orderFrequency: {}, favoriteIds: {},
      );
      expect(result.length, equals(10));
    });

    test('zero scores → sorted alphabetically by name', () {
      final restaurants = [_resto(3, 'Zebra'), _resto(1, 'Alpha'), _resto(2, 'Mango')];
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: [],
        userPreferences: [], orderFrequency: {}, favoriteIds: {},
      );
      expect(result.map((r) => r.restaurant.name).toList(),
          equals(['Alpha', 'Mango', 'Zebra']));
    });

    test('matchingDishes limited to 3', () {
      final restaurants = [_resto(1, 'A')];
      final dishes = List.generate(
          5, (i) => _dish(i + 1, 1, ['halal']));
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: dishes,
        userPreferences: ['halal'], orderFrequency: {}, favoriteIds: {},
      );
      expect(result.first.matchingDishes.length, equals(3));
    });

    test('no preference match → matchingDishes empty', () {
      final restaurants = [_resto(1, 'A')];
      final dishes = [_dish(1, 1, ['vegan'])];
      final result = RecommendationService.score(
        restaurants: restaurants, allDishes: dishes,
        userPreferences: ['halal'], orderFrequency: {}, favoriteIds: {},
      );
      expect(result.first.matchingDishes, isEmpty);
    });
  });

  // ── RecommendationsRepository integration test ────────────────────────────
  group('RecommendationsRepository', () {
    test('returns scored list from SQLite data', () async {
      final helper  = await buildTestDb();
      final storage = _FakeStorage();
      final auth    = AuthRepository(dbHelper: helper, storage: storage);
      final repo    = RecommendationsRepository(dbHelper: helper);
      final db      = await helper.database;

      // Register client with halal preference
      final client = await auth.register(
        email: 'c@reco.test', password: 'Password1!',
        userType: 'client', resetQuestion: 'Q?', resetAnswer: 'A',
      );
      await db.update(
        'client_profiles',
        {'dietary_preferences': '["halal"]'},
        where: 'user_id = ?', whereArgs: [client.id],
      );

      // Register restaurant
      final resto = await auth.register(
        email: 'r@reco.test', password: 'Password1!',
        userType: 'restaurant', resetQuestion: 'Q?', resetAnswer: 'A',
        restaurantName: 'Test Bistro',
      );
      final rpRows = await db.query('restaurant_profiles',
          columns: ['id'], where: 'user_id = ?', whereArgs: [resto.id],
          limit: 1);
      final rpId = rpRows.first['id'] as int;

      // Insert a halal-tagged dish
      await db.insert('dishes', {
        'restaurant_id': rpId, 'name': 'Halal Dish',
        'price': 12.0, 'is_available': 1, 'tags': '["halal"]',
      });

      // Add to order history
      await db.insert('order_history',
          {'user_id': client.id, 'restaurant_id': rpId});

      final results = await repo.getRecommendations(client.id);
      expect(results, isNotEmpty);
      expect(results.first.name, equals('Test Bistro'));
      // score: 1 order×3=3, 1 tag match×2=2 → 5
      expect(results.first.score, equals(5));
    });

    test('returns all restaurants alphabetically when user has no data', () async {
      final helper  = await buildTestDb();
      final storage = _FakeStorage();
      final auth    = AuthRepository(dbHelper: helper, storage: storage);
      final repo    = RecommendationsRepository(dbHelper: helper);
      final db      = await helper.database;

      final client = await auth.register(
        email: 'empty@reco.test', password: 'Password1!',
        userType: 'client', resetQuestion: 'Q?', resetAnswer: 'A',
      );

      // Two restaurants, no order history
      for (final name in ['Zara Bistro', 'Alpha Grill']) {
        final r = await auth.register(
          email: '${name.toLowerCase().replaceAll(' ', '')}@reco.test',
          password: 'Password1!', userType: 'restaurant',
          resetQuestion: 'Q?', resetAnswer: 'A',
          restaurantName: name,
        );
        final rpRows = await db.query('restaurant_profiles',
            columns: ['id'], where: 'user_id = ?',
            whereArgs: [r.id], limit: 1);
        // registered — no history or favorites needed for this test
      }

      final results = await repo.getRecommendations(client.id);
      expect(results.length, equals(2));
      expect(results.first.name, equals('Alpha Grill')); // alphabetical
    });
  });
}
