// Edit-profile screens: the "delete photo" buttons ask for confirmation,
// delete through ProfileNotifier → ProfileRepository, and the screen shows
// the photo gone.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/tables/events_tables.dart';
import 'package:tablego/core/database/tables/menu_tables.dart';
import 'package:tablego/core/database/tables/shared_tables.dart';
import 'package:tablego/core/database/tables/user_module_tables.dart';
import 'package:tablego/features/auth/data/models/user_model.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/auth/providers/auth_provider.dart';
import 'package:tablego/features/profile/data/repositories/profile_repository.dart';
import 'package:tablego/features/profile/presentation/screens/edit_client_profile_screen.dart';
import 'package:tablego/features/profile/presentation/screens/edit_restaurant_profile_screen.dart';
import 'package:tablego/features/profile/providers/profile_provider.dart';

/// A valid 1×1 PNG (the screen decodes the photo).
final _png1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _LoggedIn extends AuthNotifier {
  _LoggedIn(UserModel user) : super(AuthRepository()) {
    state = state.copyWith(user: user);
  }
}

UserModel _user(int id, String type) => UserModel(
      id: id, email: '$type@photo.test', userType: type, isActive: true,
      createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z',
    );

Future<Database> _db() => databaseFactoryFfiNoIsolate.openDatabase(
      'file:photo_${DateTime.now().microsecondsSinceEpoch}'
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

Future<void> _pumpScreen(WidgetTester tester, ProviderContainer container,
    Widget screen) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('client: "Supprimer la photo" removes the profile photo',
      (tester) async {
    late int id;
    final db = (await tester.runAsync(() async {
      final db = await _db();
      id = await db.insert('users', {
        'email': 'client@photo.test', 'password_hash': 'h', 'salt': 's',
        'password_iterations': 1, 'user_type': 'client',
      });
      await db.insert('client_profiles', {'user_id': id, 'full_name': 'A'});
      await db.insert('profile_photos', {
        'user_id': id, 'user_type': 'client', 'mime_type': 'image/png',
        'data': _png1x1,
      });
      return db;
    }))!;
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((_) => _LoggedIn(_user(id, 'client'))),
      profileRepositoryProvider.overrideWithValue(
          ProfileRepository(dbHelper: DatabaseHelper.forTesting(db))),
    ]);
    addTearDown(container.dispose);
    await container.read(profileProvider.notifier).loadClientProfile(id);

    await _pumpScreen(tester, container, const EditClientProfileScreen());
    expect(find.byKey(const Key('delete_client_photo')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_client_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_client_photo')), findsNothing);
    expect(await tester.runAsync(() => db.query('profile_photos')), isEmpty);
  });

  testWidgets('restaurant: the × on a photo removes that photo only',
      (tester) async {
    late int id;
    final db = (await tester.runAsync(() async {
      final db = await _db();
      id = await db.insert('users', {
        'email': 'restaurant@photo.test', 'password_hash': 'h', 'salt': 's',
        'password_iterations': 1, 'user_type': 'restaurant',
      });
      await db.insert('restaurant_profiles', {
        'user_id': id, 'name': 'R',
        'photo_paths': '["assets/images/placeholders/restaurant.jpg",'
            '"assets/images/placeholders/dish.jpg"]',
      });
      return db;
    }))!;
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((_) => _LoggedIn(_user(id, 'restaurant'))),
      profileRepositoryProvider.overrideWithValue(
          ProfileRepository(dbHelper: DatabaseHelper.forTesting(db))),
    ]);
    addTearDown(container.dispose);
    await container.read(profileProvider.notifier).loadRestaurantProfile(id);

    await _pumpScreen(tester, container, const EditRestaurantProfileScreen());
    expect(find.byKey(const Key('delete_restaurant_photo_1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_restaurant_photo_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_restaurant_photo_1')), findsNothing);
    final row = (await tester.runAsync(
            () => db.query('restaurant_profiles')))!
        .single;
    expect(row['photo_paths'], '["assets/images/placeholders/dish.jpg"]');
  });
}
