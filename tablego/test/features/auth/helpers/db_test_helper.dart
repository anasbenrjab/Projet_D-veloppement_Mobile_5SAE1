import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';

/// Returns a [DatabaseHelper] backed by a fresh in-memory SQLite database.
///
/// Callers are responsible for calling [sqfliteFfiInit] and setting
/// `databaseFactory = databaseFactoryFfi` exactly once in [setUpAll] — doing
/// it per-call produces the repeated "changing sqflite default factory"
/// warning.
///
/// Each call uses a unique URI so sqflite_ffi creates a distinct in-memory
/// database, preventing cross-test data leakage.
int _counter = 0;

Future<DatabaseHelper> buildTestDb() async {
  // Unique URI → independent in-memory DB per test.
  final uniquePath =
      'file:tablego_test_${_counter++}?mode=memory&cache=shared';

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
