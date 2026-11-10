// Module 3 (événements + réservations) on the shared TableGo database:
// reservations reference users.id / restaurant_profiles.id, everything is
// scoped to one restaurant, and the demo seed attaches to the seed accounts.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/data/current_restaurant.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/seeds/events_seed.dart';
import 'package:tablego/features/events/database/evenements_repository.dart';
import 'package:tablego/features/events/models/evenement.dart';
import 'package:tablego/features/events/models/reservation.dart';
import 'package:tablego/features/events/services/ai_service.dart';
import 'package:tablego/features/events/utils/aide_dates.dart';

import '../auth/helpers/db_test_helper.dart';

class _Fixture {
  _Fixture(this.helper, this.db);

  final DatabaseHelper helper;
  final Database db;
  late final int clientId, otherClientId, restaurantId, otherRestoId;

  EvenementsRepository get repo => EvenementsRepository(helper);

  static Future<_Fixture> create() async {
    final helper = await buildTestDb();
    final f = _Fixture(helper, await helper.database);
    Future<int> user(String email, String type) => f.db.insert('users', {
          'email': email, 'password_hash': 'h', 'salt': 's',
          'password_iterations': 1, 'user_type': type,
        });
    f.clientId = await user('client@m3.test', 'client');
    f.otherClientId = await user('anon@m3.test', 'client');
    await f.db.insert('client_profiles',
        {'user_id': f.clientId, 'full_name': 'Alice Martin'});
    final owner = await user('resto@m3.test', 'restaurant');
    final owner2 = await user('resto2@m3.test', 'restaurant');
    f.restaurantId = await f.db.insert('restaurant_profiles',
        {'user_id': owner, 'name': 'Le Gourmet', 'seat_capacity': 10});
    f.otherRestoId = await f.db.insert(
        'restaurant_profiles', {'user_id': owner2, 'name': 'Autre'});
    return f;
  }

  Future<int> reserve(int client, int restaurant,
          {String date = '2099-01-02', String heure = '20:00',
          int nb = 2, String statut = Reservation.statutAcceptee}) =>
      repo.insererReservation(Reservation(
        clientId: client,
        restaurantId: restaurant,
        date: date,
        heure: heure,
        nbPersonnes: nb,
        statut: statut,
        createdAt: AideDates.maintenantIso(),
      ));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('restaurant(): name and seat capacity come from restaurant_profiles',
      () async {
    final f = await _Fixture.create();
    final r = await f.repo.restaurant(f.restaurantId);
    expect(r.nom, 'Le Gourmet');
    expect(r.capaciteMax, 10);
    expect((await f.repo.restaurant(f.otherRestoId)).capaciteMax, 40);
  });

  test('restaurant side only sees its own reservations, with the client '
      'name from the TableGo profile (or the email)', () async {
    final f = await _Fixture.create();
    await f.reserve(f.clientId, f.restaurantId);
    await f.reserve(f.otherClientId, f.restaurantId);
    await f.reserve(f.clientId, f.otherRestoId);

    final lignes =
        await f.repo.reservationsAvecClient(restaurantId: f.restaurantId);
    expect(lignes.map((l) => l['nom_client']).toSet(),
        {'Alice Martin', 'anon@m3.test'});
  });

  test('client side: all reservations with the restaurant name, or one '
      "restaurant's", () async {
    final f = await _Fixture.create();
    await f.reserve(f.clientId, f.restaurantId);
    await f.reserve(f.clientId, f.otherRestoId);

    final toutes = await f.repo.reservationsDuClient(f.clientId);
    expect(toutes.map((r) => r.nomRestaurant).toSet(),
        {'Le Gourmet', 'Autre'});
    final ici = await f.repo
        .reservationsDuClient(f.clientId, restaurantId: f.restaurantId);
    expect(ici.single.restaurantId, f.restaurantId);
  });

