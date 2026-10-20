import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/auth/domain/auth_exception.dart';
import 'package:tablego/features/profile/data/models/client_profile_model.dart';
import 'package:tablego/features/profile/data/models/restaurant_profile_model.dart';
import 'package:tablego/features/profile/data/repositories/profile_repository.dart';
import 'package:tablego/features/profile/domain/profile_exception.dart';

import '../auth/helpers/db_test_helper.dart';

// ── Fake secure storage (same as in auth tests) ───────────────────────────────

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final _map = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      value == null ? _map.remove(key) : _map[key] = value;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _map[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _map.remove(key);
}

// ── Shared fixture constants ──────────────────────────────────────────────────

const _clientEmail  = 'client@example.com';
const _restEmail    = 'resto@example.com';
const _password     = 'SecretPass1!';
const _question     = 'Nom de votre animal ?';
const _answer       = 'Médor';
const _restName     = 'La Belle Assiette';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns a fresh triple of (helper, AuthRepository, ProfileRepository)
/// all sharing the same in-memory database.
Future<({DatabaseHelper helper, AuthRepository auth, ProfileRepository profile})>
    _buildRepos() async {
  final helper  = await buildTestDb();
  final storage = _FakeSecureStorage();
  return (
    helper:  helper,
    auth:    AuthRepository(dbHelper: helper, storage: storage),
    profile: ProfileRepository(dbHelper: helper),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── ClientProfileModel JSON round-trip ─────────────────────────────────────
  group('ClientProfileModel', () {
    test('fromMap decodes JSON dietary_preferences string', () {
      final map = {
        'id':                   1,
        'email':                'a@b.com',
        'user_type':            'client',
        'created_at':           '2026-01-01T00:00:00Z',
        'full_name':            'Alice',
        'phone':                null,
        'photo_path':           null,
        'dietary_preferences':  jsonEncode(['halal', 'vegan']),
        'allergies':            jsonEncode(['peanuts']),
      };
      final model = ClientProfileModel.fromMap(map);
      expect(model.dietaryPreferences, equals(['halal', 'vegan']));
      expect(model.allergies, equals(['peanuts']));
    });

    test('fromMap handles null JSON columns gracefully', () {
      final map = {
        'id': 1, 'email': 'a@b.com', 'user_type': 'client',
        'created_at': '2026-01-01T00:00:00Z',
        'full_name': null, 'phone': null, 'photo_path': null,
        'dietary_preferences': null, 'allergies': null,
      };
      final model = ClientProfileModel.fromMap(map);
      expect(model.dietaryPreferences, isEmpty);
      expect(model.allergies, isEmpty);
    });

    test('fromMap handles malformed JSON string with empty fallback', () {
      final map = {
        'id': 1, 'email': 'a@b.com', 'user_type': 'client',
        'created_at': '2026-01-01T00:00:00Z',
        'full_name': null, 'phone': null, 'photo_path': null,
        'dietary_preferences': 'NOT_JSON', 'allergies': '{bad}',
      };
      final model = ClientProfileModel.fromMap(map);
      expect(model.dietaryPreferences, isEmpty);
      expect(model.allergies, isEmpty);
    });

    test('toMap re-encodes lists as JSON strings', () {
      const model = ClientProfileModel(
        id: 1, email: 'a@b.com', userType: 'client',
        createdAt: '2026-01-01T00:00:00Z',
        dietaryPreferences: ['halal'],
        allergies: ['eggs'],
      );
      final map = model.toMap();
      expect(jsonDecode(map['dietary_preferences'] as String), equals(['halal']));
      expect(jsonDecode(map['allergies'] as String), equals(['eggs']));
    });
  });

  // ── RestaurantProfileModel JSON round-trip ─────────────────────────────────
  group('RestaurantProfileModel', () {
    test('fromMap decodes JSON opening_hours string', () {
      final hours = {'mon': {'open': '11:00', 'close': '23:00'}};
      final map = {
        'id': 1, 'email': 'r@b.com', 'user_type': 'restaurant',
        'created_at': '2026-01-01T00:00:00Z',
        'name': 'Resto', 'address': null, 'latitude': null, 'longitude': null,
        'cuisine_type': null, 'description': null,
        'opening_hours': jsonEncode(hours),
        'photo_paths':   jsonEncode(['path/a.jpg']),
      };
      final model = RestaurantProfileModel.fromMap(map);
      expect(model.openingHours['mon'], equals({'open': '11:00', 'close': '23:00'}));
      expect(model.photoPaths, equals(['path/a.jpg']));
    });

    test('fromMap handles null JSON columns gracefully', () {
      final map = {
        'id': 1, 'email': 'r@b.com', 'user_type': 'restaurant',
        'created_at': '2026-01-01T00:00:00Z',
        'name': 'Resto', 'address': null, 'latitude': null, 'longitude': null,
        'cuisine_type': null, 'description': null,
        'opening_hours': null, 'photo_paths': null,
      };
      final model = RestaurantProfileModel.fromMap(map);
      expect(model.openingHours, isEmpty);
      expect(model.photoPaths, isEmpty);
    });

    test('toMap re-encodes maps and lists as JSON strings', () {
      final model = RestaurantProfileModel(
        id: 1, email: 'r@b.com', userType: 'restaurant',
        createdAt: '2026-01-01T00:00:00Z', name: 'Resto',
        openingHours: {'fri': {'open': '18:00', 'close': '23:00'}},
        photoPaths: ['/docs/a.jpg', '/docs/b.jpg'],
      );
      final map = model.toMap();
      final decodedHours = jsonDecode(map['opening_hours'] as String) as Map;
      expect(decodedHours['fri'], equals({'open': '18:00', 'close': '23:00'}));
      final decodedPaths = jsonDecode(map['photo_paths'] as String) as List;
      expect(decodedPaths, equals(['/docs/a.jpg', '/docs/b.jpg']));
    });
  });

  // ── get / update client profile ────────────────────────────────────────────
  group('ProfileRepository — client', () {
    late AuthRepository    authRepo;
    late ProfileRepository profileRepo;
    late DatabaseHelper    helper;
    late int               userId;

    setUp(() async {
      final repos = await _buildRepos();
      helper      = repos.helper;
      authRepo    = repos.auth;
      profileRepo = repos.profile;

      final user = await authRepo.register(
        email:         _clientEmail,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
      userId = user.id;
    });

    test('getClientProfile returns a ClientProfileModel', () async {
      final profile = await profileRepo.getClientProfile(userId);
      expect(profile, isA<ClientProfileModel>());
      expect(profile.email,    equals(_clientEmail));
      expect(profile.userType, equals('client'));
    });

    test('updateClientProfile persists full_name and phone', () async {
      await profileRepo.updateClientProfile(
        userId:   userId,
        fullName: 'Alice Dupont',
        phone:    '+33 6 12 34 56 78',
      );
      final profile = await profileRepo.getClientProfile(userId);
      expect(profile.fullName, equals('Alice Dupont'));
      expect(profile.phone,    equals('+33 6 12 34 56 78'));
    });

    test('updateClientProfile persists dietary_preferences and allergies',
        () async {
      await profileRepo.updateClientProfile(
        userId:             userId,
        dietaryPreferences: ['halal', 'vegan'],
        allergies:          ['peanuts', 'gluten'],
      );
      final profile = await profileRepo.getClientProfile(userId);
      expect(profile.dietaryPreferences, equals(['halal', 'vegan']));
      expect(profile.allergies,          equals(['peanuts', 'gluten']));
    });

    test('updated_at is set after update', () async {
      final before = DateTime.now().toUtc();
      await profileRepo.updateClientProfile(
          userId: userId, fullName: 'Bob');
      final db   = await helper.database;
      final rows = await db.query('client_profiles',
          columns: ['updated_at'],
          where: 'user_id = ?',
          whereArgs: [userId]);
      final updatedAt =
          DateTime.parse(rows.first['updated_at'] as String);
      expect(updatedAt.isAfter(before) || updatedAt.isAtSameMomentAs(before),
          isTrue);
    });

    test('rejects empty full_name', () {
      expect(
        () => profileRepo.updateClientProfile(userId: userId, fullName: '  '),
        throwsA(isA<ProfileException>()),
      );
    });

    test('rejects invalid phone format', () {
      expect(
        () => profileRepo.updateClientProfile(
            userId: userId, phone: 'abc'),
        throwsA(isA<ProfileException>()),
      );
    });
  });

  group('ProfileRepository — restaurant', () {
    late AuthRepository    authRepo;
    late ProfileRepository profileRepo;
    late int               userId;

    setUp(() async {
      final repos = await _buildRepos();
      authRepo    = repos.auth;
      profileRepo = repos.profile;

      final user = await authRepo.register(
        email:          _restEmail,
        password:       _password,
        userType:       'restaurant',
        resetQuestion:  _question,
        resetAnswer:    _answer,
        restaurantName: _restName,
      );
      userId = user.id;
    });

    test('getRestaurantProfile returns a RestaurantProfileModel', () async {
      final profile = await profileRepo.getRestaurantProfile(userId);
      expect(profile, isA<RestaurantProfileModel>());
      expect(profile.email,    equals(_restEmail));
      expect(profile.userType, equals('restaurant'));
      expect(profile.name,     equals(_restName));
    });

    test('updateRestaurantProfile persists name, address, cuisineType',
        () async {
      await profileRepo.updateRestaurantProfile(
        userId:      userId,
        name:        'Le Nouveau Nom',
        address:     '42 Rue de la Paix',
        cuisineType: 'French',
      );
      final profile = await profileRepo.getRestaurantProfile(userId);
      expect(profile.name,        equals('Le Nouveau Nom'));
      expect(profile.address,     equals('42 Rue de la Paix'));
      expect(profile.cuisineType, equals('French'));
    });

    test('updateRestaurantProfile persists opening_hours JSON', () async {
      final hours = {
        'mon': {'open': '11:00', 'close': '23:00'},
        'fri': {'open': '11:00', 'close': '01:00'},
      };
      await profileRepo.updateRestaurantProfile(
          userId: userId, openingHours: hours);
      final profile = await profileRepo.getRestaurantProfile(userId);
      expect(profile.openingHours['mon'],
          equals({'open': '11:00', 'close': '23:00'}));
      expect(profile.openingHours['fri'],
          equals({'open': '11:00', 'close': '01:00'}));
    });

    test('rejects empty restaurant name', () {
      expect(
        () => profileRepo.updateRestaurantProfile(
            userId: userId, name: '   '),
        throwsA(isA<ProfileException>().having(
            (e) => e.message, 'message', contains('vide'))),
      );
    });
  });

  group('ProfileRepository — role checks', () {
    late AuthRepository    authRepo;
    late ProfileRepository profileRepo;
    late int               clientId;
    late int               restaurantId;

    setUp(() async {
      final repos = await _buildRepos();
      authRepo    = repos.auth;
      profileRepo = repos.profile;

      final client = await authRepo.register(
        email:         _clientEmail,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
      clientId = client.id;

      final resto = await authRepo.register(
        email:          _restEmail,
        password:       _password,
        userType:       'restaurant',
        resetQuestion:  _question,
        resetAnswer:    _answer,
        restaurantName: _restName,
      );
      restaurantId = resto.id;
    });

    test('client user cannot update restaurant profile', () {
      expect(
        () => profileRepo.updateRestaurantProfile(
            userId: clientId, name: 'Hacked Name'),
        throwsA(isA<ProfileException>().having(
            (e) => e.message, 'message', contains('restaurant'))),
      );
    });

    test('restaurant user cannot update client profile', () {
      expect(
        () => profileRepo.updateClientProfile(
            userId: restaurantId, fullName: 'Hacked'),
        throwsA(isA<ProfileException>().having(
            (e) => e.message, 'message', contains('client'))),
      );
    });

    test('getClientProfile rejects a restaurant user id', () {
      expect(
        () => profileRepo.getClientProfile(restaurantId),
        throwsA(isA<ProfileException>()),
      );
    });

    test('getRestaurantProfile rejects a client user id', () {
      expect(
        () => profileRepo.getRestaurantProfile(clientId),
        throwsA(isA<ProfileException>()),
      );
    });
  });

  // ── AuthException still surfaces cleanly ──────────────────────────────────
  group('AuthRepository — unchanged after profile step', () {
    test('login still works after db schema unchanged', () async {
      final repos = await _buildRepos();
      await repos.auth.register(
        email:         _clientEmail,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
      final user =
          await repos.auth.login(email: _clientEmail, password: _password);
      expect(user.email, equals(_clientEmail));
    });

    test('wrong password still throws AuthException', () async {
      final repos = await _buildRepos();
      await repos.auth.register(
        email:         _clientEmail,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
      expect(
        () => repos.auth.login(email: _clientEmail, password: 'wrong!'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
