import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/data/user_data_changes.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/favorites/data/repositories/favorites_repository.dart';
import 'package:tablego/features/favorites/providers/favorites_provider.dart';
import 'package:tablego/features/profile/data/repositories/profile_repository.dart';
import 'package:tablego/features/profile/providers/profile_provider.dart';
import 'package:tablego/features/recommendations/data/recommendation_data_source.dart';
import 'package:tablego/features/recommendations/data/repositories/recommendations_repository.dart';
import 'package:tablego/features/recommendations/domain/recommendation_models.dart';
import 'package:tablego/features/recommendations/providers/recommendations_provider.dart';

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

/// Counts how often the recommendations are (re)computed.
class _CountingRepository extends RecommendationsRepository {
  _CountingRepository(this._inner);

  final RecommendationsRepository _inner;
  int calls = 0;

  @override
  Future<RecommendationResult> getRecommendations(int userId,
      {DateTime? now}) {
    calls++;
    return _inner.getRecommendations(userId, now: now);
  }
}

// ── Fixture ───────────────────────────────────────────────────────────────────

/// A client and one restaurant whose dishes are written with the formats a
/// teammate might use: mixed case, accents, English names, NULL allergens.
class _Fixture {
  _Fixture._(this.helper, this.db, this.auth);

  final DatabaseHelper helper;
  final Database db;
  final AuthRepository auth;
  late final int clientId;
  late final int restaurantId;
  final dishIds = <String, int>{};

  static Future<_Fixture> create({
    List<String> diets = const [],
    List<String> allergies = const [],
  }) async {
    final helper = await buildTestDb();
    final f = _Fixture._(helper, await helper.database,
        AuthRepository(dbHelper: helper, storage: _FakeStorage()));

    f.clientId = (await f.auth.register(
      email: 'client@reco.test', password: 'Password1!',
      userType: 'client', resetQuestion: 'Q?', resetAnswer: 'A',
    )).id;
    await f.db.update(
      'client_profiles',
      {
        'dietary_preferences': jsonEncode(diets),
        'allergies': jsonEncode(allergies),
      },
      where: 'user_id = ?', whereArgs: [f.clientId],
    );

    final owner = await f.auth.register(
      email: 'resto@reco.test', password: 'Password1!',
      userType: 'restaurant', resetQuestion: 'Q?', resetAnswer: 'A',
      restaurantName: 'Test Bistro',
    );
    final rows = await f.db.query('restaurant_profiles',
        columns: ['id'], where: 'user_id = ?', whereArgs: [owner.id]);
    f.restaurantId = rows.single['id']! as int;
    await f.db.update('restaurant_profiles', {'cuisine_type': 'French'},
        where: 'id = ?', whereArgs: [f.restaurantId]);

    Future<void> dish(String name, String? tags, String? allergens) async {
      f.dishIds[name] = await f.db.insert('dishes', {
        'restaurant_id': f.restaurantId, 'name': name, 'price': 12.0,
        'is_available': 1, 'tags': tags, 'allergens': allergens,
      });
    }

    await dish('Falafel', '["Végétarien","HALAL"]', '[]');
    await dish('Cookie', '["vegetarian","halal"]', '["Peanuts","gluten"]');
    await dish('Mystère', '["vegetarien","halal"]', null);
    await dish('Poulet', '["halal"]', '[]');
    await dish('Cassé', 'not json', 'not json');
    return f;
  }

  RecommendationsRepository get repo =>
      RecommendationsRepository(dbHelper: helper);
}

