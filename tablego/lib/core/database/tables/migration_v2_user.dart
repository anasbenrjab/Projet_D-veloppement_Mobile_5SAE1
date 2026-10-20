/// Schema migration v2 — user module.
///
/// Adds the `profile_photos` table.  On web there is no file system to copy a
/// picked image into, so photo bytes are stored here as BLOBs.  Mobile keeps
/// the existing file-path approach (`client_profiles.photo_path` /
/// `restaurant_profiles.photo_paths`) and leaves this table empty.  The UI
/// renders whichever of the two is present.
///
/// [up] is idempotent (every statement uses `IF NOT EXISTS`) and is called
/// from both [UserModuleTables.create] (fresh installs, including web) and
/// [DatabaseHelper._onUpgrade] (existing v1 databases).
library;

import 'package:sqflite/sqflite.dart';

class MigrationV2User {
  MigrationV2User._();

  static Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profile_photos (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        user_type  TEXT    NOT NULL
                     CHECK(user_type IN ('client','restaurant')),
        position   INTEGER NOT NULL DEFAULT 0,
        mime_type  TEXT    NOT NULL DEFAULT 'image/jpeg',
        data       BLOB    NOT NULL,
        created_at TEXT    NOT NULL
                     DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_profile_photos_owner
        ON profile_photos(user_id, user_type, position)
    ''');
  }
}