  test('AI: a slot is full against this restaurant capacity only', () async {
    final f = await _Fixture.create();
    await f.reserve(f.clientId, f.restaurantId, nb: 8);
    await f.reserve(f.clientId, f.otherRestoId, nb: 30);

    final ia = AiService(f.restaurantId, db: f.repo);
    expect(
        await ia.creneauComplet(
            date: '2099-01-02', heure: '20:00', nbPersonnes: 3),
        isTrue); // 8 + 3 > 10
    expect(
        await AiService(f.otherRestoId, db: f.repo).creneauComplet(
            date: '2099-01-02', heure: '20:00', nbPersonnes: 3),
        isFalse); // 30 + 3 <= 40
    final alternatives = await ia.proposerCreneauxAlternatifs(
        date: '2099-01-02', heure: '20:00', nbPersonnes: 3);
    expect(alternatives, isNotEmpty);
    expect(alternatives.first.ecartHeures, 1);
  });

  test('events: CRUD scoped to the restaurant, upcoming-only for clients',
      () async {
    final f = await _Fixture.create();
    Evenement e(int restaurant, String date) => Evenement(
          restaurantId: restaurant,
          titre: 'Soirée $date',
          type: Evenement.typeSoiree,
          date: date,
          description: '',
          placesTotal: 20,
          placesRestantes: 20,
        );
    await f.repo.insererEvenement(e(f.restaurantId, '2000-01-01'));
    final futur = await f.repo.insererEvenement(e(f.restaurantId, '2099-01-01'));
    await f.repo.insererEvenement(e(f.otherRestoId, '2099-01-01'));

    expect(await f.repo.evenements(f.restaurantId), hasLength(2));
    final aVenir =
        await f.repo.evenements(f.restaurantId, aVenirSeulement: true);
    expect(aVenir.single.id, futur);

    await f.repo.supprimerEvenement(futur);
    expect(await f.repo.evenements(f.restaurantId), hasLength(1));
  });

  test('deleting a client account deletes its reservations (FK cascade)',
      () async {
    final f = await _Fixture.create();
    await f.reserve(f.clientId, f.restaurantId);
    await f.db.delete('users', where: 'id = ?', whereArgs: [f.clientId]);
    expect(await f.db.query('reservation'), isEmpty);
  });

  test('restaurantIdForUser maps the restaurant account', () async {
    final f = await _Fixture.create();
    final owner = (await f.db.query('restaurant_profiles',
            where: 'id = ?', whereArgs: [f.restaurantId]))
        .single['user_id']! as int;
    expect(await restaurantIdForUser(f.db, owner), f.restaurantId);
  });

  test('demo seed: attaches to resto@test.com and the seed clients, once',
      () async {
    final f = await _Fixture.create();
    Future<int> user(String email) => f.db.insert('users', {
          'email': email, 'password_hash': 'h', 'salt': 's',
          'password_iterations': 1, 'user_type': 'client',
        });
    for (final e in ['client@test.com', 'karim@test.com', 'lucas@test.com']) {
      await user(e);
    }
    final owner = await f.db.insert('users', {
      'email': 'resto@test.com', 'password_hash': 'h', 'salt': 's',
      'password_iterations': 1, 'user_type': 'restaurant',
    });
    final rid = await f.db.insert(
        'restaurant_profiles', {'user_id': owner, 'name': 'Le Gourmet'});

    await EventsSeed.applyEventsDemo(f.db);
    final n = (await f.db.query('reservation',
            where: 'restaurant_id = ?', whereArgs: [rid]))
        .length;
    expect(n, 320 + 4 + 6); // history (90+90+30+30+80) + upcoming
    expect(await f.repo.evenements(rid), hasLength(3));
    expect((await f.repo.reservationsAvecClient(restaurantId: rid)),
        hasLength(n)); // every reservation has a real client

    await EventsSeed.applyEventsDemo(f.db); // idempotent
    expect(
        (await f.db.query('reservation',
                where: 'restaurant_id = ?', whereArgs: [rid]))
            .length,
        n);

    // The AI finds busy slots in the seeded history.
    final affluence = await AiService(rid, db: f.repo).predireAffluence();
    expect(affluence.where((c) => c.charge), isNotEmpty);
  });
}
