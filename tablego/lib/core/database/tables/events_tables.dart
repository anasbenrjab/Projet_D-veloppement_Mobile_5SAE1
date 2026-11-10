/// DDL for Module 3 (Événements + Réservations).
///
/// Module 3's standalone app had its own `restaurant` and `client` tables;
/// in TableGo they are the shared `restaurant_profiles` and `users` tables:
///
/// * `evenement.restaurant_id`   → `restaurant_profiles.id`
/// * `reservation.restaurant_id` → `restaurant_profiles.id`
/// * `reservation.client_id`     → `users.id` (the logged-in client)
/// * the restaurant's capacity per time slot (`restaurant.capacite_max`) is
///   `restaurant_profiles.seat_capacity` (default 40, as in Module 3).
///
/// Table and column names of `evenement` / `reservation` are Module 3's.
/// Every step is idempotent: [create] runs from `onCreate` (new databases)
/// and from the v5 block of `DatabaseHelper.migrate` (existing databases).
library;

import 'package:sqflite/sqflite.dart';

class EventsTables {
  EventsTables._();

  static Future<void> create(DatabaseExecutor db) async {
    await addSeatCapacity(db);
    await createEventsAndReservations(db);
  }

  /// `restaurant_profiles.seat_capacity`: maximum number of guests per time
  /// slot (date + hour), used by the reservation AI.
  static Future<void> addSeatCapacity(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(restaurant_profiles)');
    if (!columns.any((c) => c['name'] == 'seat_capacity')) {
      await db.execute('ALTER TABLE restaurant_profiles '
          'ADD COLUMN seat_capacity INTEGER NOT NULL DEFAULT 40');
    }
  }

  static Future<void> createEventsAndReservations(DatabaseExecutor db) async {
    // ── evenement ──────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS evenement (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurant_id    INTEGER NOT NULL,
        titre            TEXT    NOT NULL,
        type             TEXT    NOT NULL,
        date             TEXT    NOT NULL,
        description      TEXT    NOT NULL DEFAULT '',
        places_total     INTEGER NOT NULL,
        places_restantes INTEGER NOT NULL,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_evenement_restaurant '
        'ON evenement(restaurant_id, date)');

    // ── reservation ────────────────────────────────────────────────────────
    // date "AAAA-MM-JJ", heure "HH:MM" (Module 3's text formats).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reservation (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id        INTEGER NOT NULL,
        restaurant_id    INTEGER NOT NULL,
        date             TEXT    NOT NULL,
        heure            TEXT    NOT NULL,
        nb_personnes     INTEGER NOT NULL CHECK(nb_personnes > 0),
        statut           TEXT    NOT NULL,
        nb_modifications INTEGER NOT NULL DEFAULT 0,
        score_no_show    REAL    NOT NULL DEFAULT 0,
        created_at       TEXT    NOT NULL,
        FOREIGN KEY (client_id)
          REFERENCES users(id)               ON DELETE CASCADE,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reservation_client '
        'ON reservation(client_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reservation_slot '
        'ON reservation(restaurant_id, date, heure)');
  }
}
