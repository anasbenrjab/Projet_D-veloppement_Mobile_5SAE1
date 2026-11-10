// AuthRepository — users: create (register), read (login / session),
// update (change & reset password), delete (soft delete), plus constraints.

import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/auth/domain/auth_exception.dart';

import 'support.dart';

const _pw = 'Password1!';

void main() {
  setUpAll(initFfi);

  late TestDb t;
  late FakeSecureStorage storage;
  late AuthRepository repo;

  setUp(() async {
    t = await TestDb.open();
    storage = FakeSecureStorage();
    repo = AuthRepository(dbHelper: t.helper, storage: storage);
  });

  Future<int> registerClient([String email = 'alice@test.com']) async =>
      (await repo.register(
        email: email, password: _pw, userType: 'client',
        resetQuestion: 'Animal ?', resetAnswer: 'Médor',
      )).id;

  group('create (register)', () {
    test('client: users + client_profiles rows, email normalised', () async {
      final user = await repo.register(
        email: '  Alice@Test.COM ', password: _pw, userType: 'client',
        resetQuestion: 'Animal ?', resetAnswer: 'Médor',
      );
      expect(user.email, 'alice@test.com');
      expect(user.userType, 'client');
      expect(user.isActive, isTrue);
      expect(await t.count('client_profiles', 'user_id = ?', [user.id]), 1);
      final row = (await t.db.query('users', where: 'id = ?',
          whereArgs: [user.id])).single;
      expect(row['password_hash'], isNot(_pw)); // hashed, never plain text
      expect(row['reset_answer_hash'], isNot('Médor'));
    });

    test('restaurant: users + restaurant_profiles rows', () async {
      final user = await repo.register(
        email: 'resto@test.com', password: _pw, userType: 'restaurant',
        resetQuestion: 'Q ?', resetAnswer: 'R', restaurantName: 'Chez Test',
      );
      final rp = (await t.db.query('restaurant_profiles',
          where: 'user_id = ?', whereArgs: [user.id])).single;
      expect(rp['name'], 'Chez Test');
      expect(rp['seat_capacity'], 40); // Module 3 default
    });

    test('unique email, case-insensitive', () async {
      await registerClient('alice@test.com');
      await expectLater(registerClient('ALICE@test.com'),
          throwsA(isA<AuthException>()
              .having((e) => e.message, 'message', 'Email déjà utilisé')));
      expect(await t.count('users'), 1);
    });

    test('the users.email UNIQUE constraint also holds below the repository',
        () async {
      await t.user('dup@test.com');
      expect(t.user('dup@test.com'), throwsConstraint);
    });

    test('invalid data is rejected and nothing is written', () async {
      Future<void> attempt({
        String email = 'x@test.com', String password = _pw,
        String type = 'client', String question = 'Q ?', String answer = 'A',
        String? restaurantName,
      }) =>
          repo.register(
            email: email, password: password, userType: type,
            resetQuestion: question, resetAnswer: answer,
            restaurantName: restaurantName,
          );

      for (final call in <Future<void> Function()>[
        () => attempt(email: 'not-an-email'),
        () => attempt(password: 'short'),
        () => attempt(type: 'admin'),
        () => attempt(question: ''),
        () => attempt(answer: ' '),
        () => attempt(type: 'restaurant'), // no restaurant name
      ]) {
        await expectLater(call(), throwsA(isA<AuthException>()));
      }
      expect(await t.count('users'), 0);
      expect(await t.count('client_profiles'), 0);
      expect(await t.count('restaurant_profiles'), 0);
    });

    test('user_type is CHECK-constrained in SQLite too', () async {
      expect(t.user('bad@test.com', type: 'admin'), throwsConstraint);
    });
  });

  group('read (login / session)', () {
    test('login returns the user and stores the session', () async {
      final id = await registerClient();
      await repo.logout();
      final user = await repo.login(email: 'ALICE@test.com', password: _pw);
      expect(user.id, id);
      expect((await repo.getSessionUser())?.id, id);
    });

    test('wrong password / unknown email: same generic error', () async {
      await registerClient();
      for (final (email, pw) in [
        ('alice@test.com', 'Wrong1!pass'),
        ('nobody@test.com', _pw),
      ]) {
        await expectLater(
            repo.login(email: email, password: pw),
            throwsA(isA<AuthException>().having((e) => e.message, 'message',
                'Email ou mot de passe incorrect')));
      }
    });

    test('no session → getSessionUser is null; logout keeps the row',
        () async {
      await registerClient();
      await repo.logout();
      expect(await repo.getSessionUser(), isNull);
      expect(await t.count('users'), 1);
    });
  });

  group('update (passwords)', () {
    test('changePassword: new one works, old one no longer', () async {
      final id = await registerClient();
      await repo.changePassword(
          userId: id, currentPassword: _pw, newPassword: 'NewPass2@');
      await expectLater(
          repo.login(email: 'alice@test.com', password: _pw),
          throwsA(isA<AuthException>()));
      expect((await repo.login(email: 'alice@test.com', password: 'NewPass2@'))
          .id, id);
    });

    test('changePassword: wrong current password or weak new one → error, '
        'password unchanged', () async {
      final id = await registerClient();
      await expectLater(
          repo.changePassword(
              userId: id, currentPassword: 'Wrong1!pass',
              newPassword: 'NewPass2@'),
          throwsA(isA<AuthException>().having((e) => e.message, 'message',
              'Mot de passe actuel incorrect')));
      await expectLater(
          repo.changePassword(
              userId: id, currentPassword: _pw, newPassword: 'weak'),
          throwsA(isA<AuthException>()));
      expect((await repo.login(email: 'alice@test.com', password: _pw)).id, id);
    });

    test('changePassword: unknown user', () async {
      await expectLater(
          repo.changePassword(
              userId: 999, currentPassword: _pw, newPassword: 'NewPass2@'),
          throwsA(isA<AuthException>()));
    });

    test('resetPassword with the security answer (trimmed, any case)',
        () async {
      await registerClient();
      expect(await repo.getResetQuestion('alice@test.com'), 'Animal ?');
      await repo.resetPassword(
          email: 'alice@test.com', answer: '  médor ', newPassword: 'Reset3#x');
      expect((await repo.login(email: 'alice@test.com', password: 'Reset3#x'))
          .email, 'alice@test.com');
      await expectLater(
          repo.resetPassword(
              email: 'alice@test.com', answer: 'wrong',
              newPassword: 'Reset4#x'),
          throwsA(isA<AuthException>()));
    });
  });

  group('delete (soft delete)', () {
    test('deleteAccount keeps the row inactive, ends the session, blocks '
        'login and the email', () async {
      final id = await registerClient();
      await repo.deleteAccount(id);

      final row = (await t.db.query('users', where: 'id = ?',
          whereArgs: [id])).single;
      expect(row['is_active'], 0);
      expect(storage.map, isEmpty);
      await expectLater(
          repo.login(email: 'alice@test.com', password: _pw),
          throwsA(isA<AuthException>().having((e) => e.message, 'message',
              'Ce compte a été désactivé')));
      await expectLater(registerClient('alice@test.com'),
          throwsA(isA<AuthException>()));
      // Soft delete: the profile is kept.
      expect(await t.count('client_profiles', 'user_id = ?', [id]), 1);
    });

    test('a hard delete of a user cascades to everything that is theirs',
        () async {
      final clientId = await t.client('c@test.com', fullName: 'C');
      final (ownerId, restaurantId) = await t.restaurant('r@test.com', 'R');
      final dishId = await t.dish(restaurantId, 'Plat');
      await t.db.insert('favorite_restaurants',
          {'user_id': clientId, 'restaurant_id': restaurantId});
      await t.db.insert('favorite_dishes',
          {'user_id': clientId, 'dish_id': dishId});
      await t.db.insert('cart_items', {'user_id': clientId, 'dish_id': dishId});
      final orderId = await t.db.insert('orders', {
        'user_id': clientId, 'restaurant_id': restaurantId,
        'order_type': 'sur place',
      });
      await t.db.insert('order_items', {
        'order_id': orderId, 'dish_id': dishId, 'dish_name': 'Plat',
        'dish_price': 10.0,
      });
      await t.db.insert('reservation', {
        'client_id': clientId, 'restaurant_id': restaurantId,
        'date': '2099-01-01', 'heure': '20:00', 'nb_personnes': 2,
        'statut': 'en_attente', 'created_at': '2099-01-01T00:00:00Z',
      });

      await t.db.delete('users', where: 'id = ?', whereArgs: [clientId]);
      for (final table in [
        'client_profiles', 'favorite_restaurants', 'favorite_dishes',
        'cart_items', 'orders', 'order_items', 'order_history', 'reservation',
      ]) {
        expect(await t.count(table), 0, reason: table);
      }

      // Deleting the restaurant owner removes the restaurant and its menu.
      await t.db.delete('users', where: 'id = ?', whereArgs: [ownerId]);
      expect(await t.count('restaurant_profiles'), 0);
      expect(await t.count('dishes'), 0);
    });
  });
}
