import 'package:sqflite/sqflite.dart';

import '../../../core/data/validation_exception.dart';
import '../../../core/database/database_helper.dart';
import '../models/evenement.dart';
import '../models/reservation.dart';
import '../models/restaurant.dart';

/// Accès aux données du Module 3 (événements + réservations).
///
/// Integration: this was Module 3's own `DatabaseHelper` (its own
/// `resto_events.db`).  It now uses TableGo's shared database
/// ([DatabaseHelper]); the schema lives in
/// `core/database/tables/events_tables.dart` and the demo data in
/// `core/database/seeds/events_seed.dart`.  Method names and SQL are
/// Module 3's; what changed:
///
/// * the restaurant is no longer "the" restaurant (id 1): every
///   restaurant-side query takes the `restaurant_profiles.id` of the
///   logged-in restaurant;
/// * `client` rows are TableGo users: the client's name comes from
///   `client_profiles.full_name` (or the email).
///
/// Toutes les requêtes utilisent des paramètres "?" pour éviter les
/// injections SQL.
class EvenementsRepository {
  EvenementsRepository([DatabaseHelper? db])
      : _helper = db ?? DatabaseHelper.instance;

  static final EvenementsRepository instance = EvenementsRepository();

  final DatabaseHelper _helper;

  Future<Database> get database => _helper.database;

  // ---------------------------------------------------------------------------
  // CRUD : RÉSERVATIONS
  // ---------------------------------------------------------------------------

  // ── Règles de sécurité (intégration) ─────────────────────────────────────

  static void _verifierStatut(String statut) {
    if (!Reservation.statuts.contains(statut)) {
      throw ValidationException('Statut de réservation invalide : « $statut ».');
    }
  }

  /// 0 <= places restantes <= places totales.
  static void _verifierPlaces(Evenement e) {
    if (e.placesRestantes < 0 || e.placesRestantes > e.placesTotal) {
      throw const ValidationException(
          'Places restantes invalides : elles doivent être entre 0 et le '
          'nombre total de places.');
    }
  }

  Future<int> insererReservation(Reservation r) async {
    _verifierStatut(r.statut);
    final db = await database;
    return db.insert('reservation', r.toMap());
  }

