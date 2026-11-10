import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/seeds/dev_seed.dart';
import 'package:tablego/core/database/seeds/menu_seed.dart';
import 'package:tablego/core/database/tables/menu_tables.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';
import 'package:tablego/core/utils/photo_ref.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/profile/data/models/restaurant_profile_model.dart';
import 'package:tablego/features/recommendations/data/repositories/recommendations_repository.dart';
import 'package:tablego/features/recommendations/domain/food_labels.dart';
import 'package:tablego/features/recommendations/domain/recommendation_models.dart';

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

/// Opens a fresh in-memory DB whose [onCreate] mirrors
/// [DatabaseHelper._onCreate] — tables then [DevSeed.run].
Future<Database> _freshSeededDb() => databaseFactoryFfi.openDatabase(
      'file:tablego_seed_${DateTime.now().microsecondsSinceEpoch}'
      '?mode=memory&cache=shared',
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await UserModuleTables.create(db);
          await SharedTables.create(db);
          await MenuTables.create(db);
          await DevSeed.run(db);
        },
      ),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('fresh in-memory DB → seed accounts exist and can log in', () async {
    final db = await _freshSeededDb();

    // Seed accounts exist.
    final rows = await db.query('users', columns: ['email']);
    final emails = rows.map((r) => r['email'] as String).toSet();
    expect(emails, containsAll(seedAccountEmails));

    // Seeded credentials authenticate.
    final auth = AuthRepository(
      dbHelper: DatabaseHelper.forTesting(db),
      storage: _FakeStorage(),
    );
    final user = await auth.login(
      email: 'client@test.com',
      password: 'password123',
    );
    expect(user.email, equals('client@test.com'));
    expect(user.userType, equals('client'));

    // Idempotent: a second run does not duplicate rows.
    await DevSeed.run(db);
    final count = await db.query('users', columns: ['id']);
    expect(count.length, equals(seedAccountEmails.length));
  });

  group('seed photos', () {
    Future<String?> clientPhoto(Database db) async {
      final rows = await db.rawQuery('''
        SELECT cp.photo_path FROM client_profiles cp
          JOIN users u ON u.id = cp.user_id
         WHERE u.email = 'client@test.com'
      ''');
      return rows.single['photo_path'] as String?;
    }

    Future<List<String>> restaurantPhotos(Database db, String email) async {
      final rows = await db.rawQuery('''
        SELECT rp.photo_paths FROM restaurant_profiles rp
          JOIN users u ON u.id = rp.user_id
         WHERE u.email = ?
      ''', [email]);
      return RestaurantProfileModel.decodeList(rows.single['photo_paths']);
    }

    test('fresh DB → Alice, every restaurant and the 5 photographed dishes '
        'have a photo', () async {
      final db = await _freshSeededDb();

      expect(await clientPhoto(db),
          equals('assets/images/seed/avatars/alice.jpg'));
      for (final email in [
        'resto@test.com',
        'burgerking@test.com',
        'sushi@test.com',
      ]) {
        expect(await restaurantPhotos(db, email), hasLength(3),
            reason: email);
      }
      // Dishes added for the recommendation demo use the placeholder.
      // Module 2's demo dishes use network photos (TheMealDB / Unsplash).
      final dishes = await db.query('dishes',
          columns: ['name', 'photo_path'],
          where: "photo_path IS NOT NULL AND photo_path NOT LIKE 'http%'");
      expect(dishes, hasLength(5));
      for (final d in dishes) {
        expect(d['photo_path'], startsWith('assets/images/seed/dishes/'),
            reason: d['name'] as String);
      }
      final networkPhotos = await db.query('dishes',
          columns: ['name'], where: "photo_path LIKE 'https://%'");
      expect(networkPhotos.map((d) => d['name']),
          unorderedEquals(menuDemoDishNames));
    });

    test('every seed photo exists in a folder bundled by pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final asset in seedPhotoAssets) {
        expect(File(asset).existsSync(), isTrue, reason: '$asset missing');
        final folder = asset.substring(0, asset.lastIndexOf('/') + 1);
        expect(pubspec, contains('- $folder'),
            reason: '$folder not declared in pubspec.yaml');
      }
      for (final placeholder in [
        kRestaurantPlaceholderAsset,
        kDishPlaceholderAsset,
      ]) {
        expect(File(placeholder).existsSync(), isTrue,
            reason: '$placeholder missing');
      }
    });

    test('backfill fills missing photos and keeps user-set ones', () async {
      final db = await _freshSeededDb();

      // Simulate a database seeded before the photos existed, where the
      // client has since uploaded a photo of their own.
      await db.update('client_profiles', {'photo_path': '/docs/mine.jpg'});
      await db.update('restaurant_profiles', {'photo_paths': null});
      await db.update('dishes', {'photo_path': null});

      await DevSeed.applySeedPhotos(db);

      expect(await clientPhoto(db), equals('/docs/mine.jpg'));
      expect(await restaurantPhotos(db, 'sushi@test.com'), [
        'assets/images/seed/restaurants/sushi_1.jpg',
        'assets/images/seed/restaurants/sushi_2.jpg',
        'assets/images/seed/restaurants/sushi_3.jpg',
      ]);
      final soup = await db.query('dishes',
          columns: ['photo_path'],
          where: 'name = ?',
          whereArgs: ["Soupe à l'oignon"]);
      expect(soup.single['photo_path'],
          equals('assets/images/seed/dishes/soupe_oignon.jpg'));

      // Idempotent: nothing left to update on a second pass.
      final before = await db.query('restaurant_profiles');
      await DevSeed.applySeedPhotos(db);
      expect(await db.query('restaurant_profiles'), equals(before));
    });
  });

  group('recommendation demo', () {
    Future<int> count(Database db, String table) async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']!
            as int;

    test('every seed dish declares normalised tags and allergens', () async {
      final db = await _freshSeededDb();
      final dishes = await db.query('dishes');
      // Recommendation demo menu + Module 2's demo menu.
      expect(dishes, hasLength(seedMenuSize + menuDemoSize));
      for (final d in dishes) {
        expect(d['allergens'], isNotNull, reason: d['name'] as String);
        final labels = [
          ...(jsonDecode(d['tags']! as String) as List),
          ...(jsonDecode(d['allergens']! as String) as List),
        ].cast<String>();
        for (final label in labels) {
          expect(label, FoodLabels.canonical(label),
              reason: '${d['name']}: "$label" is not normalised');
        }
      }
      // Every demo client has orders and favorites.
      final perClient = await db.rawQuery('''
        SELECT u.email,
               (SELECT COUNT(*) FROM order_history o WHERE o.user_id = u.id)
                 AS orders,
               (SELECT COUNT(*) FROM favorite_dishes f WHERE f.user_id = u.id)
                 AS favorites
          FROM users u WHERE u.user_type = 'client'
      ''');
      expect(perClient, hasLength(5));
      for (final row in perClient) {
        expect(row['orders'], greaterThan(0), reason: '${row['email']}');
        expect(row['favorites'], greaterThan(0), reason: '${row['email']}');
      }
    });

    test('backfill completes a database seeded before the demo, once',
        () async {
      final db = await _freshSeededDb();
      final expected = {
        for (final t in [
          'users', 'dishes', 'order_history', 'favorite_dishes',
          'favorite_restaurants',
        ])
          t: await count(db, t),
      };

      // Simulate the old seed: no demo clients (orders and favorites
      // cascade), only the 5 original dishes, English tags, no allergens.
      await db.delete('users',
          where: "email IN ('karim@test.com','sophie@test.com',"
              "'yuki@test.com','lucas@test.com')");
      await db.delete('dishes',
          where: "name NOT IN ('Soupe à l''oignon','Poulet rôti',"
              "'Smash Burger Classic','Crispy Chicken Burger',"
              "'Salmon Sashimi (8 pcs)')");
      await db.update('dishes', {'tags': '["vegetarian"]', 'allergens': null});

      // Same backfills as DatabaseHelper._onOpen.
      await DevSeed.applyRecommendationDemo(db);
      await MenuSeed.applyMenuDemo(db);
      for (final e in expected.entries) {
        expect(await count(db, e.key), e.value, reason: e.key);
      }
      final soup = (await db.query('dishes',
              where: 'name = ?', whereArgs: ["Soupe à l'oignon"]))
          .single;
      expect(soup['tags'], '["vegetarien"]');
      expect(soup['allergens'], '["gluten","lactose"]');

      // Idempotent: a second pass adds nothing.
      await DevSeed.applyRecommendationDemo(db);
      await MenuSeed.applyMenuDemo(db);
      for (final e in expected.entries) {
        expect(await count(db, e.key), e.value, reason: e.key);
      }
    });

    test('the demo clients get different, filter-safe recommendations',
        () async {
      final db = await _freshSeededDb();
      final repo =
          RecommendationsRepository(dbHelper: DatabaseHelper.forTesting(db));
      Future<RecommendationResult> forClient(String email) async {
        final id = (await db.query('users',
                columns: ['id'], where: 'email = ?', whereArgs: [email]))
            .single['id']! as int;
        return repo.getRecommendations(id);
      }

      // Alice: halal + végétarien, allergic to peanuts.
      final alice = await forClient('client@test.com');
      expect(alice.dishes.map((d) => d.dish.name).toSet(), {
        'Ratatouille provençale', 'Tarte aux pommes', 'Veggie Burger',
        'Frites maison',
      });
      // Tokyo Sushi Bar has no halal + vegetarian dish: excluded even though
      // it is one of her favorites.
      expect(alice.restaurants.map((r) => r.restaurant.name).toSet(),
          {'Le Gourmet Parisien', 'Burger Palace'});

      // Yuki: allergic to lactose (stored as "dairy").
      final yuki = await forClient('yuki@test.com');
      expect(
          yuki.dishes.every((d) => !d.dish.allergens!.contains('lactose')),
          isTrue);

      // Each client gets a different dish list.
      final lists = <String, List<String>>{};
      for (final email in [
        'client@test.com', 'karim@test.com', 'sophie@test.com',
        'yuki@test.com', 'lucas@test.com',
      ]) {
        lists[email] =
            (await forClient(email)).dishes.map((d) => d.dish.name).toList();
      }
      expect(lists.values.map((l) => l.join('|')).toSet(),
          hasLength(lists.length));
    });
  });
}
