import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'seeds/avis_promotions_seed.dart';
import 'seeds/dev_seed.dart';
import 'seeds/events_seed.dart';
import 'seeds/gaspillage_seed.dart';
import 'seeds/menu_seed.dart';
import 'tables/avis_promotions_tables.dart';
import 'tables/events_tables.dart';
import 'tables/gaspillage_tables.dart';
import 'tables/menu_tables.dart';
import 'tables/shared_tables.dart';
import 'tables/user_module_tables.dart';
import 'web_database_factory.dart';

/// Singleton wrapper around the SQLite database.
///
/// ## Team usage
/// Each module adds its table definitions to a file under
/// `lib/core/database/tables/` and calls its `create()` method from
/// [_onCreate] below.
///
/// ## Schema versioning rule
/// Every schema change:
///   1. Adds the new DDL to the owning module's table file as an idempotent
///      (`IF NOT EXISTS`) helper, called from that module's `create()` so new
///      databases get it.
///   2. Bumps [_dbVersion] by 1.
///   3. Calls the same helper from a guarded block in [_onUpgrade] so existing
///      databases get it.
/// Never modify a shipped table definition retroactively.
class DatabaseHelper {
  static const String _dbName = 'tablego.db';

  // Bump this for every schema change.  See class doc for the versioning rule.
  //   v1 — initial user-module + shared tables
  //   v2 — profile_photos (web photo bytes)
  //   v3 — dishes.allergens (recommendations)
  //   v4 — Module 2 (menu + commande): dishes.category, cart_items, orders,
  //        order_items; order_history becomes a VIEW over orders/order_items
  //   v5 — Module 3 (événements + réservations): evenement, reservation,
  //        restaurant_profiles.seat_capacity
  //   v6 — Module 5 (avis + promotions): avis, promotions
  //   v7 — Module 4 (gaspillage alimentaire): ingredients, pertes, offres,
  //        reservations_offres, ventes
  static const int _dbVersion = 7;

  /// Current schema version, exposed for tests and tooling.
  static int get schemaVersion => _dbVersion;

  /// Upper bound on the first web database open.
  ///
  /// `sqflite_common_ffi_web` talks to its Web Worker with **no timeout**: the
  /// reply future only completes when the worker answers (or fires `onerror`
  /// for the very first message).  If `sqflite_sw.js` / `sqlite3.wasm` never
  /// initialises, the worker stays silent and `openDatabase` never completes —
  /// the app freezes with no exception and nothing in the console.  Bounding it
  /// here turns that invisible freeze into an actionable error.
  static const _webOpenTimeout = Duration(seconds: 20);

  /// Upper bound on the throwaway web-worker probe (see [_probeWebWorker]).
  ///
  /// Only used to detect a **silent** worker (one that never replies at all);
  /// a wasm that fails to instantiate reports back immediately with an error.
  static const _webProbeTimeout = Duration(seconds: 10);

  // ── Singleton ─────────────────────────────────────────────────────────────
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  Database? _db;

