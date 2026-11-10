// EvenementsRepository (Module 3) — reservations: create, read, update
// (modify, accept / refuse / cancel / honour / no-show); events: create,
// read, update, delete; constraints and cascades.

import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/core/data/validation_exception.dart';
import 'package:tablego/features/events/database/evenements_repository.dart';
import 'package:tablego/features/events/models/evenement.dart';
import 'package:tablego/features/events/models/reservation.dart';

import 'support.dart';

void main() {
  setUpAll(initFfi);

  late TestDb t;
  late EvenementsRepository repo;
  late int alice, bob, restaurantId, otherRestaurantId;

  setUp(() async {
    t = await TestDb.open();
    repo = EvenementsRepository(t.helper);
    alice = await t.client('alice@test.com', fullName: 'Alice');
    bob = await t.client('bob@test.com');
    (_, restaurantId) = await t.restaurant('r@test.com', 'Le Gourmet');
    (_, otherRestaurantId) = await t.restaurant('r2@test.com', 'Autre');
  });

  Reservation resa(int client,
          {int? restaurant,
          String date = '2099-03-20',
          String heure = '20:00',
          int nb = 2,
          String statut = Reservation.statutEnAttente}) =>
      Reservation(
        clientId: client,
        restaurantId: restaurant ?? restaurantId,
        date: date,
        heure: heure,
        nbPersonnes: nb,
        statut: statut,
        scoreNoShow: 0.1,
        createdAt: '2099-03-01T12:00:00',
      );

  Future<Reservation> byId(int id) async => Reservation.fromMap(
      (await t.db.query('reservation', where: 'id = ?', whereArgs: [id]))
          .single);

  group('reservations', () {
    test('create and read (client side, with restaurant name)', () async {
      final id = await repo.insererReservation(resa(alice));
      final mine = await repo.reservationsDuClient(alice);
      expect(mine.single.id, id);
      expect(mine.single.nomRestaurant, 'Le Gourmet');
      expect(mine.single.statut, Reservation.statutEnAttente);
      expect(await repo.reservationsDuClient(bob), isEmpty);
    });

    test('read (restaurant side): own restaurant only, client names, '
        'status filter', () async {
      await repo.insererReservation(resa(alice));
      await repo.insererReservation(
          resa(bob, statut: Reservation.statutAcceptee));
      await repo.insererReservation(resa(alice, restaurant: otherRestaurantId));
      final all =
          await repo.reservationsAvecClient(restaurantId: restaurantId);
      expect(all.map((r) => r['nom_client']).toSet(),
          {'Alice', 'bob@test.com'});
      final pending = await repo.reservationsAvecClient(
          restaurantId: restaurantId, statut: Reservation.statutEnAttente);
      expect(pending.single['client_id'], alice);
    });

    test('update: the client modifies date / hour / party size', () async {
      final id = await repo.insererReservation(resa(alice));
      final r = await byId(id);
      await repo.modifierReservation(Reservation(
        id: id, clientId: alice, restaurantId: restaurantId,
        date: '2099-03-21', heure: '21:30', nbPersonnes: 4,
        statut: r.statut, nbModifications: 1, scoreNoShow: 0.2,
        createdAt: r.createdAt,
      ));
      final updated = await byId(id);
      expect(updated.date, '2099-03-21');
      expect(updated.heure, '21:30');
      expect(updated.nbPersonnes, 4);
      expect(updated.nbModifications, 1);
      expect(updated.createdAt, r.createdAt);
    });

    test('update: accept, refuse, cancel, honour, no-show', () async {
      final a = await repo.insererReservation(resa(alice));
      final b = await repo.insererReservation(resa(bob));
      await repo.changerStatutReservation(a, Reservation.statutAcceptee);
      await repo.changerStatutReservation(b, Reservation.statutRefusee);
      expect((await byId(a)).statut, Reservation.statutAcceptee);
      expect((await byId(b)).statut, Reservation.statutRefusee);
      expect(await repo.sommePersonnesAcceptees(
          restaurantId, '2099-03-20', '20:00'), 2);

      await repo.changerStatutReservation(a, Reservation.statutAnnulee);
      expect(await repo.sommePersonnesAcceptees(
          restaurantId, '2099-03-20', '20:00'), 0); // cancelled frees seats

      await repo.changerStatutReservation(a, Reservation.statutNoShow);
      expect(await repo.compterNoShows(alice), 1);
      expect(await repo.compterNoShows(bob), 0);
    });

    test('a past or cancelled reservation is no longer modifiable', () {
      expect(resa(alice, date: '2000-01-01').estModifiable, isFalse);
      expect(resa(alice, statut: Reservation.statutAnnulee).estModifiable,
          isFalse);
      expect(resa(alice).estModifiable, isTrue);
    });

    test('constraints: unknown client / restaurant, party size > 0', () async {
      expect(repo.insererReservation(resa(999)), throwsConstraint);
      expect(repo.insererReservation(resa(alice, restaurant: 999)),
          throwsConstraint);
      expect(repo.insererReservation(resa(alice, nb: 0)), throwsConstraint);
      expect(await t.count('reservation'), 0);
    });

    test('cascade: deleting the client or the restaurant deletes the '
        'reservations', () async {
      await repo.insererReservation(resa(alice));
      await repo.insererReservation(resa(bob));
      await t.db.delete('users', where: 'id = ?', whereArgs: [alice]);
      expect(await t.count('reservation'), 1);
      await t.db.delete('restaurant_profiles',
          where: 'id = ?', whereArgs: [restaurantId]);
      expect(await t.count('reservation'), 0);
    });
  });

  group('events', () {
    Evenement event(String titre,
            {int? id, String date = '2099-05-01', int total = 30,
            int restantes = 30, int? restaurant}) =>
        Evenement(
          id: id,
          restaurantId: restaurant ?? restaurantId,
          titre: titre,
          type: Evenement.typeSoiree,
          date: date,
          description: 'Desc',
          placesTotal: total,
          placesRestantes: restantes,
        );

    test('create and read (sorted by date, per restaurant)', () async {
      await repo.insererEvenement(event('Jazz', date: '2099-06-01'));
      await repo.insererEvenement(event('Karaoké', date: '2099-05-01'));
      await repo.insererEvenement(
          event('Ailleurs', restaurant: otherRestaurantId));
      expect((await repo.evenements(restaurantId)).map((e) => e.titre),
          ['Karaoké', 'Jazz']);
    });

    test('read: upcoming only (client view)', () async {
      await repo.insererEvenement(event('Passé', date: '2000-01-01'));
      await repo.insererEvenement(event('Futur'));
      expect((await repo.evenements(restaurantId, aVenirSeulement: true))
          .map((e) => e.titre), ['Futur']);
    });

    test('update', () async {
      final id = await repo.insererEvenement(event('Soirée'));
      await repo.modifierEvenement(
          event('Soirée jazz', id: id, total: 40, restantes: 12));
      final e = (await repo.evenements(restaurantId)).single;
      expect(e.titre, 'Soirée jazz');
      expect(e.placesTotal, 40);
      expect(e.placesRestantes, 12);
    });

    test('delete', () async {
      final id = await repo.insererEvenement(event('À supprimer'));
      expect(await repo.supprimerEvenement(id), 1);
      expect(await repo.evenements(restaurantId), isEmpty);
      expect(await repo.supprimerEvenement(id), 0); // already gone
    });

    test('constraints: unknown restaurant; deleting the restaurant deletes '
        'its events', () async {
      expect(repo.insererEvenement(event('X', restaurant: 999)),
          throwsConstraint);
      await repo.insererEvenement(event('Y'));
      await t.db.delete('restaurant_profiles',
          where: 'id = ?', whereArgs: [restaurantId]);
      expect(await t.count('evenement'), 0);
    });
  });

  test('restaurant(): name and capacity per time slot', () async {
    final r = await repo.restaurant(restaurantId);
    expect(r.nom, 'Le Gourmet');
    expect(r.capaciteMax, 40);
    await expectLater(repo.restaurant(999), throwsA(isA<StateError>()));
  });

  group('safety rules', () {
    test('reservation status: only the allowed values (create, modify, '
        'change)', () async {
      await expectLater(repo.insererReservation(resa(alice, statut: 'perdue')),
          throwsA(isA<ValidationException>()));
      expect(await t.count('reservation'), 0);

      final id = await repo.insererReservation(resa(alice));
      await expectLater(repo.changerStatutReservation(id, 'confirmée'),
          throwsA(isA<ValidationException>()));
      final r = await byId(id);
      await expectLater(
          repo.modifierReservation(Reservation(
            id: id, clientId: alice, restaurantId: restaurantId,
            date: r.date, heure: r.heure, nbPersonnes: 3, statut: '',
            createdAt: r.createdAt,
          )),
          throwsA(isA<ValidationException>()));
      expect((await byId(id)).statut, Reservation.statutEnAttente);
      expect((await byId(id)).nbPersonnes, 2);

      for (final ok in Reservation.statuts) {
        await repo.changerStatutReservation(id, ok);
        expect((await byId(id)).statut, ok);
      }
    });

    test('event: 0 <= places restantes <= places totales', () async {
      Evenement e({int? id, required int total, required int restantes}) =>
          Evenement(
            id: id, restaurantId: restaurantId, titre: 'Soirée',
            type: Evenement.typeSoiree, date: '2099-05-01', description: '',
            placesTotal: total, placesRestantes: restantes,
          );
      for (final (total, restantes) in [(10, 11), (10, -1), (-1, -1)]) {
        await expectLater(
            repo.insererEvenement(e(total: total, restantes: restantes)),
            throwsA(isA<ValidationException>()),
            reason: '$total/$restantes');
      }
      expect(await t.count('evenement'), 0);

      final id = await repo.insererEvenement(e(total: 10, restantes: 10));
      expect(await repo.insererEvenement(e(total: 10, restantes: 0)), isNotNull);
      await expectLater(
          repo.modifierEvenement(e(id: id, total: 5, restantes: 8)),
          throwsA(isA<ValidationException>()));
      expect((await repo.evenements(restaurantId)).first.placesRestantes, 10);
    });
  });
}
