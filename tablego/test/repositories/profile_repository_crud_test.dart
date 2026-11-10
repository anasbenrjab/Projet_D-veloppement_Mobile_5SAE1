// ProfileRepository — client & restaurant profiles (read, update) and
// profile photos (create, read, replace).  The photo copy goes through
// path_provider, mocked here to a temporary directory.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tablego/core/services/geocoding_service.dart';
import 'package:tablego/features/profile/data/repositories/profile_repository.dart';
import 'package:tablego/features/profile/domain/profile_exception.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initFfi);

  late TestDb t;
  late ProfileRepository repo;
  late Directory docs;
  var geocoderCalls = 0;

  setUp(() async {
    t = await TestDb.open();
    geocoderCalls = 0;
    repo = ProfileRepository(
      dbHelper: t.helper,
      // Never reaches the network.
      geocoder: GeocodingService(
          client: MockClient((_) async {
        geocoderCalls++;
        return http.Response('[]', 200);
      })),
    );
    docs = Directory.systemTemp.createTempSync('tablego_docs_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => docs.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    docs.deleteSync(recursive: true);
  });

  File sourcePhoto(String name) {
    final f = File('${docs.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync([1, 2, 3]);
    return f;
  }

  group('client profile', () {
    test('read: user + profile row', () async {
      final id = await t.client('c@test.com', fullName: 'Alice');
      final p = await repo.getClientProfile(id);
      expect(p.email, 'c@test.com');
      expect(p.fullName, 'Alice');
      expect(p.dietaryPreferences, isEmpty);
    });

    test('update: name, phone, diets, allergies (JSON lists)', () async {
      final id = await t.client('c@test.com');
      await repo.updateClientProfile(
        userId: id, fullName: 'Alice Martin', phone: '+33 6 12 34 56 78',
        dietaryPreferences: ['halal'], allergies: ['peanuts', 'gluten'],
      );
      final p = await repo.getClientProfile(id);
      expect(p.fullName, 'Alice Martin');
      expect(p.phone, '+33 6 12 34 56 78');
      expect(p.dietaryPreferences, ['halal']);
      expect(p.allergies, ['peanuts', 'gluten']);
      final row = (await t.db.query('client_profiles',
          where: 'user_id = ?', whereArgs: [id])).single;
      expect(row['allergies'], '["peanuts","gluten"]');
    });

    test('update: only the given fields change', () async {
      final id = await t.client('c@test.com', fullName: 'Alice');
      await repo.updateClientProfile(userId: id, phone: '0612345678');
      expect((await repo.getClientProfile(id)).fullName, 'Alice');
    });

    test('invalid data → ProfileException, row unchanged', () async {
      final id = await t.client('c@test.com', fullName: 'Alice');
      for (final call in <Future<void> Function()>[
        () => repo.updateClientProfile(userId: id, fullName: '   '),
        () => repo.updateClientProfile(userId: id, fullName: 'x' * 500),
        () => repo.updateClientProfile(userId: id, phone: 'abc'),
      ]) {
        await expectLater(call(), throwsA(isA<ProfileException>()));
      }
      expect((await repo.getClientProfile(id)).fullName, 'Alice');
    });

    test('wrong user type / unknown user', () async {
      final (owner, _) = await t.restaurant('r@test.com', 'R');
      await expectLater(
          repo.getClientProfile(owner), throwsA(isA<ProfileException>()));
      await expectLater(
          repo.getClientProfile(999), throwsA(isA<ProfileException>()));
      await expectLater(repo.updateClientProfile(userId: owner, fullName: 'X'),
          throwsA(isA<ProfileException>()));
    });
  });

  group('restaurant profile', () {
    test('read and update (name, address, hours, cuisine, description)',
        () async {
      final (owner, _) = await t.restaurant('r@test.com', 'Avant');
      final needsGeocoding = await repo.updateRestaurantProfile(
        userId: owner, name: 'Après', address: '1 rue de Rivoli, Paris',
        openingHours: {'lundi': '12:00-22:00'}, cuisineType: 'French',
        description: 'Bistrot',
      );
      expect(needsGeocoding, isTrue); // new address, no coordinates yet
      final p = await repo.getRestaurantProfile(owner);
      expect(p.name, 'Après');
      expect(p.address, '1 rue de Rivoli, Paris');
      expect(p.openingHours, {'lundi': '12:00-22:00'});
      expect(p.cuisineType, 'French');
      expect(p.description, 'Bistrot');
      expect(geocoderCalls, 0); // geocoding is a separate, explicit step
    });

    test('coordinates given with the address → stored, no geocoding needed',
        () async {
      final (owner, _) = await t.restaurant('r@test.com', 'R');
      expect(
          await repo.updateRestaurantProfile(
              userId: owner, address: 'Tunis', latitude: 36.8,
              longitude: 10.18),
          isFalse);
      final p = await repo.getRestaurantProfile(owner);
      expect(p.latitude, 36.8);
      expect(p.longitude, 10.18);
    });

    test('empty name rejected; client account rejected', () async {
      final (owner, _) = await t.restaurant('r@test.com', 'R');
      await expectLater(repo.updateRestaurantProfile(userId: owner, name: ' '),
          throwsA(isA<ProfileException>()));
      final client = await t.client('c@test.com');
      await expectLater(repo.updateRestaurantProfile(userId: client, name: 'X'),
          throwsA(isA<ProfileException>()));
      expect((await repo.getRestaurantProfile(owner)).name, 'R');
    });

    test('the name CHECK constraint holds below the repository', () async {
      final owner = await t.user('r2@test.com', type: 'restaurant');
      expect(
          t.db.insert('restaurant_profiles', {'user_id': owner, 'name': '  '}),
          throwsConstraint);
    });

    test('one profile per user (UNIQUE user_id)', () async {
      final (owner, _) = await t.restaurant('r@test.com', 'R');
      expect(
          t.db.insert('restaurant_profiles', {'user_id': owner, 'name': 'Bis'}),
          throwsConstraint);
    });
  });

  group('profile photos', () {
    test('client: create (copied into documents), read, replace (old file '
        'deleted)', () async {
      final id = await t.client('c@test.com');
      final first = await repo.saveProfilePhoto(
          userId: id, userType: 'client', bytes: const [1, 2, 3],
          sourcePath: sourcePhoto('a.jpg').path);
      expect(first, contains('profile_photos'));
      expect(File(first).existsSync(), isTrue);
      expect((await repo.getClientProfile(id)).photoPath, first);

      final second = await repo.saveProfilePhoto(
          userId: id, userType: 'client', bytes: const [4],
          sourcePath: sourcePhoto('b.png').path);
      expect((await repo.getClientProfile(id)).photoPath, second);
      expect(File(first).existsSync(), isFalse);
      expect(File(second).existsSync(), isTrue);
    });

    test('restaurant: each photo is appended to photo_paths', () async {
      final (owner, _) = await t.restaurant('r@test.com', 'R');
      final a = await repo.saveProfilePhoto(
          userId: owner, userType: 'restaurant', bytes: const [1],
          sourcePath: sourcePhoto('a.jpg').path);
      final b = await repo.saveProfilePhoto(
          userId: owner, userType: 'restaurant', bytes: const [2],
          sourcePath: sourcePhoto('b.jpg').path);
      expect((await repo.getRestaurantProfile(owner)).photoPaths, [a, b]);
    });

    test('missing source file → ProfileException', () async {
      final id = await t.client('c@test.com');
      await expectLater(
          repo.saveProfilePhoto(
              userId: id, userType: 'client', bytes: const [1]),
          throwsA(isA<ProfileException>()));
    });

    test('profile_photos (web bytes) rows go away with their user', () async {
      final id = await t.client('c@test.com');
      await t.db.insert('profile_photos', {
        'user_id': id, 'user_type': 'client', 'mime_type': 'image/png',
        'data': Uint8List.fromList([1, 2, 3]),
      });
      await t.db.delete('users', where: 'id = ?', whereArgs: [id]);
      expect(await t.count('profile_photos'), 0);
    });
  });
}
