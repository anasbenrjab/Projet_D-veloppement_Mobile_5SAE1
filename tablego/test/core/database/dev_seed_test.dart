import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/seeds/dev_seed.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';

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
}
