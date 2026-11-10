// Restaurant → Mes plats: edit (prefilled form, saved to SQLite, list
// refreshed) and delete through the real screens.  Regression test for
// "the edit button does nothing": the form rebuilt the dish without its
// restaurant, the update hit the restaurant_id foreign key and failed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/tables/events_tables.dart';
import 'package:tablego/core/database/tables/menu_tables.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/main.dart';

class _FakeStorage extends Fake implements FlutterSecureStorage {
  final map = <String, String>{};

  @override
  Future<String?> read({required String key, IOSOptions? iOptions,
      AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async => map[key];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('edit opens prefilled, saves to SQLite, list refreshes; '
      'delete removes the dish', (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    late int ownerId, dishId;
    final db = (await tester.runAsync(() async {
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        'file:edit_dish_${DateTime.now().microsecondsSinceEpoch}'
        '?mode=memory&cache=shared',
        options: OpenDatabaseOptions(
          version: DatabaseHelper.schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await UserModuleTables.create(db);
            await SharedTables.create(db);
            await MenuTables.create(db);
            await EventsTables.create(db);
          },
        ),
      );
      ownerId = await db.insert('users', {
        'email': 'resto@edit.test', 'password_hash': 'h', 'salt': 's',
        'password_iterations': 1, 'user_type': 'restaurant',
      });
      final rid = await db.insert('restaurant_profiles',
          {'user_id': ownerId, 'name': 'Chez Edit'});
      dishId = await db.insert('dishes', {
        'restaurant_id': rid, 'name': 'Tajine', 'price': 20.0,
        'description': 'Agneau', 'category': 'Plat principal',
        'is_available': 1, 'allergens': '["gluten"]',
      });
      return db;
    }))!;
    DatabaseHelper.useDatabaseForTesting(db);
    addTearDown(() => DatabaseHelper.useDatabaseForTesting(null));

    final storage = _FakeStorage()..map['session_user_id'] = '$ownerId';
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(AuthRepository(storage: storage)),
      ],
      child: const TableGoApp(),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Tajine'), findsOneWidget);

    // Edit: the form opens prefilled.
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le plat'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Tajine'), findsOneWidget);
    expect(find.widgetWithText(TextField, '20.000'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Gluten'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Tajine'), 'Tajine royal');
    await tester.enterText(find.widgetWithText(TextField, '20.000'), '24.5');
    final save = find.text('Enregistrer');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Back on the list, refreshed; SQLite updated, restaurant unchanged.
    expect(find.text('Tajine royal'), findsOneWidget);
    final row = (await tester.runAsync(() =>
            db.query('dishes', where: 'id = ?', whereArgs: [dishId])))!
        .single;
    expect(row['name'], 'Tajine royal');
    expect(row['price'], 24.5);
    expect(row['restaurant_id'], isNot(0));
    expect(row['allergens'], '["gluten"]');

    // Delete through the confirmation dialog.
    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(find.text('Tajine royal'), findsNothing);
    expect(await tester.runAsync(() => db.query('dishes')), isEmpty);
  });
}
