// Whole-app flow (regression test for the "no way back to Profil after an
// order" bug): a restored client session opens a restaurant, adds a dish,
// orders, sees the order in Activité → Commandes, then logs out from Profil
// and lands on the login screen.

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

Future<Database> _appDb() async {
  // No isolate: database calls complete inside the widget test's fake clock.
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    'file:order_flow_${DateTime.now().microsecondsSinceEpoch}?mode=memory&cache=shared',
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
  Future<int> user(String email, String type) => db.insert('users', {
        'email': email, 'password_hash': 'h', 'salt': 's',
        'password_iterations': 1, 'user_type': type,
      });
  final client = await user('client@flow.test', 'client');
  await db.insert('client_profiles', {'user_id': client, 'full_name': 'Alice'});
  final owner = await user('resto@flow.test', 'restaurant');
  final resto = await db.insert('restaurant_profiles',
      {'user_id': owner, 'name': 'Chez Flow'});
  await db.insert('dishes', {
    'restaurant_id': resto, 'name': 'Tajine Flow', 'price': 20.0,
    'category': 'Plat principal', 'is_available': 1, 'allergens': '[]',
  });
  return db;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('client orders, finds it in Activité, logs out → login',
      (tester) async {
    // Wide enough for the test font (much wider than the real fonts).
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final db = (await tester.runAsync(_appDb))!;
    DatabaseHelper.useDatabaseForTesting(db);
    addTearDown(() => DatabaseHelper.useDatabaseForTesting(null));

    // Restored session (as after a page reload).
    final storage = _FakeStorage();
    final clientId = (await tester.runAsync(() => db.query('users',
            where: 'email = ?', whereArgs: ['client@flow.test'])))!
        .single['id'];
    storage.map['session_user_id'] = '$clientId';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(AuthRepository(storage: storage)),
      ],
      child: const TableGoApp(),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Que voulez-vous manger ?'), findsOneWidget);

    // Explorer → restaurant → add the dish → cart → checkout.
    await _tap(tester, find.text('Explorer'));
    await _tap(tester, find.text('Chez Flow'));
    await _tap(tester, find.text('Menu'));
    await _tap(tester, find.byIcon(Icons.add)); // dish card "+" button
    await _tap(tester, find.text('Panier'));
    await _tap(tester, find.text('Passer la commande'));
    await _tap(tester, find.text('Confirmer la commande'));
    expect(find.text('Commande passée !'), findsOneWidget);

    // Back in the main client shell, Activité → Commandes.
    await _tap(tester, find.text('Voir mes commandes'));
    expect(find.text('Activité'), findsOneWidget);
    expect(find.textContaining('Commande #1'), findsOneWidget);
    expect(find.textContaining('Tajine Flow'), findsOneWidget);

    // Profil → Se déconnecter → login screen.
    await _tap(tester, find.byTooltip('Back'));
    await _tap(tester, find.text('Profil'));
    await _tap(tester, find.text('Se déconnecter'));
    expect(find.text('Se connecter'), findsOneWidget);
    expect(storage.map.containsKey('session_user_id'), isFalse);
    // Nothing of the session is left under the login screen.
    expect(find.text('Que voulez-vous manger ?', skipOffstage: false),
        findsNothing);
  });

  testWidgets('the restaurant view always offers a way back to the main shell',
      (tester) async {
    // Wide enough for the test font (much wider than the real fonts).
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final db = (await tester.runAsync(_appDb))!;
    DatabaseHelper.useDatabaseForTesting(db);
    addTearDown(() => DatabaseHelper.useDatabaseForTesting(null));
    final storage = _FakeStorage();
    final clientId = (await tester.runAsync(() => db.query('users',
            where: 'email = ?', whereArgs: ['client@flow.test'])))!
        .single['id'];
    storage.map['session_user_id'] = '$clientId';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(AuthRepository(storage: storage)),
      ],
      child: const TableGoApp(),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Explorer'));
    await _tap(tester, find.text('Chez Flow'));

    for (final tab in ['Accueil', 'Menu', 'Panier', 'Commandes', 'Réserver']) {
      await _tap(tester, find.text(tab).last);
      expect(find.byKey(const Key('leave_restaurant')), findsOneWidget,
          reason: tab);
    }
    await _tap(tester, find.byKey(const Key('leave_restaurant')));
    expect(find.text('Profil'), findsOneWidget);
  });
}
