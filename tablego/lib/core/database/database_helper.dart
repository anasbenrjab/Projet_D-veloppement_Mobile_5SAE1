import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'seeds/dev_seed.dart';
import 'tables/shared_tables.dart';
import 'tables/user_module_tables.dart';

/// Singleton wrapper around the SQLite database.
///
/// ## Team usage
/// Each module adds its table definitions to a file under
/// `lib/core/database/tables/` and calls its `create()` method from
/// [_onCreate] below.
///
/// ## Schema versioning rule
/// During active development [_dbVersion] stays at 1.  Once the team
/// freezes the initial schema (first demo / integration sprint), any
/// subsequent schema change must:
///   1. Create a new DDL helper (e.g. `migration_v2_orders.dart`).
///   2. Bump [_dbVersion] by 1.
///   3. Add a guarded call in [_onUpgrade].
/// Never modify the existing table files retroactively.
class DatabaseHelper {
  static const String _dbName = 'tablego.db';

  // Bump this only after the team freezes the schema.
  // See class doc for the versioning rule.
  static const int _dbVersion = 1;

  // ── Singleton ─────────────────────────────────────────────────────────────
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  Database? _db;

  /// Returns the open database, opening it on first access.
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  // ── Test injection ────────────────────────────────────────────────────────

  /// Creates a [DatabaseHelper] backed by [db].
  ///
  /// Use this in tests with an in-memory sqflite_common_ffi database so that
  /// no file is created on disk and each test gets a clean slate.
  ///
  /// ```dart
  /// final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, ...);
  /// final helper = DatabaseHelper.forTesting(db);
  /// ```
  @visibleForTesting
  factory DatabaseHelper.forTesting(Database db) =>
      DatabaseHelper._internal().._db = db;

  // ── Initialisation ────────────────────────────────────────────────────────
  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enable foreign-key enforcement before any DDL or DML runs.
  ///
  /// [onConfigure] is the correct hook for this: it fires before [onCreate],
  /// [onUpgrade], and every subsequent open, so the pragma is always active.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create all tables.
  ///
  /// sqflite already wraps [onCreate] in a transaction, so we call the
  /// table helpers directly on [db] — nesting a second transaction is not
  /// supported by sqflite and would throw a [DatabaseException].
  Future<void> _onCreate(Database db, int version) async {
    // User module: users, client_profiles, restaurant_profiles,
    //              favorite_restaurants, favorite_dishes
    await UserModuleTables.create(db);

    // Shared tables: dishes, order_history
    // Defined here for FK integrity; content managed by the orders module.
    await SharedTables.create(db);

    // Seed test data in debug builds only — no-op in release.
    await DevSeed.run(db);

    if (kDebugMode) {
      debugPrint('[DB] Database created at version $version');
    }
  }

  /// Reserved for post-freeze schema changes.
  ///
  /// Rule: add a guarded block for each version increment.
  /// Example (do not uncomment until needed):
  ///
  /// ```dart
  /// if (oldVersion < 2) {
  ///   await MigrationV2Orders.up(db);
  /// }
  /// ```
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // No upgrades defined while _dbVersion == 1.
    // See class-level doc for the team versioning rule.
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Closes the database.  Call this only in tests or when you need to
  /// swap the database path (e.g. sqflite_common_ffi in-memory databases).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
