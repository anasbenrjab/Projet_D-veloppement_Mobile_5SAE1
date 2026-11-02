/// No-op on non-web platforms: mobile keeps the default sqflite factory.
void configureWebDatabaseFactory() {}

/// No-op on non-web platforms: the web-worker fallback does not apply.
void switchToMainThreadWebDatabaseFactory() {}
