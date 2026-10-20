import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/password_hasher.dart';
import '../../domain/auth_exception.dart';
import '../models/user_model.dart';

// ── Session key ───────────────────────────────────────────────────────────────

const _kSessionKey = 'session_user_id';

// ── Private credential row ────────────────────────────────────────────────────

/// Holds the credential columns from the users table.
///
/// Never exposed outside this file.  [UserModel] intentionally omits these
/// fields; they are only needed inside [AuthRepository] for hashing operations.
class _CredentialsRow {
  const _CredentialsRow({
    required this.id,
    required this.passwordHash,
    required this.salt,
    required this.iterations,
    required this.isActive,
    this.resetAnswerHash,
    this.resetAnswerSalt,
  });

  final int id;
  final String passwordHash;
  final String salt;
  final int iterations;
  final int isActive; // raw 0/1 from DB
  final String? resetAnswerHash;
  final String? resetAnswerSalt;

  factory _CredentialsRow.fromMap(Map<String, dynamic> m) => _CredentialsRow(
        id:              m['id']                as int,
        passwordHash:    m['password_hash']     as String,
        salt:            m['salt']              as String,
        iterations:      m['password_iterations'] as int,
        isActive:        m['is_active']         as int,
        resetAnswerHash: m['reset_answer_hash'] as String?,
        resetAnswerSalt: m['reset_answer_salt'] as String?,
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class AuthRepository {
  AuthRepository({
    DatabaseHelper? dbHelper,
    FlutterSecureStorage? storage,
  })  : _db = dbHelper ?? DatabaseHelper.instance,
        _storage = storage ?? const FlutterSecureStorage();

  final DatabaseHelper _db;
  final FlutterSecureStorage _storage;

  // Exposed for testing only — allows test helpers to access the same DB.
  @visibleForTesting
  DatabaseHelper get dbHelperForTesting => _db;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<Database> get _database => _db.database;

  /// Runs [fn] and prints how long it took (debug builds only).
  Future<T> _timed<T>(String label, Future<T> Function() fn) async {
    if (!kDebugMode) return fn();
    final start = DateTime.now();
    final result = await fn();
    final ms = DateTime.now().difference(start).inMilliseconds;
    debugPrint('[AuthRepository] $label took ${ms}ms');
    return result;
  }

  // ── Session ──────────────────────────────────────────────────────────────────

  /// Saves the user id to secure storage as the active session.
  Future<void> _saveSession(int userId) =>
      _storage.write(key: _kSessionKey, value: userId.toString());

  /// Removes the session from secure storage.
  Future<void> _clearSession() => _storage.delete(key: _kSessionKey);

  // ── Queries ──────────────────────────────────────────────────────────────────

  /// Returns the [UserModel] columns only (no credentials).
  Future<UserModel?> _fetchUserModel(Database db, int id) async {
    final rows = await db.query(
      'users',
      columns: [
        'id', 'email', 'user_type', 'is_active',
        'reset_question', 'created_at', 'updated_at',
      ],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  /// Returns the credential row for [email] (lowercase), or null.
  Future<_CredentialsRow?> _fetchCredentials(Database db, String email) async {
    final rows = await db.query(
      'users',
      columns: [
        'id', 'password_hash', 'salt', 'password_iterations',
        'is_active', 'reset_answer_hash', 'reset_answer_salt',
      ],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _CredentialsRow.fromMap(rows.first);
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Registers a new user, hashing the password and security-question answer
  /// BEFORE opening the transaction, then atomically inserts the user row and
  /// the matching profile row.
  ///
  /// Throws [AuthException] if:
  /// - [email] is already registered and active → "Email déjà utilisé"
  /// - [email] is already registered but deactivated → "Compte désactivé …"
  /// - [userType] is `'restaurant'` and [restaurantName] is null/blank
  /// - any required field is missing
  Future<UserModel> register({
    required String email,
    required String password,
    required String userType,
    required String resetQuestion,
    required String resetAnswer,
    String? restaurantName, // required when userType == 'restaurant'
  }) async {
    // ── Input validation ────────────────────────────────────────────────────
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const AuthException('L\'email est requis');
    }
    // Basic format check — full regex validation is done in the form layer,
    // but we guard here too because the repository is the last line of defence.
    if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
      throw const AuthException('Format d\'email invalide');
    }
    if (password.length < 8) {
      throw const AuthException('Le mot de passe doit contenir au moins 8 caractères');
    }
    if (!['client', 'restaurant'].contains(userType)) {
      throw const AuthException('Type d\'utilisateur invalide');
    }
    if (resetQuestion.trim().isEmpty) {
      throw const AuthException('La question de sécurité est requise');
    }
    if (resetAnswer.trim().isEmpty) {
      throw const AuthException('La réponse de sécurité est requise');
    }
    if (userType == 'restaurant') {
      if (restaurantName == null || restaurantName.trim().isEmpty) {
        throw const AuthException('Le nom du restaurant est requis');
      }
    }

    final db = await _database;

    // ── Check existing email ─────────────────────────────────────────────────
    final existing = await db.query(
      'users',
      columns: ['id', 'is_active'],
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final isActive = (existing.first['is_active'] as int) == 1;
      if (isActive) {
        throw const AuthException('Email déjà utilisé');
      } else {
        // Soft-deleted account: do not reactivate, do not reveal the email
        // is soft-deleted (but a clear error is acceptable here per spec).
        throw const AuthException(
          'Ce compte a été désactivé. '
          'Créez un compte avec une adresse email différente.',
        );
      }
    }

    // ── Hash BEFORE transaction (expensive — must not block DB) ─────────────
    final passwordSalt = PasswordHasher.generateSalt();
    final passwordHash = await _timed(
      'register: hash password',
      () => PasswordHasher.hash(password, passwordSalt),
    );

    final answerSalt = PasswordHasher.generateSalt();
    final answerHash = await _timed(
      'register: hash answer',
      () => PasswordHasher.hash(
        resetAnswer.trim().toLowerCase(),
        answerSalt,
      ),
    );

    final now = DateTime.now().toUtc().toIso8601String();

    // ── Atomic insert ────────────────────────────────────────────────────────
    late UserModel createdUser;

    await db.transaction((txn) async {
      final userId = await txn.insert('users', {
        'email':               normalizedEmail,
        'password_hash':       passwordHash,
        'salt':                passwordSalt,
        'password_iterations': PasswordHasher.kPasswordIterations,
        'user_type':           userType,
        'is_active':           1,
        'reset_question':      resetQuestion.trim(),
        'reset_answer_hash':   answerHash,
        'reset_answer_salt':   answerSalt,
        'created_at':          now,
        'updated_at':          now,
      });

      if (userType == 'client') {
        await txn.insert('client_profiles', {
          'user_id':    userId,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.insert('restaurant_profiles', {
          'user_id':    userId,
          'name':       restaurantName!.trim(),
          'created_at': now,
          'updated_at': now,
        });
      }

      createdUser = UserModel(
        id:            userId,
        email:         normalizedEmail,
        userType:      userType,
        isActive:      true,
        createdAt:     now,
        updatedAt:     now,
        resetQuestion: resetQuestion.trim(),
      );
    });

    await _saveSession(createdUser.id);
    return createdUser;
  }

  /// Authenticates a user.
  ///
  /// Returns the same generic error for unknown email and wrong password to
  /// prevent user enumeration.  Reports deactivated account only AFTER the
  /// password is verified, so an attacker cannot use the error to enumerate
  /// valid emails.
  ///
  /// Throws [AuthException] on failure.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    const genericError = AuthException('Email ou mot de passe incorrect');

    final db = await _database;
    final normalizedEmail = email.trim().toLowerCase();

    final creds = await _fetchCredentials(db, normalizedEmail);

    if (creds == null) {
      // Unknown email: run a full dummy hash so the response time is
      // indistinguishable from a wrong-password attempt, preventing
      // timing-based user enumeration.
      await _timed(
        'login: dummy hash (unknown email)',
        () => PasswordHasher.verify(
          password,
          PasswordHasher.generateSalt(), // throwaway salt
          'a' * 64,                      // 64-char hex placeholder
        ),
      );
      throw genericError;
    }

    // Verify password FIRST — before checking is_active.
    final match = await _timed(
      'login: verify password',
      () => PasswordHasher.verify(
        password,
        creds.salt,
        creds.passwordHash,
        iterations: creds.iterations,
      ),
    );

    if (!match) throw genericError;

    // Only reveal "deactivated" after a correct password.
    if (creds.isActive == 0) {
      throw const AuthException('Ce compte a été désactivé');
    }

    final user = await _fetchUserModel(db, creds.id);
    if (user == null) throw genericError; // should never happen

    await _saveSession(user.id);
    return user;
  }

  /// Returns the security question for [email], or `null` if the email does
  /// not exist or has no question set.
  ///
  /// Intentionally returns `null` for both cases so the caller cannot
  /// distinguish "no such email" from "no question set".
  Future<String?> getResetQuestion(String email) async {
    final db = await _database;
    final rows = await db.query(
      'users',
      columns: ['reset_question'],
      where: 'email = ? AND is_active = 1',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final q = rows.first['reset_question'] as String?;
    return (q != null && q.isNotEmpty) ? q : null;
  }

  /// Resets the password after verifying the security-question answer.
  ///
  /// - Normalises the answer (trim + lowercase) before comparing.
  /// - Generates a new salt and uses the current [PasswordHasher.kPasswordIterations].
  /// - Throws [AuthException] if email not found, answer wrong, or account
  ///   inactive.  The error message does not reveal which condition failed.
  Future<void> resetPassword({
    required String email,
    required String answer,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw const AuthException(
          'Le nouveau mot de passe doit contenir au moins 8 caractères');
    }

    const genericError =
        AuthException('Réinitialisation impossible. Vérifiez vos informations.');

    final db = await _database;
    final normalizedEmail = email.trim().toLowerCase();

    final creds = await _fetchCredentials(db, normalizedEmail);
    if (creds == null || creds.isActive == 0) throw genericError;
    if (creds.resetAnswerHash == null || creds.resetAnswerSalt == null) {
      throw genericError;
    }

    // Verify the answer — same timing whether right or wrong.
    final answerMatch = await _timed(
      'resetPassword: verify answer',
      () => PasswordHasher.verify(
        answer.trim().toLowerCase(),
        creds.resetAnswerSalt!,
        creds.resetAnswerHash!,
      ),
    );
    if (!answerMatch) throw genericError;

    // Answer correct — hash new password with a fresh salt.
    final newSalt = PasswordHasher.generateSalt();
    final newHash = await _timed(
      'resetPassword: hash new password',
      () => PasswordHasher.hash(newPassword, newSalt),
    );

    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'users',
      {
        'password_hash':       newHash,
        'salt':                newSalt,
        'password_iterations': PasswordHasher.kPasswordIterations,
        'updated_at':          now,
      },
      where: 'id = ?',
      whereArgs: [creds.id],
    );
  }

  /// Changes the password for the authenticated user.
  ///
  /// Verifies [currentPassword] before accepting [newPassword].
  /// Generates a new salt and stores the current iteration count.
  /// Throws [AuthException] if the current password is wrong.
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw const AuthException(
          'Le nouveau mot de passe doit contenir au moins 8 caractères');
    }

    final db = await _database;
    final rows = await db.query(
      'users',
      columns: ['password_hash', 'salt', 'password_iterations'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('Utilisateur introuvable');
    }

    final storedHash = rows.first['password_hash'] as String;
    final salt       = rows.first['salt']           as String;
    final iterations = rows.first['password_iterations'] as int;

    final match = await _timed(
      'changePassword: verify current',
      () => PasswordHasher.verify(
        currentPassword,
        salt,
        storedHash,
        iterations: iterations,
      ),
    );
    if (!match) {
      throw const AuthException('Mot de passe actuel incorrect');
    }

    final newSalt = PasswordHasher.generateSalt();
    final newHash = await _timed(
      'changePassword: hash new',
      () => PasswordHasher.hash(newPassword, newSalt),
    );

    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'users',
      {
        'password_hash':       newHash,
        'salt':                newSalt,
        'password_iterations': PasswordHasher.kPasswordIterations,
        'updated_at':          now,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Returns the [UserModel] for the stored session id, or `null` if:
  /// - no session exists
  /// - the stored id does not match any row
  /// - the matched user is inactive
  ///
  /// In all failure cases the session is cleared from secure storage.
  Future<UserModel?> getSessionUser() async {
    final raw = await _storage.read(key: _kSessionKey);
    final userId = int.tryParse(raw ?? '');
    if (userId == null) return null;

    final db = await _database;
    final user = await _fetchUserModel(db, userId);

    if (user == null || !user.isActive) {
      await _clearSession();
      return null;
    }

    return user;
  }

  /// Soft-deletes the account and clears the session.
  ///
  /// The row is kept with [is_active] = 0 so the email cannot be reused
  /// for a new account.
  Future<void> deleteAccount(int userId) async {
    final db = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'users',
      {'is_active': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await _clearSession();
  }

  /// Removes the session token.  Does not touch the database row.
  Future<void> logout() => _clearSession();
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);
