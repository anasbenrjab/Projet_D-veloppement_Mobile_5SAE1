import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../models/avis.dart';
import '../models/promotion.dart';

// CRUD du module 5 sur la base commune de TableGo (tablego.db)
// les tables avis et promotions sont creees dans
// core/database/tables/avis_promotions_tables.dart
// et les donnees de test dans core/database/seeds/avis_promotions_seed.dart
class AvisPromotionsDb {
  Future<Database> get db async {
    return await DatabaseHelper.instance.database;
  }

  // ---------------- AVIS ----------------

  Future<int> insertAvis(Avis avis) async {
    Database d = await db;
    return await d.insert('avis', avis.toMap());
  }

  Future<List<Avis>> getAvis(int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.query('avis',
        where: 'restaurantId = ?',
        whereArgs: [restaurantId],
        orderBy: 'id DESC');
    return res.map((e) => Avis.fromMap(e)).toList();
  }

  Future<int> updateAvis(Avis avis) async {
    Database d = await db;
    return await d
        .update('avis', avis.toMap(), where: 'id = ?', whereArgs: [avis.id]);
  }

  Future<int> deleteAvis(int id) async {
    Database d = await db;
    return await d.delete('avis', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> repondre(int id, String? reponse) async {
    Database d = await db;
    return await d.update('avis', {'reponse': reponse},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> publierAvis(int id) async {
    Database d = await db;
    return await d
        .update('avis', {'spam': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- PROMOTIONS ----------------

  Future<int> insertPromotion(Promotion p) async {
    Database d = await db;
    return await d.insert('promotions', p.toMap());
  }

  Future<List<Promotion>> getPromotions(int restaurantId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.query('promotions',
        where: 'restaurantId = ?',
        whereArgs: [restaurantId],
        orderBy: 'dateFin');
    return res.map((e) => Promotion.fromMap(e)).toList();
  }

  Future<Promotion?> getPromotionParCode(String code) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.query('promotions',
        where: 'code = ?', whereArgs: [code.toUpperCase()]);
    if (res.isEmpty) return null;
    return Promotion.fromMap(res.first);
  }

  Future<int> updatePromotion(Promotion p) async {
    Database d = await db;
    return await d
        .update('promotions', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deletePromotion(int id) async {
    Database d = await db;
    return await d.delete('promotions', where: 'id = ?', whereArgs: [id]);
  }
}
