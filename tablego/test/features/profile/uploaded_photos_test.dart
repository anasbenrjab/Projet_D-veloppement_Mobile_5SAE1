import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/utils/photo_ref.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/favorites/data/models/restaurant_summary_model.dart';
import 'package:tablego/features/favorites/data/repositories/favorites_repository.dart';
import 'package:tablego/features/profile/data/repositories/profile_repository.dart';
import 'package:tablego/features/recommendations/data/repositories/recommendations_repository.dart';

import '../auth/helpers/db_test_helper.dart';

// ── In-memory secure storage stub ────────────────────────────────────────────

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

// ── Helpers ───────────────────────────────────────────────────────────────────

const _seedCover = 'assets/images/seed/restaurants/sushi_1.jpg';

/// Stores [bytes] the way the web build stores an upload
/// (`ProfileRepository._saveWebPhoto`) and returns the expected reference.
Future<String> _webUpload(Database db, int userId, int position,
    List<int> bytes) async {
  await db.insert('profile_photos', {
    'user_id':   userId,
    'user_type': 'restaurant',
    'position':  position,
    'mime_type': 'image/png',
    'data':      Uint8List.fromList(bytes),
  });
  return encodePhotoDataUri('image/png', bytes);
}

Future<int> _restaurantProfileId(Database db, int userId) async {
  final rows = await db.query('restaurant_profiles',
      columns: ['id'], where: 'user_id = ?', whereArgs: [userId]);
  return rows.single['id'] as int;
}

RestaurantSummaryModel _byName(
        Iterable<RestaurantSummaryModel> restaurants, String name) =>
    restaurants.singleWhere((r) => r.name == name);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Restaurant photos uploaded on web live in `profile_photos`, not in
  // `restaurant_profiles.photo_paths`.  The cards (home, "Recommandé pour
  // vous", favorites) must show them just like the restaurant profile does.
  test('web-uploaded restaurant photos reach the cards and the profile',
      () async {
    final helper = await buildTestDb();
    final db = await helper.database;
    final auth = AuthRepository(dbHelper: helper, storage: _FakeStorage());

    Future<int> registerRestaurant(String name) async => (await auth.register(
          email: '${name.toLowerCase().replaceAll(' ', '')}@photos.test',
          password: 'Password1!',
          userType: 'restaurant',
          resetQuestion: 'Q?',
          resetAnswer: 'A',
          restaurantName: name,
        ))
            .id;

    final client = await auth.register(
      email: 'client@photos.test',
      password: 'Password1!',
      userType: 'client',
      resetQuestion: 'Q?',
      resetAnswer: 'A',
    );
    final uploadsOnly = await registerRestaurant('Uploads Only');
    final storedAndUploads = await registerRestaurant('Stored And Uploads');
    await registerRestaurant('No Photos');

    // "Uploads Only": one web upload, nothing stored.
    final onlyUpload = await _webUpload(db, uploadsOnly, 0, [1, 2, 3]);

    // "Stored And Uploads": a stored seed photo plus two web uploads,
    // inserted out of order to check they come back sorted by position.
    await db.update(
      'restaurant_profiles',
      {'photo_paths': jsonEncode([_seedCover])},
      where: 'user_id = ?',
      whereArgs: [storedAndUploads],
    );
    final second = await _webUpload(db, storedAndUploads, 1, [7, 8]);
    final first = await _webUpload(db, storedAndUploads, 0, [4, 5, 6]);
    final expectedMerged = [_seedCover, first, second];

    // ── Favorites (also the home screen's "nearby" list) ──────────────────
    final favs = FavoritesRepository(dbHelper: helper);
    await favs.addFavoriteRestaurant(
        client.id, await _restaurantProfileId(db, uploadsOnly));
    await favs.addFavoriteRestaurant(
        client.id, await _restaurantProfileId(db, storedAndUploads));

    final favorites = await favs.getFavoriteRestaurants(client.id);
    expect(_byName(favorites, 'Uploads Only').photoPaths, [onlyUpload]);
    expect(_byName(favorites, 'Uploads Only').firstPhotoPath, onlyUpload);
    expect(_byName(favorites, 'Stored And Uploads').photoPaths,
        expectedMerged);

    // ── "Recommandé pour vous" ────────────────────────────────────────────
    final recommended = (await RecommendationsRepository(dbHelper: helper)
            .getRecommendations(client.id))
        .map((s) => s.restaurant);
    expect(_byName(recommended, 'Uploads Only').firstPhotoPath, onlyUpload);
    expect(_byName(recommended, 'Stored And Uploads').photoPaths,
        expectedMerged);
    expect(_byName(recommended, 'No Photos').photoPaths, isEmpty);

    // ── Restaurant profile shows the same list as the cards ───────────────
    final profile = await ProfileRepository(dbHelper: helper)
        .getRestaurantProfile(storedAndUploads);
    expect(profile.photoPaths, expectedMerged);
  });

  test('client uploads never appear on restaurant cards', () async {
    final helper = await buildTestDb();
    final db = await helper.database;
    final auth = AuthRepository(dbHelper: helper, storage: _FakeStorage());

    final client = await auth.register(
      email: 'c2@photos.test',
      password: 'Password1!',
      userType: 'client',
      resetQuestion: 'Q?',
      resetAnswer: 'A',
    );
    await auth.register(
      email: 'r2@photos.test',
      password: 'Password1!',
      userType: 'restaurant',
      resetQuestion: 'Q?',
      resetAnswer: 'A',
      restaurantName: 'Plain',
    );
    // A client avatar upload is stored in the same table.
    await db.insert('profile_photos', {
      'user_id':   client.id,
      'user_type': 'client',
      'position':  0,
      'mime_type': 'image/png',
      'data':      Uint8List.fromList([9, 9]),
    });

    final recommended = await RecommendationsRepository(dbHelper: helper)
        .getRecommendations(client.id);
    expect(recommended.single.restaurant.photoPaths, isEmpty);
  });
}
