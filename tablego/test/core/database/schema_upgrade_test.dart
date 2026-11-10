import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/tables/events_tables.dart';
import 'package:tablego/core/database/tables/menu_tables.dart';
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

  test('schema version is 6', () {
    expect(DatabaseHelper.schemaVersion, 6);
  });

  test('a v2 database upgrades: dishes.allergens added, rows kept',
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

    // 2. Reopened by the current app: the real upgrade steps run.
    db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.schemaVersion,
          onUpgrade: DatabaseHelper.migrate,
        ));
    addTearDown(db.close);

    expect(await db.getVersion(), DatabaseHelper.schemaVersion);
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

  test('a v3 database upgrades to v4: order_history rows become orders, '
      'and order_history becomes a view', () async {
    final dir = Directory.systemTemp.createTempSync('tablego_upgrade_v4_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}tablego.db';

    // 1. A database created by the v3 app (order_history is a table).
    var db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 3,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await UserModuleTables.create(db);
            await SharedTables.create(db);
          },
        ));
    final userId = await db.insert('users', {
      'email': 'c@test.com', 'password_hash': 'h', 'salt': 's',
      'password_iterations': 1, 'user_type': 'client',
    });
    final ownerId = await db.insert('users', {
      'email': 'r@test.com', 'password_hash': 'h', 'salt': 's',
      'password_iterations': 1, 'user_type': 'restaurant',
    });
    final restaurantId = await db.insert(
        'restaurant_profiles', {'user_id': ownerId, 'name': 'Chez Test'});
    final dishId = await db.insert('dishes',
        {'restaurant_id': restaurantId, 'name': 'Tajine', 'price': 20.0});
    await db.insert('order_history', {
      'user_id': userId, 'restaurant_id': restaurantId, 'dish_id': dishId,
      'ordered_at': '2026-10-01T12:00:00Z',
    });
    await db.insert('order_history', {
      'user_id': userId, 'restaurant_id': restaurantId, 'dish_id': null,
      'ordered_at': '2026-10-02T12:00:00Z',
    });
    await db.close();

    // 2. Reopened by the v4 app.
    db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onUpgrade: DatabaseHelper.migrate,
        ));
    addTearDown(db.close);

    final type = (await db.rawQuery(
            "SELECT type FROM sqlite_master WHERE name = 'order_history'"))
        .single['type'];
    expect(type, 'view');
    expect(await _dishColumns(db), contains('category'));

    // Same history, now read through the view.
    final history = await db.query('order_history',
        columns: ['user_id', 'restaurant_id', 'dish_id', 'ordered_at'],
        orderBy: 'ordered_at');
    expect(history, [
      {'user_id': userId, 'restaurant_id': restaurantId, 'dish_id': dishId,
       'ordered_at': '2026-10-01T12:00:00Z'},
      {'user_id': userId, 'restaurant_id': restaurantId, 'dish_id': null,
       'ordered_at': '2026-10-02T12:00:00Z'},
    ]);
    final items = await db.query('order_items',
        columns: ['dish_name', 'dish_price', 'quantity'], orderBy: 'id');
    expect(items, [
      {'dish_name': 'Tajine', 'dish_price': 20.0, 'quantity': 1},
      {'dish_name': 'Plat supprimé', 'dish_price': 0.0, 'quantity': 1},
    ]);

    // 3. Idempotent: running the v4 step again changes nothing.
    await DatabaseHelper.migrate(db, 3, 4);
    expect(await db.query('orders'), hasLength(2));
    expect(await db.query('order_history'), hasLength(2));
  });

  test('a v4 database upgrades to v5: Module 3 tables and seat capacity',
      () async {
    final dir = Directory.systemTemp.createTempSync('tablego_upgrade_v5_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}tablego.db';

    var db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
            await UserModuleTables.create(db);
            await SharedTables.create(db);
            await MenuTables.create(db);
          },
        ));
    final ownerId = await db.insert('users', {
      'email': 'r@test.com', 'password_hash': 'h', 'salt': 's',
      'password_iterations': 1, 'user_type': 'restaurant',
    });
    await db.insert(
        'restaurant_profiles', {'user_id': ownerId, 'name': 'Chez Test'});
    await db.close();

    db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.schemaVersion,
          onUpgrade: DatabaseHelper.migrate,
        ));
    addTearDown(db.close);

    final tables = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, containsAll(['evenement', 'reservation']));
    // Module 3's own restaurant/client/meta tables are not recreated.
    expect(tables, isNot(contains('restaurant')));
    expect(tables, isNot(contains('client')));
    expect(tables, isNot(contains('meta')));
    final rp = (await db.query('restaurant_profiles')).single;
    expect(rp['seat_capacity'], 40);

    // Idempotent.
    await DatabaseHelper.migrate(db, 4, 5);
    await EventsTables.create(db);
  });
}
