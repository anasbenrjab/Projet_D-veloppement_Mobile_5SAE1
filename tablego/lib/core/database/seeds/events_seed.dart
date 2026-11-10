/// Module 3 (Événements + Réservations) demo data — debug builds only.
///
/// Module 3's own demo generator, moved out of its former DatabaseHelper and
/// attached to TableGo's seed accounts:
///
/// * restaurant: `resto@test.com` (Module 3's "Le Gourmet", capacity 40);
/// * clients: the seeded client accounts (Module 3's fake `client` rows
///   Camille, Sarah… are replaced by real users); `karim@test.com` and
///   `lucas@test.com` play the two no-show "récidivistes".
///
/// The generation itself (seeded random generator, 250 past reservations
/// concentrated on busy slots, upcoming requests, a nearly full Saturday,
/// three events) is unchanged (its comment said 250 past reservations; the
/// lots actually add up to 320).  It runs once: it does nothing when the
/// restaurant already has reservations (Module 3 used a `meta` table and
/// wiped its tables on every seed version; neither is acceptable in the
/// shared database).  It opens no transaction, so it is safe in `onCreate`.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../features/events/models/evenement.dart';
import '../../../features/events/models/reservation.dart';
import '../../../features/events/services/ai_service.dart';
import '../../../features/events/services/generateur_aleatoire.dart';
import '../../../features/events/utils/aide_dates.dart';

const _restaurantEmail = 'resto@test.com';
const _clientEmails = [
  'client@test.com',
  'karim@test.com',
  'sophie@test.com',
  'yuki@test.com',
  'lucas@test.com',
];
const _recidivistEmails = {'karim@test.com', 'lucas@test.com'};

class EventsSeed {
  EventsSeed._();

