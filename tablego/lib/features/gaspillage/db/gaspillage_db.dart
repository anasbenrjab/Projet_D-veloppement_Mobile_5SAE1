import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../models/ingredient.dart';
import '../models/perte.dart';
import '../models/offre.dart';
import '../models/reservation_offre.dart';
import '../models/vente.dart';
import '../outils.dart';

// CRUD du module 4 sur la base commune de TableGo (tablego.db)
// les tables sont creees dans core/database/tables/gaspillage_tables.dart
// et les donnees de test dans core/database/seeds/gaspillage_seed.dart
class GaspillageDb {
  Future<Database> get db async {
    return await DatabaseHelper.instance.database;
  }

  // ---------------- INGREDIENTS ----------------

  Future<int> insertIngredient(Ingredient i) async {
    Database d = await db;
    return await d.insert('ingredients', i.toMap());
  }

  // tries par date de peremption : les plus urgents en premier
  Future<List<Ingredient>> getIngredients(int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.query('ingredients',
        where: 'restaurantId = ?',
        whereArgs: [restaurantId],
        orderBy: 'datePeremption');
    return res.map((e) => Ingredient.fromMap(e)).toList();
  }

  Future<int> updateIngredient(Ingredient i) async {
    Database d = await db;
    return await d
        .update('ingredients', i.toMap(), where: 'id = ?', whereArgs: [i.id]);
  }

  Future<int> deleteIngredient(int id) async {
    Database d = await db;
    return await d.delete('ingredients', where: 'id = ?', whereArgs: [id]);
  }

  // ingredient perime ou abime : on l'ajoute au journal et on le retire du stock
  Future<void> jeterIngredient(Ingredient i, String raison) async {
    Database d = await db;
    await d.transaction((txn) async {
      await txn.insert(
          'pertes',
          Perte(
            restaurantId: i.restaurantId,
            produit: i.nom,
            quantite: i.quantite,
            unite: i.unite,
            raison: raison,
            cout: i.valeurStock(),
            date: formatDate(aujourdhui()),
          ).toMap());
      await txn.delete('ingredients', where: 'id = ?', whereArgs: [i.id]);
    });
  }

  // ---------------- JOURNAL DE GASPILLAGE ----------------

  Future<int> insertPerte(Perte p) async {
    Database d = await db;
    return await d.insert('pertes', p.toMap());
  }

  Future<List<Perte>> getPertes(int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.query('pertes',
        where: 'restaurantId = ?',
        whereArgs: [restaurantId],
        orderBy: 'date DESC, id DESC');
    return res.map((e) => Perte.fromMap(e)).toList();
  }

  Future<int> updatePerte(Perte p) async {
    Database d = await db;
    return await d
        .update('pertes', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deletePerte(int id) async {
    Database d = await db;
    return await d.delete('pertes', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- OFFRES ANTI-GASPI ----------------

  Future<int> insertOffre(Offre o) async {
    Database d = await db;
    return await d.insert('offres', o.toMap());
  }

  Future<List<Offre>> getOffres(int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.query('offres',
        where: 'restaurantId = ?',
        whereArgs: [restaurantId],
        orderBy: 'date DESC, heureFin');
    return res.map((e) => Offre.fromMap(e)).toList();
  }

  Future<int> updateOffre(Offre o) async {
    Database d = await db;
    return await d
        .update('offres', o.toMap(), where: 'id = ?', whereArgs: [o.id]);
  }

  // on supprime aussi les reservations de cette offre
  Future<void> deleteOffre(int id) async {
    Database d = await db;
    await d.delete('reservations_offres', where: 'offreId = ?', whereArgs: [id]);
    await d.delete('offres', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- RESERVATIONS DES OFFRES ----------------

  // retourne false si il n'y a plus assez de portions
  Future<bool> reserverOffre(
      Offre o, int quantite, int clientId, String clientNom) async {
    Database d = await db;
    bool ok = false;
    await d.transaction((txn) async {
      // on relit la quantite dans la base (un autre client a peut-etre reserve)
      List<Map<String, dynamic>> res =
          await txn.query('offres', where: 'id = ?', whereArgs: [o.id]);
      if (res.isEmpty) return;
      int reste = res.first['quantite'];
      if (reste < quantite) return;

      await txn.insert(
          'reservations_offres',
          ReservationOffre(
            offreId: o.id!,
            clientId: clientId,
            clientNom: clientNom,
            quantite: quantite,
            date: formatDate(aujourdhui()),
          ).toMap());
      await txn.update('offres', {'quantite': reste - quantite},
          where: 'id = ?', whereArgs: [o.id]);
      ok = true;
    });
    return ok;
  }

  // annuler : on rend les portions a l'offre
  Future<void> annulerReservation(ReservationOffre r) async {
    Database d = await db;
    await d.transaction((txn) async {
      await txn.delete('reservations_offres',
          where: 'id = ?', whereArgs: [r.id]);
      await txn.rawUpdate(
          'UPDATE offres SET quantite = quantite + ? WHERE id = ?',
          [r.quantite, r.offreId]);
    });
  }

  // reservations d'un client dans ce restaurant, avec les infos de l'offre
  Future<List<ReservationOffre>> getReservationsClient(
      int clientId, int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.rawQuery('''
      SELECT r.*, o.plat, o.prixReduit, o.heureFin, o.date AS dateOffre
      FROM reservations_offres r
      JOIN offres o ON o.id = r.offreId
      WHERE r.clientId = ? AND o.restaurantId = ?
      ORDER BY r.id DESC
    ''', [clientId, restaurantId]);
    return res.map((e) => ReservationOffre.fromMap(e)).toList();
  }

  // pour le restaurant : combien de portions reservees par offre
  Future<Map<int, int>> getPortionsReservees(int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.rawQuery('''
      SELECT r.offreId, SUM(r.quantite) AS total
      FROM reservations_offres r
      JOIN offres o ON o.id = r.offreId
      WHERE o.restaurantId = ?
      GROUP BY r.offreId
    ''', [restaurantId]);
    Map<int, int> m = {};
    for (var e in res) {
      m[e['offreId']] = e['total'];
    }
    return m;
  }

  // ---------------- VENTES (historique pour l'IA) ----------------

  Future<int> insertVente(Vente v) async {
    Database d = await db;
    return await d.insert('ventes', v.toMap());
  }

  Future<List<Vente>> getVentes(int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.query('ventes',
        where: 'restaurantId = ?',
        whereArgs: [restaurantId],
        orderBy: 'date DESC');
    return res.map((e) => Vente.fromMap(e)).toList();
  }
}
