/// DDL for Module Utilisateur.
///
/// Called once from [DatabaseHelper._onCreate].
/// To add a column or table to this module, add an idempotent helper here
/// (see [UserModuleTables.createProfilePhotos]), call it from [create], bump
/// [DatabaseHelper._dbVersion], and call it from a guarded block in
/// [DatabaseHelper._onUpgrade].  Do NOT edit a table definition that has
/// already shipped.
library;

import 'package:sqflite/sqflite.dart';

class UserModuleTables {
  UserModuleTables._();

  static Future<void> create(DatabaseExecutor db) async {
    // ── users ──────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        email               TEXT    NOT NULL UNIQUE,
        password_hash       TEXT    NOT NULL,
        salt                TEXT    NOT NULL,
        password_iterations INTEGER NOT NULL,
        user_type           TEXT    NOT NULL DEFAULT 'client'
                              CHECK(user_type IN ('client','restaurant')),
        is_active           INTEGER NOT NULL DEFAULT 1
                              CHECK(is_active IN (0,1)),
        reset_question      TEXT    NULL,
        reset_answer_hash   TEXT    NULL,
        reset_answer_salt   TEXT    NULL,
        created_at          TEXT    NOT NULL
                              DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        updated_at          TEXT    NOT NULL
                              DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
      )
    ''');

    // ── client_profiles ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS client_profiles (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id             INTEGER NOT NULL UNIQUE,
        full_name           TEXT    NULL,
        phone               TEXT    NULL,
        photo_path          TEXT    NULL,
        dietary_preferences TEXT    NULL,
        allergies           TEXT    NULL,
        created_at          TEXT    NOT NULL
                              DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        updated_at          TEXT    NOT NULL
                              DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // ── restaurant_profiles ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_profiles (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER NOT NULL UNIQUE,
        name          TEXT    NOT NULL
                        CHECK(length(trim(name)) > 0),
        address       TEXT    NULL,
        latitude      REAL    NULL,
        longitude     REAL    NULL,
        opening_hours TEXT    NULL,
        cuisine_type  TEXT    NULL,
        photo_paths   TEXT    NULL,
        description   TEXT    NULL,
        created_at    TEXT    NOT NULL
                        DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        updated_at    TEXT    NOT NULL
                        DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // ── favorite_restaurants ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_restaurants (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER NOT NULL,
        restaurant_id INTEGER NOT NULL,
        created_at    TEXT    NOT NULL
                        DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        UNIQUE(user_id, restaurant_id),
        FOREIGN KEY (user_id)
          REFERENCES users(id)               ON DELETE CASCADE,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');

    // ── favorite_dishes ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_dishes (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        dish_id    INTEGER NOT NULL,
        created_at TEXT    NOT NULL
                     DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        UNIQUE(user_id, dish_id),
        FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE,
        FOREIGN KEY (dish_id)  REFERENCES dishes(id)  ON DELETE CASCADE
      )
    ''');

    await createProfilePhotos(db);
  }

  /// v2: `profile_photos` — photo bytes stored in the database (the web build
  /// has no file system).
  ///
  /// Called from [create] for new databases and from
  /// `DatabaseHelper._onUpgrade` for databases created at v1.  Idempotent
  /// (`IF NOT EXISTS`), so it is safe on both paths.
  static Future<void> createProfilePhotos(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profile_photos (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        user_type  TEXT    NOT NULL CHECK(user_type IN ('client','restaurant')),
        position   INTEGER NOT NULL DEFAULT 0,
        mime_type  TEXT    NOT NULL DEFAULT 'image/jpeg',
        data       BLOB    NOT NULL,
        created_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_profile_photos_owner
        ON profile_photos(user_id, user_type, position)
    ''');
  }
}
