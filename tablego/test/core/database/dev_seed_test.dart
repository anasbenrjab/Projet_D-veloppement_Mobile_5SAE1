import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/seeds/dev_seed.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';
import 'package:tablego/core/utils/photo_ref.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/profile/data/models/restaurant_profile_model.dart';

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
    expect(
      emails,
      containsAll(<String>[
        'client@test.com',
        'resto@test.com',
        'burgerking@test.com',
        'sushi@test.com',
      ]),
    );

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
    expect(count.length, equals(4));
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

    test('fresh DB → Alice, every restaurant and every dish have a photo',
        () async {
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
      final dishes = await db.query('dishes', columns: ['name', 'photo_path']);
      expect(dishes, hasLength(5));
      for (final d in dishes) {
        expect(d['photo_path'], startsWith('assets/images/seed/dishes/'),
            reason: d['name'] as String);
      }
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
}
