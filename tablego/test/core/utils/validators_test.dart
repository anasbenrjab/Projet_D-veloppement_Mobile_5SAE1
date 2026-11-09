import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/core/utils/validators.dart';

void main() {
  group('Validators.emailError', () {
    for (final ok in [
      'client@test.com',
      'Jean.Dupont+resa@mail.example.fr',
      '  padded@example.org  ',
    ]) {
      test('accepts "$ok"', () => expect(Validators.emailError(ok), isNull));
    }

    for (final bad in [
      '',
      'a@.',
      'no-at.example.com',
      'two@@example.com',
      'space in@example.com',
      'user@domain',
      'user@domain.c',
      'user@-domain.com',
    ]) {
      test('rejects "$bad"',
          () => expect(Validators.emailError(bad), isNotNull));
    }
  });

  group('Validators.passwordError', () {
    test('accepts 8+ chars with a letter and a digit', () {
      expect(Validators.passwordError('password123'), isNull);
      expect(Validators.passwordError('Crème9brûlée'), isNull);
    });

    test('rejects too short', () {
      expect(Validators.passwordError('abc1234'), 'Au moins 8 caractères');
    });

    test('rejects letters only and digits only', () {
      expect(Validators.passwordError('motdepasse'), isNotNull);
      expect(Validators.passwordError('12345678'), isNotNull);
    });

    test('rejects empty', () {
      expect(Validators.passwordError(''), 'Mot de passe requis');
      expect(Validators.passwordError(null), 'Mot de passe requis');
    });
  });
}
