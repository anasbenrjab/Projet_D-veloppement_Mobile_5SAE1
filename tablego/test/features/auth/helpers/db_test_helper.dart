import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';

/// Returns a [DatabaseHelper] backed by a fresh in-memory SQLite database.
///
/// Uses sqflite_common_ffi so tests run on the host machine with no emulator.
/// Call once per test (or in setUp) — each call creates an independent DB.
///
/// The unique [_counter] path ensures sqflite_ffi creates a separate memory
/// database for every call, even though [inMemoryDatabasePath] itself is
/// shared across calls in the ffi implementation.
int _counter = 0;

Future<DatabaseHelper> buildTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Using a unique name forces sqflite_ffi to create a distinct in-memory
  // database for each test, preventing cross-test data leakage.
  final uniquePath = 'file:tablego_test_${_counter++}?mode=memory&cache=shared';

  final db = await databaseFactoryFfi.openDatabase(
    uniquePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await UserModuleTables.create(db);
        await SharedTables.create(db);
      },
    ),
  );

  return DatabaseHelper.forTesting(db);
}