  static Future<void> applyEventsDemo(DatabaseExecutor db) async {
    if (!kDebugMode) return;

    final resto = await db.rawQuery('''
      SELECT rp.id FROM restaurant_profiles rp
        JOIN users u ON u.id = rp.user_id
       WHERE u.email = ?
    ''', [_restaurantEmail]);
    if (resto.isEmpty) return;
    final restaurantId = resto.first['id']! as int;

    final already = await db.query('reservation',
        columns: ['id'],
        where: 'restaurant_id = ?',
        whereArgs: [restaurantId],
        limit: 1);
    if (already.isNotEmpty) return;

    final clientRows = await db.query('users',
        columns: ['id', 'email'],
        where: 'email IN (${List.filled(_clientEmails.length, '?').join(',')})',
        whereArgs: _clientEmails,
        orderBy: 'id');
    if (clientRows.isEmpty) return;
    final clientIds = [for (final r in clientRows) r['id']! as int];
    final recidivistes = {
      for (final r in clientRows)
        if (_recidivistEmails.contains(r['email'])) r['id']! as int,
    };

    final batch = db.batch();
    final alea = GenerateurAleatoireSeedee(42);
    final aujourdhui = DateTime.now();
    int clientAuHasard() => clientIds[alea.nextInt(clientIds.length)];

    // 320 réservations fictives sur les 8 dernières semaines, concentrées
    // sur les créneaux qui remplissent le restaurant.
    void genererLot({
      required List<int> joursSemaine, // index strftime (5 = vendredi...)
      required List<int> heures,
      required int nombre,
      required int tailleMin,
      required int tailleMax,
    }) {
      for (var i = 0; i < nombre; i++) {
        final semainesRecul = alea.nextInt(8);
        final jour = AideDates.versTexte(
          aujourdhui.subtract(Duration(days: semainesRecul * 7)),
        );
        final dateReservation = _calerSurJour(jour, joursSemaine);

        final heure = heures[alea.nextInt(heures.length)];
        final minutes = alea.nextBool() ? '00' : '30';
        final nbPersonnes =
            tailleMin + alea.nextInt(tailleMax - tailleMin + 1);
        final clientId = clientAuHasard();

        // Tirage du statut : environ 10 % de no-show au total.
        final tirage = alea.nextInt(100);
        String statut;
        if (tirage < 10) {
          statut = Reservation.statutNoShow;
        } else if (tirage < 22) {
          statut = Reservation.statutRefusee;
        } else if (tirage < 30) {
          statut = Reservation.statutAnnulee;
        } else if (tirage < 35) {
          statut = Reservation.statutEnAttente;
        } else if (tirage < 50) {
          statut = Reservation.statutAcceptee;
        } else {
          statut = Reservation.statutHonoree;
        }
        // Les récidivistes manquent beaucoup plus souvent leurs résas.
        if (recidivistes.contains(clientId) &&
            statut != Reservation.statutRefusee &&
            statut != Reservation.statutAnnulee &&
            alea.nextInt(100) < 35) {
          statut = Reservation.statutNoShow;
        }

        // La réservation a été prise entre 0 et 10 jours à l'avance.
        var joursAvance = alea.nextInt(11);
        var dateCreation = DateTime.parse(dateReservation)
            .subtract(Duration(days: joursAvance));
        if (dateCreation.isAfter(aujourdhui)) {
          dateCreation = aujourdhui;
          joursAvance = 0;
        }

        batch.insert('reservation', {
          'client_id': clientId,
          'restaurant_id': restaurantId,
          'date': dateReservation,
          'heure': '${heure.toString().padLeft(2, '0')}:$minutes',
          'nb_personnes': nbPersonnes,
          'statut': statut,
          'nb_modifications': alea.nextInt(100) < 10 ? 1 : 0,
          'score_no_show': AiService.formuleScoreNoShow(
            aDejaNoShow: recidivistes.contains(clientId),
            joursDavance: joursAvance,
            nbPersonnes: nbPersonnes,
            nbModifications: 0,
          ),
          'created_at': DateTime(dateCreation.year, dateCreation.month,
                  dateCreation.day, 12)
              .toIso8601String(),
        });
      }
    }

    // Créneaux chargés : vendredi et samedi soir, dimanche midi.
    genererLot(
        joursSemaine: [5], heures: [19, 20], nombre: 90, tailleMin: 7, tailleMax: 11);
    genererLot(
        joursSemaine: [6], heures: [19, 20], nombre: 90, tailleMin: 7, tailleMax: 11);
    genererLot(
        joursSemaine: [6], heures: [21], nombre: 30, tailleMin: 5, tailleMax: 10);
    genererLot(
        joursSemaine: [0], heures: [12, 13], nombre: 30, tailleMin: 3, tailleMax: 7);
    // Le reste de la semaine : affluence normale.
    genererLot(
        joursSemaine: [1, 2, 3, 4],
        heures: [12, 13, 14, 18, 19, 20, 21, 22],
        nombre: 80,
        tailleMin: 1,
        tailleMax: 6);

    // Réservations À VENIR : un samedi soir presque complet (37/40 à 20h)
    // pour tester les créneaux alternatifs proposés par l'IA…
    final samediProchain = _prochainJour(aujourdhui, 6); // 6 = samedi
    for (final nb in const [9, 10, 10, 8]) {
      batch.insert('reservation', {
        'client_id': clientAuHasard(),
        'restaurant_id': restaurantId,
        'date': AideDates.versTexte(samediProchain),
        'heure': '20:00',
        'nb_personnes': nb,
        'statut': Reservation.statutAcceptee,
        'nb_modifications': 0,
        'score_no_show': AiService.formuleScoreNoShow(
          aDejaNoShow: false,
          joursDavance: 7,
          nbPersonnes: nb,
          nbModifications: 0,
        ),
        'created_at': AideDates.maintenantIso(),
      });
    }
    // … et six demandes en attente à traiter côté restaurant.
    const heuresFutures = ['19:00', '20:00', '12:30', '21:00', '13:00', '20:30'];
    for (var i = 0; i < 6; i++) {
      final nbPersonnes = 2 + alea.nextInt(5);
      final clientId = clientAuHasard();
      batch.insert('reservation', {
        'client_id': clientId,
        'restaurant_id': restaurantId,
        'date': AideDates.versTexte(aujourdhui.add(Duration(days: 1 + i % 4))),
        'heure': heuresFutures[i],
        'nb_personnes': nbPersonnes,
        'statut': Reservation.statutEnAttente,
        'nb_modifications': 0,
        'score_no_show': AiService.formuleScoreNoShow(
          aDejaNoShow: recidivistes.contains(clientId),
          joursDavance: 1 + i % 4,
          nbPersonnes: nbPersonnes,
          nbModifications: 0,
        ),
        'created_at': AideDates.maintenantIso(),
      });
    }

    // Trois événements d'exemple pour le CRUD côté restaurant.
    for (final (titre, type, jours, description, total, restantes) in [
      ('Anniversaire surprise', Evenement.typeAnniversaire, 5,
          'Grande table réservée pour fêter les 30 ans de Lina. Gâteau prévu en dessert.',
          25, 18),
      ('Soirée karaoké', Evenement.typeSoiree, 9,
          'Karaoké ouvert à tous les clients à partir de 21h, inscription sur place.',
          40, 31),
      ('Concert jazz live', Evenement.typeMusiqueLive, 14,
          'Un trio de jazz accompagne le dîner à partir de 20h. Ambiance feutrée garantie.',
          35, 20),
    ]) {
      batch.insert('evenement', {
        'restaurant_id': restaurantId,
        'titre': titre,
        'type': type,
        'date': AideDates.versTexte(aujourdhui.add(Duration(days: jours))),
        'description': description,
        'places_total': total,
        'places_restantes': restantes,
      });
    }

    await batch.commit(noResult: true);
    debugPrint('[EventsSeed] Module 3 demo: reservations and events added');
  }

  /// Décale la date "AAAA-MM-JJ" sur le jour de semaine visé
  /// ([cibles] = liste d'index au format `strftime('%w')`).
  static String _calerSurJour(String jour, List<int> cibles) {
    if (cibles.contains(AideDates.indexJourStrftime(jour))) return jour;
    var date = DateTime.parse(jour);
    while (!cibles.contains(date.weekday % 7)) {
      date = date.subtract(const Duration(days: 1));
    }
    return AideDates.versTexte(date);
  }

  /// Prochaine occurrence du jour de semaine [cible] (aujourd'hui inclus).
  static DateTime _prochainJour(DateTime depuis, int cible) {
    var date = DateTime(depuis.year, depuis.month, depuis.day);
    while (date.weekday % 7 != cible) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}
