import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/client.dart';
import '../models/evenement.dart';
import '../models/reservation.dart';
import '../models/restaurant.dart';
import '../services/ai_service.dart';
import '../services/generateur_aleatoire.dart';
import '../utils/aide_dates.dart';

/// Gestionnaire unique de la base SQLite (patron "singleton") : toute
/// l'application passe par [DatabaseHelper.instance].
///
/// Toutes les requêtes utilisent des paramètres "?" pour éviter les
/// injections SQL.
class DatabaseHelper {
  DatabaseHelper._interne();
  static final DatabaseHelper instance = DatabaseHelper._interne();

  static const String _nomBase = 'resto_events.db';
  static const int _versionBase = 1;

  Database? _base;

  /// Ouvre la base au premier appel puis renvoie toujours la même instance.
  Future<Database> get database async {
    _base ??= await _ouvrirBase();
    return _base!;
  }

  Future<Database> _ouvrirBase() async {
    final chemin = join(await getDatabasesPath(), _nomBase);
    final base = await openDatabase(
      chemin,
      version: _versionBase,
      onCreate: (db, version) => _creerTables(db),
    );
    await _insererDonneesDemoSiNecessaire(base);
    return base;
  }

  // ---------------------------------------------------------------------------
  // SCHÉMA
  // ---------------------------------------------------------------------------

