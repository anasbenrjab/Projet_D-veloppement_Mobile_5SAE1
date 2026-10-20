/// DDL for shared tables that cross module boundaries.
///
/// These tables are owned by the menu/orders module but are defined here
/// so that foreign-key constraints in user_module_tables.dart (favorite_dishes)
/// and the recommendations feature work correctly.
///
/// The team rule: the module that owns the *business logic* for a table
/// provides its repository.  This file only defines the schema.
///
/// To be confirmed with the team before the schema is frozen.
library;

import 'package:sqflite/sqflite.dart';

class SharedTables {
  SharedTables._();

  static Future<void> create(DatabaseExecutor db) async {
    // ── dishes ─────────────────────────────────────────────────────────────
    // Owned by the menu/orders module.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dishes (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurant_id INTEGER NOT NULL,
        name          TEXT    NOT NULL,
        description   TEXT    NULL,
        price         REAL    NOT NULL DEFAULT 0.0,
        photo_path    TEXT    NULL,
        is_available  INTEGER NOT NULL DEFAULT 1,
        tags          TEXT    NULL,
        created_at    TEXT    NOT NULL
                        DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        updated_at    TEXT    NOT NULL
                        DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dishes_restaurant_id
        ON dishes(restaurant_id)
    ''');

    // ── order_history ──────────────────────────────────────────────────────
    // Owned by the menu/orders module.
    // Used read-only by the recommendations feature (Module Utilisateur).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_history (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER NOT NULL,
        restaurant_id INTEGER NOT NULL,
        dish_id       INTEGER NULL,
        ordered_at    TEXT    NOT NULL
                        DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        FOREIGN KEY (user_id)
          REFERENCES users(id)               ON DELETE CASCADE,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE,
        FOREIGN KEY (dish_id)
          REFERENCES dishes(id)              ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_oh_user_id
        ON order_history(user_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_oh_restaurant_id
        ON order_history(restaurant_id)
    ''');
  }
}
