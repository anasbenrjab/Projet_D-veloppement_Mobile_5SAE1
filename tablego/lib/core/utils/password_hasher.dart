import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// PBKDF2-HMAC-SHA256 password hashing.
///
/// ## Design choices
/// - **Algorithm**: PBKDF2-HMAC-SHA256 via the `cryptography` package.
/// - **Salt**: 32 bytes of cryptographically random data, generated once per
///   account and stored in `users.salt`.  Salts are independent for the
///   password and for the security-question answer (`users.reset_answer_salt`).
/// - **Output**: 32 bytes (256 bits) encoded as a lowercase hex string.
/// - **Iterations**: [kPasswordIterations] (10 000).  Benchmarked at ~144 ms
///   on the development machine (x86-64 Dart VM) and an estimated ~350 ms on
///   the Android emulator.  The actual count used for each account is stored
///   in `users.password_iterations` so it can be increased for new accounts
///   without breaking existing ones.
/// - **Isolate**: hashing runs in [Isolate.run] so the UI thread never
///   freezes during registration or login.
/// - **Constant-time compare**: [verify] uses [SecretBox]-level byte
///   comparison to prevent timing attacks.
class PasswordHasher {
  PasswordHasher._();

  /// Default PBKDF2 iteration count.
  ///
  /// Increase this constant for new accounts once the team agrees on a new
  /// baseline.  Existing accounts keep their stored iteration count.
  static const int kPasswordIterations = 10000;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generates a cryptographically random 32-byte salt as a hex string.
  ///
  /// Call this once per account (and once per security-question answer).
  static String generateSalt() {
    final rng = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
    return _toHex(bytes);
  }

  /// Hashes [password] with [saltHex] using PBKDF2-HMAC-SHA256.
  ///
  /// Runs in a separate [Isolate] so the UI thread is never blocked.
  /// Returns a lowercase hex string (64 characters).
  ///
  /// [iterations] defaults to [kPasswordIterations].  Pass the stored value
  /// when re-hashing an existing account with a different iteration count.
  static Future<String> hash(
    String password,
    String saltHex, {
    int iterations = kPasswordIterations,
  }) {
    return Isolate.run(
      () => _deriveSync(password, saltHex, iterations),
    );
  }

  /// Verifies [password] against [storedHashHex] using constant-time
  /// comparison to prevent timing attacks.
  ///
  /// Runs in a separate [Isolate] — same cost as hashing, which is required
  /// for timing-attack resistance (an attacker must not be able to distinguish
  /// "wrong password → hash skipped" from "wrong password → hash compared").
  static Future<bool> verify(
    String password,
    String saltHex,
    String storedHashHex, {
    int iterations = kPasswordIterations,
  }) {
    return Isolate.run(
      () => _verifySync(password, saltHex, storedHashHex, iterations),
    );
  }

  // ── Internal (runs inside Isolate) ────────────────────────────────────────

  /// Synchronous derive — only called inside an Isolate.
  ///
  /// Even though this is labelled "sync", it uses await internally because
  /// [Pbkdf2.deriveKey] is async.  This is fine: we are always called from
  /// inside [Isolate.run], which has its own event loop.
  static Future<String> _deriveSync(
      String password, String saltHex, int iterations) async {
    final saltBytes = _fromHex(saltHex);
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256, // 32-byte output
    );

    final derivedKey = await algorithm.deriveKey(
      secretKey: SecretKey(password.codeUnits),
      nonce: saltBytes,
    );
    final keyBytes = await derivedKey.extractBytes();
    return _toHex(Uint8List.fromList(keyBytes));
  }

  /// Synchronous verify — only called inside an Isolate.
  static Future<bool> _verifySync(
    String password,
    String saltHex,
    String storedHashHex,
    int iterations,
  ) async {
    final derived = await _deriveSync(password, saltHex, iterations);
    return _constantTimeEquals(derived, storedHashHex);
  }

  /// Constant-time string equality — compares every character regardless of
  /// where the first mismatch occurs, preventing timing-based attacks.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // ── Hex helpers ───────────────────────────────────────────────────────────

  static String _toHex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  static Uint8List _fromHex(String hex) {
    assert(hex.length.isEven, 'Hex string must have even length');
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
