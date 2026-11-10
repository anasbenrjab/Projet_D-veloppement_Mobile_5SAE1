/// Tables du Module 5 (Avis + Promotions).
///
/// Dans l'application TableGo, le restaurant et le client sont les tables
/// partagees du module 1 :
///
/// * `avis.restaurantId`       -> `restaurant_profiles.id`
/// * `avis.clientId`           -> `users.id` (le client connecte)
/// * `promotions.restaurantId` -> `restaurant_profiles.id`
///
/// Les noms des tables et des colonnes sont ceux du Module 5.
/// [create] est appele depuis `onCreate` (nouvelle base) et depuis le bloc
/// v6 de `DatabaseHelper.migrate` (base existante) : `IF NOT EXISTS`.
library;

import 'package:sqflite/sqflite.dart';

class AvisPromotionsTables {
  AvisPromotionsTables._();

  static Future<void> create(DatabaseExecutor db) async {
    // un client donne un seul avis par restaurant (il peut le modifier)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS avis(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER NOT NULL,
        clientId INTEGER NOT NULL,
        clientNom TEXT NOT NULL,
        note INTEGER NOT NULL,
        commentaire TEXT NOT NULL,
        date TEXT NOT NULL,
        reponse TEXT,
        sentiment TEXT NOT NULL,
        spam INTEGER NOT NULL DEFAULT 0,
        UNIQUE(restaurantId, clientId),
        FOREIGN KEY (restaurantId)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE,
        FOREIGN KEY (clientId)
          REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS promotions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER NOT NULL,
        titre TEXT NOT NULL,
        type TEXT NOT NULL,
        valeur REAL NOT NULL,
        code TEXT NOT NULL UNIQUE,
        dateFin TEXT NOT NULL,
        actif INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (restaurantId)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');
  }
}
