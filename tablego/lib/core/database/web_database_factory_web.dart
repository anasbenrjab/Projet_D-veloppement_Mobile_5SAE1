import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Points sqflite at the sqlite3-wasm factory (persisted in IndexedDB).
///
/// Must run before anything opens the database.
void configureWebDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
