/// Tables du Module 4 (Gaspillage alimentaire).
///
/// Dans l'application TableGo, le restaurant et le client sont les tables
/// partagees du module 1 :
///
/// * `ingredients.restaurantId`   -> `restaurant_profiles.id`
/// * `pertes.restaurantId`        -> `restaurant_profiles.id`
/// * `offres.restaurantId`        -> `restaurant_profiles.id`
/// * `ventes.restaurantId`        -> `restaurant_profiles.id`
/// * `reservations_offres.offreId`  -> `offres.id`
/// * `reservations_offres.clientId` -> `users.id` (le client connecte)
///
/// Les noms des tables et des colonnes sont ceux du Module 4.
/// [create] est appele depuis `onCreate` (nouvelle base) et depuis le bloc
/// v7 de `DatabaseHelper.migrate` (base existante) : `IF NOT EXISTS`.
library;

import 'package:sqflite/sqflite.dart';

class GaspillageTables {
  GaspillageTables._();

  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingredients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER NOT NULL,
        nom TEXT NOT NULL,
        quantite REAL NOT NULL,
        unite TEXT NOT NULL,
        cout REAL NOT NULL,
        datePeremption TEXT NOT NULL,
        FOREIGN KEY (restaurantId)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pertes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER NOT NULL,
        produit TEXT NOT NULL,
        quantite REAL NOT NULL,
        unite TEXT NOT NULL,
        raison TEXT NOT NULL,
        cout REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (restaurantId)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offres(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER NOT NULL,
        plat TEXT NOT NULL,
        prixInitial REAL NOT NULL,
        prixReduit REAL NOT NULL,
        quantite INTEGER NOT NULL,
        date TEXT NOT NULL,
        heureFin TEXT NOT NULL,
        FOREIGN KEY (restaurantId)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reservations_offres(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offreId INTEGER NOT NULL,
        clientId INTEGER NOT NULL,
        clientNom TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (offreId)
          REFERENCES offres(id) ON DELETE CASCADE,
        FOREIGN KEY (clientId)
          REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER NOT NULL,
        plat TEXT NOT NULL,
        preparees INTEGER NOT NULL,
        vendues INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (restaurantId)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');
  }
}