  Future<void> _creerTables(Database db) async {
    // Le restaurant : capaciteMax = personnes maximum PAR CRÉNEAU.
    await db.execute('''
      CREATE TABLE restaurant (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        capacite_max INTEGER NOT NULL DEFAULT 40
      )
    ''');

    await db.execute('''
      CREATE TABLE client (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE evenement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurant_id INTEGER NOT NULL,
        titre TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        places_total INTEGER NOT NULL,
        places_restantes INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reservation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        restaurant_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        heure TEXT NOT NULL,
        nb_personnes INTEGER NOT NULL,
        statut TEXT NOT NULL,
        nb_modifications INTEGER NOT NULL DEFAULT 0,
        score_no_show REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Petite table technique : mémorise si les données de démo ont déjà
    // été insérées (pour ne les créer qu'au tout premier lancement).
    await db.execute('''
      CREATE TABLE meta (
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // DONNÉES DE DÉMONSTRATION
  // ---------------------------------------------------------------------------

  Future<void> _insererDonneesDemoSiNecessaire(Database db) async {
    final marqueeV3 = await db.query(
      'meta',
      where: 'cle = ?',
      whereArgs: ['demo_remplie_v4'],
    );
    if (marqueeV3.isNotEmpty) return;

    // Migration : on régénère les données de démo à chaque version du seed
    // (v2 = générateur aléatoire corrigé, v3 = affluence des vendredi/samedi
    // assez dense pour dépasser le seuil d'alerte de l'onglet IA).
    await db.delete('reservation');
    await db.delete('evenement');
    await db.delete('restaurant');
    await db.delete('client');
    await db.delete('meta');

    await db.transaction((txn) async {
      final batch = txn.batch();

      // 1) Le restaurant de la démo : 40 personnes maximum par créneau.
      batch.insert('restaurant', {'id': 1, 'nom': 'Le Gourmet', 'capacite_max': 40});

      // 2) Huit profils clients, dont deux "récidivistes" du no-show
      //    (Camille et Mehdi) pour rendre le score de risque visible.
      const nomsClients = [
        'Camille', 'Sarah', 'Karim', 'Léa', 'Mehdi', 'Julie', 'Antoine', 'Nour',
      ];
      for (var i = 0; i < nomsClients.length; i++) {
        batch.insert('client', {'id': i + 1, 'nom': nomsClients[i]});
      }
      const recidivistes = {1, 5}; // identifiants de Camille et Mehdi

      final alea = GenerateurAleatoireSeedee(42);
      final aujourdhui = DateTime.now();

      // 3) 250 réservations fictives sur les 8 dernières semaines.
      //
      //    Pour que la prédiction d'affluence soit parlante, l'historique
      //    est concentré sur les créneaux qui remplissent vraiment le
      //    restaurant (vendredi/samedi soir, dimanche midi) : c'est ce qui
      //    fera dépasser le seuil d'alerte de 80 % de la capacité.
      Future<void> genererLot({
        required List<int> joursSemaine, // index strftime (5 = vendredi...)
        required List<int> heures,
        required int nombre,
        required int tailleMin,
        required int tailleMax,
      }) async {
        for (var i = 0; i < nombre; i++) {
          // On recule d'un nombre de semaines entier pour retomber sur le
          // bon jour de la semaine (0 à 7 semaines en arrière).
          final semainesRecul = alea.nextInt(8);
          final joursRecul = semainesRecul * 7;
          final jour = AideDates.versTexte(
            aujourdhui.subtract(Duration(days: joursRecul)),
          );
          // On cale la date sur le jour de semaine visé.
          final dateReservation = _calerSurJour(jour, joursSemaine);

          final heure = heures[alea.nextInt(heures.length)];
          final minutes = alea.nextBool() ? '00' : '30';
          final nbPersonnes = tailleMin + alea.nextInt(tailleMax - tailleMin + 1);
          final clientId = 1 + alea.nextInt(nomsClients.length);

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
            // Sécurité : jamais de date de création dans le futur.
            dateCreation = aujourdhui;
            joursAvance = 0;
          }

          batch.insert('reservation', {
            'client_id': clientId,
            'restaurant_id': 1,
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
            'created_at': DateTime(
              dateCreation.year,
              dateCreation.month,
              dateCreation.day,
              12,
            ).toIso8601String(),
          });
        }
      }

      // Créneaux chargés : vendredi et samedi soir, dimanche midi.
      //    Densité volontairement forte (≈ 5-6 groupes de 7-11 par soir et
      //    par heure) pour que la moyenne d'affluence dépasse le seuil
      //    d'alerte de 80 % de la capacité — sinon l'onglet IA ne montre
      //    jamais de créneau "très chargé".
      await genererLot(
          joursSemaine: [5], heures: [19, 20], nombre: 90, tailleMin: 7, tailleMax: 11);
      await genererLot(
          joursSemaine: [6], heures: [19, 20], nombre: 90, tailleMin: 7, tailleMax: 11);
      await genererLot(
          joursSemaine: [6], heures: [21], nombre: 30, tailleMin: 5, tailleMax: 10);
      await genererLot(
          joursSemaine: [0], heures: [12, 13], nombre: 30, tailleMin: 3, tailleMax: 7);
      // Le reste de la semaine : affluence normale.
      await genererLot(
          joursSemaine: [1, 2, 3, 4],
          heures: [12, 13, 14, 18, 19, 20, 21, 22],
          nombre: 80,
          tailleMin: 1,
          tailleMax: 6);

      // 4) Quelques réservations À VENIR pour animer la démo :
      //    des demandes en attente à traiter côté restaurant, et un
      //    samedi soir déjà presque complet pour tester les créneaux
      //    alternatifs proposés par l'IA.
      final samediProchain = _prochainJour(aujourdhui, 6); // 6 = samedi
      final groupesSamedi = [9, 10, 10, 8]; // 37 personnes acceptées à 20h
      for (final nb in groupesSamedi) {
        batch.insert('reservation', {
          'client_id': 1 + alea.nextInt(nomsClients.length),
          'restaurant_id': 1,
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
      // Six demandes en attente réparties sur les jours qui viennent.
      for (var i = 0; i < 6; i++) {
        final dateFuture = AideDates.versTexte(
          aujourdhui.add(Duration(days: 1 + i % 4)),
        );
        final heuresFutures = ['19:00', '20:00', '12:30', '21:00', '13:00', '20:30'];
        final nbPersonnes = 2 + alea.nextInt(5);
        final clientId = 1 + alea.nextInt(nomsClients.length);
        batch.insert('reservation', {
          'client_id': clientId,
          'restaurant_id': 1,
          'date': dateFuture,
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

      // 5) Trois événements d'exemple pour le CRUD côté restaurant.
      batch.insert('evenement', {
        'restaurant_id': 1,
        'titre': 'Anniversaire surprise',
        'type': Evenement.typeAnniversaire,
        'date': AideDates.versTexte(aujourdhui.add(const Duration(days: 5))),
        'description':
            'Grande table réservée pour fêter les 30 ans de Lina. Gâteau prévu en dessert.',
        'places_total': 25,
        'places_restantes': 18,
      });
      batch.insert('evenement', {
        'restaurant_id': 1,
        'titre': 'Soirée karaoké',
        'type': Evenement.typeSoiree,
        'date': AideDates.versTexte(aujourdhui.add(const Duration(days: 9))),
        'description':
            'Karaoké ouvert à tous les clients à partir de 21h, inscription sur place.',
        'places_total': 40,
        'places_restantes': 31,
      });
      batch.insert('evenement', {
        'restaurant_id': 1,
        'titre': 'Concert jazz live',
        'type': Evenement.typeMusiqueLive,
        'date': AideDates.versTexte(aujourdhui.add(const Duration(days: 14))),
        'description':
            'Un trio de jazz accompagne le dîner à partir de 20h. Ambiance feutrée garantie.',
        'places_total': 35,
        'places_restantes': 20,
      });

      // On marque la base comme "remplie" pour ne pas rejouer ce seed.
      batch.insert('meta', {'cle': 'demo_remplie_v4', 'valeur': '1'});
      await batch.commit(noResult: true);
    });
  }

  /// Décale la date "AAAA-MM-JJ" sur le jour de semaine visé
  /// ([cibles] = liste d'index au format `strftime('%w')`).
  String _calerSurJour(String jour, List<int> cibles) {
    final indexActuel = AideDates.indexJourStrftime(jour);
    if (cibles.contains(indexActuel)) return jour;
    var date = DateTime.parse(jour);
    while (!cibles.contains(date.weekday % 7)) {
      date = date.subtract(const Duration(days: 1));
    }
    return AideDates.versTexte(date);
  }

  /// Prochaine occurrence du jour de semaine [cible] (aujourd'hui inclus).
  DateTime _prochainJour(DateTime depuis, int cible) {
    var date = DateTime(depuis.year, depuis.month, depuis.day);
    while (date.weekday % 7 != cible) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  // ---------------------------------------------------------------------------
  // CRUD : RÉSERVATIONS
  // ---------------------------------------------------------------------------

  Future<int> insererReservation(Reservation r) async {
    final db = await database;
    return db.insert('reservation', r.toMap());
  }

  Future<int> modifierReservation(Reservation r) async {
    final db = await database;
    return db.update(
      'reservation',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  /// Toutes les réservations d'un client, de la plus récente à la plus ancienne.
  Future<List<Reservation>> reservationsDuClient(int clientId) async {
    final db = await database;
    final lignes = await db.query(
      'reservation',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'date DESC, heure DESC',
    );
    return lignes.map(Reservation.fromMap).toList();
  }

  /// Réservations avec le nom du client (jointure pour l'écran restaurant).
  Future<List<Map<String, Object?>>> reservationsAvecClient({
    String? statut,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT r.*, c.nom AS nom_client
      FROM reservation r
      JOIN client c ON c.id = r.client_id
      ${statut != null ? 'WHERE r.statut = ?' : ''}
      ORDER BY r.date ASC, r.heure ASC
    ''', statut != null ? [statut] : null);
  }

  /// Accepter / refuser / annuler / marquer honorée ou no-show.
  Future<int> changerStatutReservation(int id, String statut) async {
    final db = await database;
    return db.update(
      'reservation',
      {'statut': statut},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Nombre de no-shows passés d'un client (facteur principal du score IA).
  Future<int> compterNoShows(int clientId) async {
    final db = await database;
    final resultat = await db.rawQuery('''
      SELECT COUNT(*) AS nb FROM reservation
      WHERE client_id = ? AND statut = ?
    ''', [clientId, Reservation.statutNoShow]);
    return (resultat.first['nb'] as int?) ?? 0;
  }

  /// Somme des personnes des réservations ACCEPTÉES pour un créneau
  /// (date + heure). C'est cette somme qui sert à savoir si un créneau
  /// est complet ou non.
  Future<int> sommePersonnesAcceptees(String date, String heure) async {
    final db = await database;
    final resultat = await db.rawQuery('''
      SELECT COALESCE(SUM(nb_personnes), 0) AS total
      FROM reservation
      WHERE date = ? AND heure = ? AND statut = ?
    ''', [date, heure, Reservation.statutAcceptee]);
    return (resultat.first['total'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // IA : REQUÊTE D'AFFLUENCE (utilisée par ai_service.dart)
  // ---------------------------------------------------------------------------

  /// Moyenne de personnes présentes par créneau récurrent.
  ///
  /// L'idée : on regroupe d'abord par date + heure (pour additionner les
  /// groupes qui dînent ensemble le même soir), puis on moyenne chaque
  /// combinaison jour de la semaine + heure sur les 8 dernières semaines.
  /// `strftime('%w', date)` renvoie le jour de la semaine (0 = dimanche).
  Future<List<Map<String, Object?>>> affluenceParCreneau() async {
    final db = await database;
    return db.rawQuery('''
      SELECT jour, heure, AVG(total_personnes) AS moyenne
      FROM (
        SELECT strftime('%w', date) AS jour,
               substr(heure, 1, 2) AS heure,
               date AS jour_exact,
               SUM(nb_personnes) AS total_personnes
        FROM reservation
        WHERE statut IN (?, ?, ?)
        GROUP BY date, substr(heure, 1, 2)
      )
      GROUP BY jour, heure
    ''', [
      Reservation.statutAcceptee,
      Reservation.statutHonoree,
      Reservation.statutNoShow,
    ]);
  }

  // ---------------------------------------------------------------------------
  // CRUD : ÉVÉNEMENTS
  // ---------------------------------------------------------------------------

  Future<int> insererEvenement(Evenement e) async {
    final db = await database;
    return db.insert('evenement', e.toMap());
  }

  Future<int> modifierEvenement(Evenement e) async {
    final db = await database;
    return db.update(
      'evenement',
      e.toMap(),
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<int> supprimerEvenement(int id) async {
    final db = await database;
    return db.delete('evenement', where: 'id = ?', whereArgs: [id]);
  }

  /// Événements triés par date croissante (les prochains d'abord).
  Future<List<Evenement>> evenements() async {
    final db = await database;
    final lignes = await db.query('evenement', orderBy: 'date ASC');
    return lignes.map(Evenement.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // CLIENTS ET RESTAURANT
  // ---------------------------------------------------------------------------

  /// Liste des clients avec leur nombre de no-shows passés
  /// (sous-requête SQL : un seul aller-retour à la base).
  Future<List<Map<String, Object?>>> clientsAvecNoShows() async {
    final db = await database;
    return db.rawQuery('''
      SELECT c.*, (
        SELECT COUNT(*) FROM reservation r
        WHERE r.client_id = c.id AND r.statut = ?
      ) AS nb_no_shows
      FROM client c
      ORDER BY c.nom ASC
    ''', [Reservation.statutNoShow]);
  }

  Future<List<Client>> clients() async {
    final db = await database;
    final lignes = await db.query('client', orderBy: 'nom ASC');
    return lignes.map(Client.fromMap).toList();
  }

  /// Le restaurant principal de la démo (id = 1).
  Future<Restaurant> restaurantPrincipal() async {
    final db = await database;
    final lignes = await db.query('restaurant', limit: 1);
    if (lignes.isEmpty) {
      throw StateError('Aucun restaurant dans la base de données.');
    }
    return Restaurant.fromMap(lignes.first);
  }
}