  Future<int> modifierReservation(Reservation r) async {
    _verifierStatut(r.statut);
    final db = await database;
    return db.update(
      'reservation',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  /// Toutes les réservations d'un client (tous restaurants), de la plus
  /// récente à la plus ancienne, avec le nom du restaurant.
  Future<List<Reservation>> reservationsDuClient(int clientId,
      {int? restaurantId}) async {
    final db = await database;
    final lignes = await db.rawQuery('''
      SELECT r.*, rp.name AS nom_restaurant
      FROM reservation r
      JOIN restaurant_profiles rp ON rp.id = r.restaurant_id
      WHERE r.client_id = ?
      ${restaurantId != null ? 'AND r.restaurant_id = ?' : ''}
      ORDER BY r.date DESC, r.heure DESC
    ''', [clientId, ?restaurantId]);
    return lignes.map(Reservation.fromMap).toList();
  }

  /// Réservations d'un restaurant avec le nom du client (jointure pour
  /// l'écran restaurant).
  Future<List<Map<String, Object?>>> reservationsAvecClient({
    required int restaurantId,
    String? statut,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT r.*,
             COALESCE(NULLIF(TRIM(cp.full_name), ''), u.email) AS nom_client
      FROM reservation r
      JOIN users u ON u.id = r.client_id
      LEFT JOIN client_profiles cp ON cp.user_id = u.id
      WHERE r.restaurant_id = ?
      ${statut != null ? 'AND r.statut = ?' : ''}
      ORDER BY r.date ASC, r.heure ASC
    ''', [restaurantId, ?statut]);
  }

  /// Accepter / refuser / annuler / marquer honorée ou no-show.
  Future<int> changerStatutReservation(int id, String statut) async {
    _verifierStatut(statut);
    final db = await database;
    return db.update(
      'reservation',
      {'statut': statut},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Nombre de no-shows passés d'un client, tous restaurants confondus
  /// (facteur principal du score IA).
  Future<int> compterNoShows(int clientId) async {
    final db = await database;
    final resultat = await db.rawQuery('''
      SELECT COUNT(*) AS nb FROM reservation
      WHERE client_id = ? AND statut = ?
    ''', [clientId, Reservation.statutNoShow]);
    return (resultat.first['nb'] as int?) ?? 0;
  }

  /// Somme des personnes des réservations ACCEPTÉES pour un créneau
  /// (date + heure) du restaurant. C'est cette somme qui sert à savoir si
  /// un créneau est complet ou non.
  Future<int> sommePersonnesAcceptees(
      int restaurantId, String date, String heure) async {
    final db = await database;
    final resultat = await db.rawQuery('''
      SELECT COALESCE(SUM(nb_personnes), 0) AS total
      FROM reservation
      WHERE restaurant_id = ? AND date = ? AND heure = ? AND statut = ?
    ''', [restaurantId, date, heure, Reservation.statutAcceptee]);
    return (resultat.first['total'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // IA : REQUÊTE D'AFFLUENCE (utilisée par ai_service.dart)
  // ---------------------------------------------------------------------------

  /// Moyenne de personnes présentes par créneau récurrent du restaurant.
  ///
  /// L'idée : on regroupe d'abord par date + heure (pour additionner les
  /// groupes qui dînent ensemble le même soir), puis on moyenne chaque
  /// combinaison jour de la semaine + heure sur les 8 dernières semaines.
  /// `strftime('%w', date)` renvoie le jour de la semaine (0 = dimanche).
  Future<List<Map<String, Object?>>> affluenceParCreneau(
      int restaurantId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT jour, heure, AVG(total_personnes) AS moyenne
      FROM (
        SELECT strftime('%w', date) AS jour,
               substr(heure, 1, 2) AS heure,
               date AS jour_exact,
               SUM(nb_personnes) AS total_personnes
        FROM reservation
        WHERE restaurant_id = ? AND statut IN (?, ?, ?)
        GROUP BY date, substr(heure, 1, 2)
      )
      GROUP BY jour, heure
    ''', [
      restaurantId,
      Reservation.statutAcceptee,
      Reservation.statutHonoree,
      Reservation.statutNoShow,
    ]);
  }

  // ---------------------------------------------------------------------------
  // CRUD : ÉVÉNEMENTS
  // ---------------------------------------------------------------------------

  Future<int> insererEvenement(Evenement e) async {
    _verifierPlaces(e);
    final db = await database;
    return db.insert('evenement', e.toMap());
  }

  Future<int> modifierEvenement(Evenement e) async {
    _verifierPlaces(e);
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

  /// Événements du restaurant triés par date croissante (les prochains
  /// d'abord).  [aVenirSeulement] : à partir d'aujourd'hui (vue client).
  Future<List<Evenement>> evenements(int restaurantId,
      {bool aVenirSeulement = false}) async {
    final db = await database;
    final lignes = await db.query(
      'evenement',
      where: aVenirSeulement
          ? 'restaurant_id = ? AND date >= ?'
          : 'restaurant_id = ?',
      whereArgs: [
        restaurantId,
        if (aVenirSeulement) _dateDuJour(),
      ],
      orderBy: 'date ASC',
    );
    return lignes.map(Evenement.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // RESTAURANT
  // ---------------------------------------------------------------------------

  /// Le restaurant [restaurantId] (nom + capacité par créneau).
  Future<Restaurant> restaurant(int restaurantId) async {
    final db = await database;
    final lignes = await db.query(
      'restaurant_profiles',
      columns: ['id', 'name AS nom', 'seat_capacity AS capacite_max'],
      where: 'id = ?',
      whereArgs: [restaurantId],
      limit: 1,
    );
    if (lignes.isEmpty) {
      throw StateError('Aucun restaurant dans la base de données.');
    }
    return Restaurant.fromMap(lignes.first);
  }

  static String _dateDuJour() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final j = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$j';
  }
}
