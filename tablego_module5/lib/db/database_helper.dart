import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/avis.dart';
import '../models/promotion.dart';
import '../ia/analyse_avis.dart';

class DatabaseHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    // nom propre au module 5 (le module 1 utilise deja tablego.db)
    String chemin = join(await getDatabasesPath(), 'tablego_module5.db');
    return await openDatabase(chemin,
        version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  // quand on change la version : on supprime les tables et on les recree
  // (on perd les donnees mais c'est des donnees de test)
  Future<void> _onUpgrade(Database db, int ancienne, int nouvelle) async {
    await db.execute('DROP TABLE IF EXISTS avis');
    await db.execute('DROP TABLE IF EXISTS promotions');
    await _onCreate(db, nouvelle);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE avis(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER,
        clientId INTEGER,
        clientNom TEXT,
        note INTEGER,
        commentaire TEXT,
        date TEXT,
        reponse TEXT,
        sentiment TEXT,
        spam INTEGER,
        UNIQUE(restaurantId, clientId)
      )
    ''');

    await db.execute('''
      CREATE TABLE promotions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER,
        titre TEXT,
        type TEXT,
        valeur REAL,
        code TEXT UNIQUE,
        dateFin TEXT,
        actif INTEGER
      )
    ''');

    // quelques donnees pour tester
    List<List> exemples = [
      [10, 'Nour B.', 5, 'Le couscous est généreux et le service magnifique.'],
      [11, 'Slah K.', 4, 'Très bon accueil, un peu d\'attente le samedi.'],
      [12, 'Amira T.', 2, 'Déçue, la ojja était froide et le service lent.'],
      [13, 'Youssef M.', 3, 'Correct, sans plus.'],
      [14, 'Karim H.', 5, 'Yaatik saha, lablabi behi barcha !'],
      [15, 'Promo', 5, 'Gagnez un iphone gratuit sur www.cadeau.com'],
    ];
    for (var e in exemples) {
      await db.insert('avis', {
        'restaurantId': 1,
        'clientId': e[0],
        'clientNom': e[1],
        'note': e[2],
        'commentaire': e[3],
        'date': '2026-10-15',
        'sentiment': AnalyseAvis.sentiment(e[3], e[2]),
        'spam': AnalyseAvis.estSpam(e[3]) ? 1 : 0,
      });
    }

    await db.insert('promotions', {
      'restaurantId': 1,
      'titre': 'Bienvenue',
      'type': '%',
      'valeur': 10,
      'code': 'BIENVENUE10',
      'dateFin': '2026-12-31',
      'actif': 1,
    });
    await db.insert('promotions', {
      'restaurantId': 1,
      'titre': 'Soirée malouf',
      'type': 'TND',
      'valeur': 5,
      'code': 'MALOUF5',
      'dateFin': '2026-11-30',
      'actif': 1,
    });
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
