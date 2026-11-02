import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Points sqflite at the sqlite3-wasm factory (persisted in IndexedDB).
///
/// Uses the **basic** web worker: a plain `Worker` (`new Worker(uri)`) instead
/// of a `SharedWorker`.  The shared-worker path is unreliable on some browsers
/// (the package notes it "don't work on Android mobile web yet"), and when a
/// worker never replies sqflite hangs with no exception — see
/// [switchToMainThreadWebDatabaseFactory] for the fallback.
///
/// Must run before anything opens the database.
void configureWebDatabaseFactory() {
  if (kDebugMode) {
    // Prints the raw main-isolate ⇄ worker traffic (`main_send …` /
    // `main_recv …`).  A `main_send` line with no matching `main_recv` pins
    // down a worker that never replies — the only startup failure with no other
    // symptom (no exception, no console error).  Debug builds only.
    // Testing-only flag, hence the ignore: it is the only way to see the worker
    // traffic, and it never runs in release builds.
    // ignore: deprecated_member_use
    sqliteFfiWebDebugWebWorker = true;
    debugPrint('[Boot] configureWebDatabaseFactory: start (basic worker)');
  }
  // `forceAsBasicWorker` is tagged `@visibleForTesting` by the package but is
  // the supported way to opt into the basic worker (the package makes the very
  // same call internally for `databaseFactoryFfiWebBasicWebWorker`).
  // ignore: invalid_use_of_visible_for_testing_member
  final options = SqfliteFfiWebOptions(forceAsBasicWorker: true);
  databaseFactory = createDatabaseFactoryFfiWeb(options: options);
  if (kDebugMode) {
    // The factory itself is lazy: the worker (`sqflite_sw.js`) and
    // `sqlite3.wasm` are only fetched on the first real database call, so this
    // line returning proves nothing about the worker being reachable.
    debugPrint('[Boot] configureWebDatabaseFactory: done '
        '(factory=${databaseFactory.runtimeType})');
  }
}

/// Fallback factory: runs sqlite3-wasm directly on the main UI thread.
///
/// Used when the worker never answers the first call (see
/// `DatabaseHelper._probeWebWorker`).  Long queries can block the UI, which is
/// acceptable for development.  Only call this *before* the real database has
/// been opened: an unresponsive worker leaves sqflite's per-path open lock held
/// forever, so the same path must not be re-opened afterwards.
void switchToMainThreadWebDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
  if (kDebugMode) {
    debugPrint('[Boot] web database factory → main thread (no web worker)');
  }
}
