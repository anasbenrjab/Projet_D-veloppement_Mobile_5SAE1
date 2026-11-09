import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/core/utils/password_hasher.dart';

void main() {
  // A fixed salt keeps the expected values deterministic.
  final salt = '00' * 32;

  test('accented password round-trips', () async {
    const password = 'Crème9brûlée';
    final hash = await PasswordHasher.hash(password, salt);

    expect(await PasswordHasher.verify(password, salt, hash), isTrue);
    expect(await PasswordHasher.verify('Creme9brulee', salt, hash), isFalse);
  });

  test('hashes the UTF-8 bytes of the password', () async {
    const password = 'café1234';
    final actual = await PasswordHasher.hash(password, salt, iterations: 1);

    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 1,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: List<int>.filled(32, 0),
    );
    final expected = (await key.extractBytes())
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    expect(actual, expected);
  });

  test('characters above U+00FF do not collide with ASCII', () async {
    // U+0142 'ł' truncated to a byte is 0x42 'B'.
    final a = await PasswordHasher.hash('passłord1', salt, iterations: 1);
    final b = await PasswordHasher.hash('passBord1', salt, iterations: 1);
    expect(a, isNot(b));
  });
}
