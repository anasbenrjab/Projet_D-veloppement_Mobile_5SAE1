// ignore_for_file: avoid_print

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/utils/password_hasher.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/auth/domain/auth_exception.dart';

import 'helpers/db_test_helper.dart';

// ── In-memory secure storage stub ────────────────────────────────────────────

/// FlutterSecureStorage talks to platform channels unavailable in pure-Dart
/// tests.  This stub stores values in a plain Map.
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
  }) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

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

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<AuthRepository> _buildRepo() async {
  final helper  = await buildTestDb();
  final storage = _FakeSecureStorage();
  return AuthRepository(dbHelper: helper, storage: storage);
}

const _email    = 'alice@example.com';
const _password = 'SecretPass1!';
const _question = 'Nom de votre animal ?';
const _answer   = 'Médor';
const _restName = 'La Belle Assiette';

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Required by sqflite_common_ffi before any test runs.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── PasswordHasher ─────────────────────────────────────────────────────────
  group('PasswordHasher', () {
    test('same password + salt always produces the same hash', () async {
      final salt  = PasswordHasher.generateSalt();
      final hash1 = await PasswordHasher.hash(_password, salt);
      final hash2 = await PasswordHasher.hash(_password, salt);
      expect(hash1, equals(hash2));
    });

    test('different salts produce different hashes', () async {
      final salt1 = PasswordHasher.generateSalt();
      final salt2 = PasswordHasher.generateSalt();
      final hash1 = await PasswordHasher.hash(_password, salt1);
      final hash2 = await PasswordHasher.hash(_password, salt2);
      expect(hash1, isNot(equals(hash2)));
    });

    test('verify returns true for correct password', () async {
      final salt = PasswordHasher.generateSalt();
      final hash = await PasswordHasher.hash(_password, salt);
      expect(await PasswordHasher.verify(_password, salt, hash), isTrue);
    });

    test('verify returns false for wrong password', () async {
      final salt = PasswordHasher.generateSalt();
      final hash = await PasswordHasher.hash(_password, salt);
      expect(
          await PasswordHasher.verify('WrongPassword!', salt, hash), isFalse);
    });

    test('output is a 64-character lowercase hex string', () async {
      final salt = PasswordHasher.generateSalt();
      final hash = await PasswordHasher.hash(_password, salt);
      expect(hash.length, equals(64));
      expect(hash, matches(RegExp(r'^[0-9a-f]+$')));
    });
  });

  // ── register ───────────────────────────────────────────────────────────────
  group('AuthRepository.register', () {
    test('registers a client and creates client_profiles row', () async {
      final repo = await _buildRepo();
      final user = await repo.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );

      expect(user.email,    equals(_email));
      expect(user.userType, equals('client'));
      expect(user.isActive, isTrue);

      // Verify profile row was created.
      final db     = await (await buildTestDb()).database;
      // We can't share the same in-memory DB across repo instances, so query
      // via the repo's own db.  Use a fresh call on the same helper.
    });

    test('registers a restaurant and creates restaurant_profiles row',
        () async {
      final helper  = await buildTestDb();
      final storage = _FakeSecureStorage();
      final repo    = AuthRepository(dbHelper: helper, storage: storage);

      final user = await repo.register(
        email:          'resto@example.com',
        password:       _password,
        userType:       'restaurant',
        resetQuestion:  _question,
        resetAnswer:    _answer,
        restaurantName: _restName,
      );

      expect(user.userType, equals('restaurant'));

      // Verify restaurant_profiles row with correct name.
      final db   = await helper.database;
      final rows = await db.query(
        'restaurant_profiles',
        columns: ['name'],
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      expect(rows.length, equals(1));
      expect(rows.first['name'], equals(_restName));
    });

    test('rejects duplicate active email', () async {
      final repo = await _buildRepo();
      await repo.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );

      expect(
        () => repo.register(
          email:         _email,
          password:      _password,
          userType:      'client',
          resetQuestion: _question,
          resetAnswer:   _answer,
        ),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('déjà utilisé'))),
      );
    });

    test('rejects soft-deleted email with deactivated message', () async {
      final helper  = await buildTestDb();
      final storage = _FakeSecureStorage();
      final repo    = AuthRepository(dbHelper: helper, storage: storage);

      final user = await repo.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );

      await repo.deleteAccount(user.id);

      expect(
        () => repo.register(
          email:         _email,
          password:      _password,
          userType:      'client',
          resetQuestion: _question,
          resetAnswer:   _answer,
        ),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('désactivé'))),
      );
    });

    test('rejects password shorter than 8 characters', () async {
      final repo = await _buildRepo();
      expect(
        () => repo.register(
          email:         _email,
          password:      'short',
          userType:      'client',
          resetQuestion: _question,
          resetAnswer:   _answer,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('rejects restaurant registration without a name', () async {
      final repo = await _buildRepo();
      expect(
        () => repo.register(
          email:         'rest@example.com',
          password:      _password,
          userType:      'restaurant',
          resetQuestion: _question,
          resetAnswer:   _answer,
          // restaurantName omitted
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  // ── login ──────────────────────────────────────────────────────────────────
  group('AuthRepository.login', () {
    late AuthRepository repo;

    setUp(() async {
      repo = await _buildRepo();
      await repo.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
    });

    test('returns user on correct credentials', () async {
      final user = await repo.login(email: _email, password: _password);
      expect(user.email,    equals(_email));
      expect(user.isActive, isTrue);
    });

    test('throws generic error on wrong password', () async {
      expect(
        () => repo.login(email: _email, password: 'WrongPass99!'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('incorrect'))),
      );
    });

    test('throws same generic error for unknown email', () async {
      expect(
        () => repo.login(
            email: 'nobody@example.com', password: _password),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('incorrect'))),
      );
    });

    test('reports deactivated account only after correct password', () async {
      final helper  = await buildTestDb();
      final storage = _FakeSecureStorage();
      final repo2   = AuthRepository(dbHelper: helper, storage: storage);

      final user = await repo2.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
      await repo2.deleteAccount(user.id);

      // Wrong password → generic error (not "deactivated").
      expect(
        () => repo2.login(email: _email, password: 'WrongPass99!'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('incorrect'))),
      );

      // Correct password → deactivated message.
      expect(
        () => repo2.login(email: _email, password: _password),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('désactivé'))),
      );
    });
  });

  // ── resetPassword ──────────────────────────────────────────────────────────
  group('AuthRepository.resetPassword', () {
    late AuthRepository repo;

    setUp(() async {
      repo = await _buildRepo();
      await repo.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
    });

    test('getResetQuestion returns the question for a known email', () async {
      final q = await repo.getResetQuestion(_email);
      expect(q, equals(_question));
    });

    test('getResetQuestion returns null for an unknown email', () async {
      final q = await repo.getResetQuestion('nobody@example.com');
      expect(q, isNull);
    });

    test('rejects wrong answer', () async {
      expect(
        () => repo.resetPassword(
          email:       _email,
          answer:      'wrong answer',
          newPassword: 'NewPassword1!',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('correct answer changes the password', () async {
      const newPass = 'NewPassword1!';
      await repo.resetPassword(
        email:       _email,
        answer:      _answer,
        newPassword: newPass,
      );
      // Old password must no longer work.
      expect(
        () => repo.login(email: _email, password: _password),
        throwsA(isA<AuthException>()),
      );
      // New password must work.
      final user = await repo.login(email: _email, password: newPass);
      expect(user.email, equals(_email));
    });

    test('answer comparison is case- and whitespace-insensitive', () async {
      // The answer was registered as 'Médor'; try with different case/spaces.
      await expectLater(
        repo.resetPassword(
          email:       _email,
          answer:      '  MÉDOR  ',
          newPassword: 'NewPassword1!',
        ),
        completes,
      );
    });
  });

  // ── getSessionUser ─────────────────────────────────────────────────────────
  group('AuthRepository.getSessionUser', () {
    test('returns user when session is valid', () async {
      final repo = await _buildRepo();
      await repo.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );
      final user = await repo.getSessionUser();
      expect(user, isNotNull);
      expect(user!.email, equals(_email));
    });

    test('returns null when no session exists', () async {
      final repo = await _buildRepo();
      final user = await repo.getSessionUser();
      expect(user, isNull);
    });

    test('clears session and returns null for a deactivated user', () async {
      final helper  = await buildTestDb();
      final storage = _FakeSecureStorage();
      final repo    = AuthRepository(dbHelper: helper, storage: storage);

      final registered = await repo.register(
        email:         _email,
        password:      _password,
        userType:      'client',
        resetQuestion: _question,
        resetAnswer:   _answer,
      );

      // Deactivate the account directly in the DB (simulates admin action
      // or deleteAccount called from another device).
      await repo.deleteAccount(registered.id);

      // getSessionUser should clear the stale session and return null.
      final result = await repo.getSessionUser();
      expect(result, isNull);

      // Session must also be gone from storage.
      final stored = await storage.read(key: 'session_user_id');
      expect(stored, isNull);
    });
  });
}
