import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';

/// The `dishes` table exactly as shipped up to schema v2 (no `allergens`).
const _dishesV2 = '''
  CREATE TABLE dishes (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    restaurant_id INTEGER NOT NULL,
    name          TEXT    NOT NULL,
    description   TEXT    NULL,
    price         REAL    NOT NULL DEFAULT 0.0,
    photo_path    TEXT    NULL,
    is_available  INTEGER NOT NULL DEFAULT 1,
    tags          TEXT    NULL,
    created_at    TEXT    NOT NULL
                    DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT    NOT NULL
                    DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
  )
''';

Future<Set<String>> _dishColumns(Database db) async =>
    (await db.rawQuery('PRAGMA table_info(dishes)'))
        .map((c) => c['name']! as String)
        .toSet();

void main() {
  setUpAll(sqfliteFfiInit);

  test('schema version is 3', () {
    expect(DatabaseHelper.schemaVersion, 3);
  });

  test('a v2 database upgrades to v3: dishes.allergens added, rows kept',
      () async {
    final dir = Directory.systemTemp.createTempSync('tablego_upgrade_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}tablego.db';

    // 1. A database created by the v2 app, with one dish.
    var db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await UserModuleTables.create(db);
            await db.execute(_dishesV2);
          },
        ));
    await db.insert('dishes',
        {'restaurant_id': 1, 'name': 'Ancien plat', 'tags': '["halal"]'});
    expect(await _dishColumns(db), isNot(contains('allergens')));
    await db.close();

    // 2. Reopened by the v3 app: the real upgrade steps run.
    db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.schemaVersion,
          onUpgrade: DatabaseHelper.migrate,
        ));
    addTearDown(db.close);

    expect(await db.getVersion(), 3);
    expect(await _dishColumns(db), contains('allergens'));
    final row = (await db.query('dishes')).single;
    expect(row['name'], 'Ancien plat');
    expect(row['tags'], '["halal"]');
    expect(row['allergens'], isNull); // not declared yet

    // 3. Idempotent: running the steps again changes nothing.
    await DatabaseHelper.migrate(db, 2, 3);
    await SharedTables.addDishAllergens(db);
    expect((await _dishColumns(db)).where((c) => c == 'allergens'),
        hasLength(1));
  });

  test('a new database gets dishes.allergens from create()', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.schemaVersion,
          onCreate: (db, _) async {
            await UserModuleTables.create(db);
            await SharedTables.create(db);
          },
        ));
    addTearDown(db.close);
    expect(await _dishColumns(db), contains('allergens'));
  });
}
