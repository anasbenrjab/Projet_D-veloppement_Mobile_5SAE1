/// Selects the platform database factory at compile time.
///
/// On web this resolves to [web_database_factory_web.dart], which points
/// sqflite at the sqlite3-wasm factory (`sqflite_common_ffi_web`).  On every
/// other platform it resolves to a no-op stub, so the web-only package is never
/// compiled into the mobile build.
library;

export 'web_database_factory_stub.dart'
    if (dart.library.js_interop) 'web_database_factory_web.dart';