List<String> _dishNames(RecommendationResult r) =>
    r.dishes.map((d) => d.dish.name).toList()..sort();

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── Data source: the integration contract ──────────────────────────────────
  group('RecommendationDataSource', () {
    test('normalises tags, allergens and profile labels on read', () async {
      final f = await _Fixture.create(
          diets: ['vegetarian'], allergies: ['arachides']);
      final snapshot = await RecommendationDataSource(dbHelper: f.helper)
          .load(f.clientId);

      expect(snapshot.profile.diets, {'vegetarien'});
      expect(snapshot.profile.allergens, {'arachides'});

      RecoDish byName(String n) =>
          snapshot.dishes.firstWhere((d) => d.name == n);
      expect(byName('Falafel').tags, {'vegetarien', 'halal'});
      expect(byName('Falafel').allergens, isEmpty); // declared: none
      expect(byName('Cookie').allergens, {'arachides', 'gluten'});
      expect(byName('Mystère').allergens, isNull); // not declared
      expect(byName('Cassé').tags, isEmpty); // malformed JSON
      expect(byName('Cassé').allergens, isNull);
    });

    test('reads orders and favorites of active clients only', () async {
      final f = await _Fixture.create();
      final other = await f.auth.register(
        email: 'gone@reco.test', password: 'Password1!',
        userType: 'client', resetQuestion: 'Q?', resetAnswer: 'A',
      );
      for (final user in [f.clientId, other.id]) {
        await f.db.insert('order_history', {
          'user_id': user, 'restaurant_id': f.restaurantId,
          'dish_id': f.dishIds['Poulet'],
          'ordered_at': '2026-10-30T12:00:00Z',
        });
      }
      await f.db.insert('favorite_dishes',
          {'user_id': f.clientId, 'dish_id': f.dishIds['Falafel']});
      await f.db.update('users', {'is_active': 0},
          where: 'id = ?', whereArgs: [other.id]);

      final snapshot = await RecommendationDataSource(dbHelper: f.helper)
          .load(f.clientId);
      expect(snapshot.interactions.map((i) => i.userId).toSet(), {f.clientId});
      final order = snapshot.interactions
          .firstWhere((i) => i.kind == InteractionKind.order);
      expect(order.at, DateTime.utc(2026, 10, 30, 12));
      expect(order.dishId, f.dishIds['Poulet']);
    });
  });

  // ── Repository: filters applied end to end ─────────────────────────────────
  group('RecommendationsRepository', () {
    test('a peanut-allergic vegetarian never gets peanuts nor unknown dishes',
        () async {
      final f = await _Fixture.create(
          diets: ['vegetarian'], allergies: ['peanuts']);
      final result = await f.repo.getRecommendations(f.clientId);
      // Cookie: peanuts. Mystère: allergens not declared. Poulet: not
      // vegetarian. Cassé: unreadable tags.
      expect(_dishNames(result), ['Falafel']);
      expect(result.restaurants.single.restaurant.name, 'Test Bistro');
      expect(result.restaurants.single.compatibleDishCount, 1);
    });

    test('a client without constraints sees every dish', () async {
      final f = await _Fixture.create();
      final result = await f.repo.getRecommendations(f.clientId);
      expect(_dishNames(result),
          ['Cassé', 'Cookie', 'Falafel', 'Mystère', 'Poulet']);
      expect(result.coldStart, isTrue);
    });
  });

  // ── Automatic refresh ──────────────────────────────────────────────────────
  test('recommendations refresh after favorites, profile and order changes',
      () async {
    final f = await _Fixture.create();
    final counting = _CountingRepository(f.repo);
    final container = ProviderContainer(overrides: [
      recommendationsRepositoryProvider.overrideWithValue(counting),
      favoritesRepositoryProvider
          .overrideWithValue(FavoritesRepository(dbHelper: f.helper)),
      profileRepositoryProvider
          .overrideWithValue(ProfileRepository(dbHelper: f.helper)),
    ]);
    addTearDown(container.dispose);
    final provider = recommendationsProvider(f.clientId);
    container.listen(provider, (_, _) {});

    // Initial computation: cold start.
    expect((await container.read(provider.future)).coldStart, isTrue);
    expect(counting.calls, 1);

    // 1. A favorite dish is added → recomputed, no longer a cold start.
    await container
        .read(favoriteDishesProvider(f.clientId).notifier)
        .toggle(f.dishIds['Falafel']!);
    expect((await container.read(provider.future)).coldStart, isFalse);
    expect(counting.calls, 2);

    // 2. Profile preferences change → recomputed with the new filter.
    await container.read(profileProvider.notifier).updateClientProfile(
        userId: f.clientId, allergies: ['peanuts']);
    final afterProfile = await container.read(provider.future);
    expect(counting.calls, 3);
    expect(_dishNames(afterProfile), isNot(contains('Cookie')));

    // 3. An order is saved by another module, which signals the change.
    await f.db.insert('order_history', {
      'user_id': f.clientId, 'restaurant_id': f.restaurantId,
      'dish_id': f.dishIds['Poulet'],
    });
    container.read(userDataChangesProvider.notifier).changed();
    await container.read(provider.future);
    expect(counting.calls, 4);
  });
}
