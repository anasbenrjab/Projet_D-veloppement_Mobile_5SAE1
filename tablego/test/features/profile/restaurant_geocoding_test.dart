// Restaurant save + background geocoding: the save never depends on
// Nominatim, and coordinates follow the address.

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/services/geocoding_service.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/profile/data/repositories/profile_repository.dart';
import 'package:tablego/features/profile/providers/profile_provider.dart';

import '../auth/helpers/db_test_helper.dart';

class _MemoryStorage extends Fake implements FlutterSecureStorage {
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
}

const _rivoli = '12 Rue de Rivoli, Paris 75001';
const _rivoliJson = '[{"lat":"48.8556009","lon":"2.3599124"}]';
const _opera = 'Place de l\'Opéra, Paris';
const _operaJson = '[{"lat":"48.8709","lon":"2.3318"}]';

/// Builds a notifier over a fresh DB with one restaurant account, whose
/// geocoder answers through [handler].  Also returns the request count.
Future<({ProfileNotifier notifier, ProfileRepository repo, int userId,
        List<Uri> requests})>
    _setUp(Future<http.Response> Function(http.Request) handler) async {
  final helper = await buildTestDb();
  final requests = <Uri>[];
  final geocoder = GeocodingService(
    timeout: const Duration(milliseconds: 100),
    client: MockClient((req) {
      requests.add(req.url);
      return handler(req);
    }),
  );
  final repo = ProfileRepository(dbHelper: helper, geocoder: geocoder);
  final user = await AuthRepository(dbHelper: helper, storage: _MemoryStorage())
      .register(
    email: 'resto@geo.test',
    password: 'Password1!',
    userType: 'restaurant',
    resetQuestion: 'Q ?',
    resetAnswer: 'r',
    restaurantName: 'Chez Geo',
  );
  return (
    notifier: ProfileNotifier(repo),
    repo: repo,
    userId: user.id,
    requests: requests,
  );
}

http.Response _json(String body, [int status = 200]) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

Future<void> _save(ProfileNotifier n, int userId, String address) async {
  final ok = await n.updateRestaurantProfile(
    userId: userId,
    name: 'Chez Geo',
    address: address,
  );
  expect(ok, isTrue, reason: 'the save itself must succeed');
  await n.pendingGeocoding;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('success: coordinates are stored and shown', () async {
    final s = await _setUp((_) async => _json(_rivoliJson));
    await _save(s.notifier, s.userId, _rivoli);

    final profile = await s.repo.getRestaurantProfile(s.userId);
    expect(profile.address, _rivoli);
    expect(profile.latitude, closeTo(48.8556, 1e-4));
    expect(profile.longitude, closeTo(2.3599, 1e-4));
  });

  final failures = <String, Future<http.Response> Function(http.Request)>{
    'offline': (_) async => throw const SocketException('no network'),
    'HTTP 500': (_) async => _json('error', 500),
    'empty result': (_) async => _json('[]'),
    'timeout': (_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      return _json(_rivoliJson);
    },
  };

  failures.forEach((label, handler) {
    test('save still works when geocoding fails ($label)', () async {
      final s = await _setUp(handler);
      await _save(s.notifier, s.userId, _rivoli);

      final profile = await s.repo.getRestaurantProfile(s.userId);
      expect(profile.address, _rivoli);
      expect(profile.latitude, isNull);
      expect(profile.longitude, isNull);
      expect(s.notifier.state.error, isNull);
      expect(s.requests, hasLength(1));
    });
  });

  test('same address with coordinates: no new request', () async {
    final s = await _setUp((_) async => _json(_rivoliJson));
    await _save(s.notifier, s.userId, _rivoli);
    // Same address, different spacing and case.
    await _save(s.notifier, s.userId, '  12 rue de Rivoli,  Paris 75001 ');

    expect(s.requests, hasLength(1));
    final profile = await s.repo.getRestaurantProfile(s.userId);
    expect(profile.latitude, isNotNull);
  });

  test('changed address: old coordinates dropped, new ones fetched', () async {
    final s = await _setUp((req) async => _json(
        req.url.queryParameters['q'] == _opera ? _operaJson : _rivoliJson));
    await _save(s.notifier, s.userId, _rivoli);
    await _save(s.notifier, s.userId, _opera);

    expect(s.requests, hasLength(2));
    final profile = await s.repo.getRestaurantProfile(s.userId);
    expect(profile.latitude, closeTo(48.8709, 1e-4));
  });

  test('changed address + failed lookup: no stale coordinates', () async {
    var online = true;
    final s = await _setUp((_) async {
      if (!online) throw const SocketException('offline');
      return _json(_rivoliJson);
    });
    await _save(s.notifier, s.userId, _rivoli);
    online = false;
    await _save(s.notifier, s.userId, _opera);

    final profile = await s.repo.getRestaurantProfile(s.userId);
    expect(profile.address, _opera);
    expect(profile.latitude, isNull, reason: 'Rivoli coords must not stay');
  });

  test('missing coordinates are retried on the next save', () async {
    var online = false;
    final s = await _setUp((_) async {
      if (!online) throw const SocketException('offline');
      return _json(_rivoliJson);
    });
    await _save(s.notifier, s.userId, _rivoli);
    online = true;
    await _save(s.notifier, s.userId, _rivoli);

    expect(s.requests, hasLength(2));
    final profile = await s.repo.getRestaurantProfile(s.userId);
    expect(profile.latitude, isNotNull);
  });

  test('cleared address: no request, no coordinates', () async {
    final s = await _setUp((_) async => _json(_rivoliJson));
    await _save(s.notifier, s.userId, _rivoli);
    await _save(s.notifier, s.userId, '');

    expect(s.requests, hasLength(1));
    final profile = await s.repo.getRestaurantProfile(s.userId);
    expect(profile.latitude, isNull);
  });
}
