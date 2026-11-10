// Shared fixtures for the per-repository CRUD tests: a fresh in-memory
// database per test (buildTestDb → DatabaseHelper.forTesting, all module
// tables, foreign keys ON) and fast direct inserts for users/restaurants/
// dishes when a test does not need real password hashing.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';

import '../features/auth/helpers/db_test_helper.dart';

export 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Call from `setUpAll`.
void initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

class TestDb {
  TestDb._(this.helper, this.db);

  final DatabaseHelper helper;
  final Database db;

  static Future<TestDb> open() async {
    final helper = await buildTestDb();
    return TestDb._(helper, await helper.database);
  }

  /// A user row without real credentials (for non-auth tests).
  Future<int> user(String email, {String type = 'client', bool active = true}) =>
      db.insert('users', {
        'email': email,
        'password_hash': 'h',
        'salt': 's',
        'password_iterations': 1,
        'user_type': type,
        'is_active': active ? 1 : 0,
      });

  Future<int> client(String email, {String? fullName}) async {
    final id = await user(email);
    await db.insert('client_profiles', {'user_id': id, 'full_name': ?fullName});
    return id;
  }

  /// Returns (owner user id, restaurant_profiles.id).
  Future<(int, int)> restaurant(String email, String name) async {
    final owner = await user(email, type: 'restaurant');
    final id = await db.insert(
        'restaurant_profiles', {'user_id': owner, 'name': name});
    return (owner, id);
  }

  Future<int> dish(int restaurantId, String name, {double price = 10}) =>
      db.insert('dishes', {
        'restaurant_id': restaurantId,
        'name': name,
        'price': price,
        'category': 'Plat principal',
        'is_available': 1,
        'allergens': '[]',
      });

  Future<int> count(String table, [String? where, List<Object?>? args]) async =>
      (await db.query(table, where: where, whereArgs: args)).length;
}

/// SQLite constraint failure (FK, UNIQUE, CHECK, NOT NULL).
final throwsConstraint = throwsA(isA<DatabaseException>());

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final map = <String, String>{};

  @override
  Future<void> write({required String key, required String? value,
      IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    value == null ? map.remove(key) : map[key] = value;
  }

  @override
  Future<String?> read({required String key, IOSOptions? iOptions,
      AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async => map[key];

  @override
  Future<void> delete({required String key, IOSOptions? iOptions,
      AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async => map.remove(key);
}