  /// Returns the open database, opening it on first access.
  Future<Database> get database async {
    if (_db == null && kDebugMode) debugPrint('[DB] database: opening');
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

  /// Makes the app-wide [instance] use [db] (or reopen normally when null).
  ///
  /// For whole-app widget tests: Module 2/3 screens and several providers
  /// read [instance] directly instead of an injected helper.
  @visibleForTesting
  static void useDatabaseForTesting(Database? db) => instance._db = db;

  // ── Initialisation ────────────────────────────────────────────────────────
  Future<Database> _initDb() async {
    final sw = Stopwatch()..start();
    // Web (sqflite_common_ffi_web) keys databases by name inside IndexedDB —
    // there is no filesystem path.  Mobile keeps the on-device path.
    final dbPath =
        kIsWeb ? _dbName : join(await getDatabasesPath(), _dbName);

    // Verify the web worker answers *before* touching `tablego.db`.  See
    // [_probeWebWorker] for why the probe cannot reuse the real path.
    if (kIsWeb) await _probeWebWorker();

    if (kDebugMode) {
      debugPrint('[DB] openDatabase: start ($dbPath, v$_dbVersion) — '
          'first web call loads sqflite_sw.js + sqlite3.wasm');
    }
    final openFuture = openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
    // Bound the wait on web only — see [_webOpenTimeout].  Mobile keeps the
    // plain await so its behaviour is unchanged.
    final db = kIsWeb
        ? await openFuture.timeout(
            _webOpenTimeout,
            onTimeout: () => throw StateError(
              'The sqflite web worker did not reply within '
              '${_webOpenTimeout.inSeconds}s. Check Chrome DevTools → Network '
              'that sqflite_sw.js and sqlite3.wasm both load (HTTP 200), then '
              'clear the site data for this origin and reload.',
            ),
          )
        : await openFuture;
    if (kDebugMode) {
      debugPrint('[DB] openDatabase: end (${sw.elapsedMilliseconds}ms)');
    }
    return db;
  }

  /// Checks that the web database worker is responsive, falling back to the
  /// main thread if it stays **silent**.
  ///
  /// sqflite serialises opens of a given path behind a **process-wide** lock
  /// (`_NamedLock.cacheLocks`) that is released only when the open future
  /// completes.  A worker that never replies therefore holds the lock on
  /// `tablego.db` forever, so re-opening that same path — even through a
  /// different factory — deadlocks.  Probing with a distinct throwaway
  /// in-memory path leaves the real path untouched, so we can still switch to
  /// the main-thread factory and open `tablego.db` afterwards.
  ///
  /// A worker that answers with an **error** is a different story: the reply
  /// releases the lock, so it is safe to let the error through.  It is also
  /// pointless to fall back — both factories load the same `sqlite3.wasm`, so
  /// the main thread would fail identically.  Such errors are reported instead
  /// of being swallowed.
  Future<void> _probeWebWorker() async {
    final sw = Stopwatch()..start();
    try {
      final probe =
          await openDatabase(inMemoryDatabasePath).timeout(_webProbeTimeout);
      await probe.close();
      if (kDebugMode) {
        debugPrint('[DB] web worker probe: ok (${sw.elapsedMilliseconds}ms)');
      }
    } on TimeoutException {
      // No reply at all: run sqlite3-wasm on the main thread so the app still
      // works during development.
      if (kDebugMode) {
        debugPrint('[DB] web worker probe: no reply after '
            '${sw.elapsedMilliseconds}ms → main-thread fallback');
      }
      switchToMainThreadWebDatabaseFactory();
    } catch (e, st) {
      // Typically `TypeError: WebAssembly.instantiate(): Import #25 "env":
      // module is not an object or function`, i.e. `web/sqlite3.wasm` does not
      // match the `sqlite3` version resolved in pubspec.lock.
      if (kDebugMode) {
        debugPrint('[DB] web worker probe: FAILED after '
            '${sw.elapsedMilliseconds}ms — sqlite3.wasm did not load. This is '
            'not a worker issue: the main thread loads the same file. Check '
            'that web/sqlite3.wasm matches the sqlite3 version in '
            'pubspec.lock.\n${e.runtimeType}: $e\n$st');
      }
      // Surfaced to the UI as a French "cannot open the local database"
      // message — see AuthNotifier._parseError.
      throw StateError('Local web database initialisation failed: $e');
    }
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
    final sw = Stopwatch()..start();
    if (kDebugMode) debugPrint('[DB] onCreate: start (version $version)');

    // User module: users, client_profiles, restaurant_profiles,
    //              favorite_restaurants, favorite_dishes, profile_photos
    await UserModuleTables.create(db);
    if (kDebugMode) {
      debugPrint('[DB] onCreate: user-module tables done '
          '(${sw.elapsedMilliseconds}ms)');
    }

    // Shared tables: dishes, order_history (the v1 table, replaced by a view
    // in MenuTables.create below).  Defined here for FK integrity.
    await SharedTables.create(db);
    if (kDebugMode) {
      debugPrint('[DB] onCreate: shared tables done '
          '(${sw.elapsedMilliseconds}ms)');
    }

    // Module 2 (menu + commande): dishes.category, cart_items, orders,
    // order_items, and the order_history view.
    await MenuTables.create(db);
    if (kDebugMode) {
      debugPrint('[DB] onCreate: menu tables done '
          '(${sw.elapsedMilliseconds}ms)');
    }

    // Module 3 (événements + réservations): evenement, reservation,
    // restaurant_profiles.seat_capacity.
    await EventsTables.create(db);
    if (kDebugMode) {
      debugPrint('[DB] onCreate: events tables done '
          '(${sw.elapsedMilliseconds}ms)');
    }

    // Module 5 (avis + promotions): avis, promotions.
    await AvisPromotionsTables.create(db);
    // Module 4 (gaspillage): ingredients, pertes, offres,
    // reservations_offres, ventes.
    await GaspillageTables.create(db);

    // Seed test data in debug builds only — no-op in release.
    await DevSeed.run(db);
    // Module 3 demo (needs the seeded restaurant and demo clients).
    await EventsSeed.applyEventsDemo(db);
    // Module 5 demo (same restaurant and demo clients).
    await AvisPromotionsSeed.applyAvisDemo(db);
    // Module 4 demo (same restaurant).
    await GaspillageSeed.applyGaspillageDemo(db);

    if (kDebugMode) {
      debugPrint('[DB] onCreate: end (version $version, '
          '${sw.elapsedMilliseconds}ms)');
    }
  }

  /// Runs after every open, once [onCreate]/[onUpgrade] are done.
  ///
  /// Backfills the dev-seed demo data (recommendation menu, allergens, demo
  /// clients) and photos on databases seeded before they existed (debug
  /// builds only; a no-op once they are set).  This is data, not schema, so
  /// it does not bump [_dbVersion].
  Future<void> _onOpen(Database db) async {
    await DevSeed.applyRecommendationDemo(db);
    await MenuSeed.applyMenuDemo(db);
    await EventsSeed.applyEventsDemo(db);
    await AvisPromotionsSeed.applyAvisDemo(db);
    await GaspillageSeed.applyGaspillageDemo(db);
    await DevSeed.applySeedPhotos(db);
  }

  /// Applies schema changes to an existing database, one guarded block per
  /// version bump.
  ///
  /// Like [onCreate], sqflite already wraps this in a transaction — do not
  /// open another one here.  Every step is idempotent (`IF NOT EXISTS`), so a
  /// database that already has the objects is left unchanged.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) debugPrint('[DB] onUpgrade: v$oldVersion → v$newVersion');
    await migrate(db, oldVersion, newVersion);
  }

  /// The upgrade steps, one guarded block per version.  Public so tests can
  /// run a real v2 → v3 upgrade on a test database.
  @visibleForTesting
  static Future<void> migrate(
      DatabaseExecutor db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: profile_photos (web photo bytes).
      await UserModuleTables.createProfilePhotos(db);
    }
    if (oldVersion < 3) {
      // v3: dishes.allergens (recommendations).
      await SharedTables.addDishAllergens(db);
    }
    if (oldVersion < 4) {
      // v4: Module 2 tables; order_history rows move into orders/order_items
      // and the table is replaced by a view.
      await MenuTables.create(db);
    }
    if (oldVersion < 5) {
      // v5: Module 3 tables (events, table reservations, seat capacity).
      await EventsTables.create(db);
    }
    if (oldVersion < 6) {
      // v6: Module 5 tables (avis, promotions).
      await AvisPromotionsTables.create(db);
    }
    if (oldVersion < 7) {
      // v7: Module 4 tables (ingredients, pertes, offres anti-gaspi,
      // reservations_offres, ventes).
      await GaspillageTables.create(db);
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Closes the database.  Call this only in tests or when you need to
  /// swap the database path (e.g. sqflite_common_ffi in-memory databases).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
