import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ingredient.dart';
import '../models/perte.dart';
import '../models/offre.dart';
import '../models/reservation_offre.dart';
import '../models/vente.dart';
import '../outils.dart';

class DatabaseHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    // nom propre au module 4 (le module 1 utilise deja tablego.db)
    String chemin = join(await getDatabasesPath(), 'tablego_module4.db');
    return await openDatabase(chemin,
        version: 1, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  // quand on change la version : on supprime les tables et on les recree
  // (on perd les donnees mais c'est des donnees de test)
  Future<void> _onUpgrade(Database db, int ancienne, int nouvelle) async {
    await db.execute('DROP TABLE IF EXISTS ingredients');
    await db.execute('DROP TABLE IF EXISTS pertes');
    await db.execute('DROP TABLE IF EXISTS offres');
    await db.execute('DROP TABLE IF EXISTS reservations_offres');
    await db.execute('DROP TABLE IF EXISTS ventes');
    await _onCreate(db, nouvelle);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ingredients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER,
        nom TEXT,
        quantite REAL,
        unite TEXT,
        cout REAL,
        datePeremption TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pertes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER,
        produit TEXT,
        quantite REAL,
        unite TEXT,
        raison TEXT,
        cout REAL,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE offres(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER,
        plat TEXT,
        prixInitial REAL,
        prixReduit REAL,
        quantite INTEGER,
        date TEXT,
        heureFin TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reservations_offres(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offreId INTEGER,
        clientId INTEGER,
        clientNom TEXT,
        quantite INTEGER,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ventes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurantId INTEGER,
        plat TEXT,
        preparees INTEGER,
        vendues INTEGER,
        date TEXT
      )
    ''');

    await _donneesDeTest(db);
  }

  // date d'aujourd'hui + n jours (n negatif = dans le passe)
  String _jour(int n) {
    return formatDate(aujourdhui().add(Duration(days: n)));
  }

  Future<void> _donneesDeTest(Database db) async {
    // stock : [nom, quantite, unite, cout, jours avant peremption]
    List<List> stock = [
      ['Tomate', 5, 'kg', 1.8, 2],
      ['Poivron', 3, 'kg', 2.5, 1],
      ['Oeuf', 30, 'pièce', 0.35, 3],
      ['Poulet', 4, 'kg', 11.5, 5],
      ['Lait', 6, 'L', 1.4, -1],
      ['Semoule', 10, 'kg', 1.9, 120],
      ['Pomme de terre', 8, 'kg', 1.2, 10],
      ['Thon', 12, 'pièce', 3.2, 200],
      ['Courgette', 2, 'kg', 1.6, 2],
      ['Fromage', 1.5, 'kg', 24, 6],
    ];
    for (var s in stock) {
      await db.insert('ingredients', {
        'restaurantId': 1,
        'nom': s[0],
        'quantite': s[1],
        'unite': s[2],
        'cout': s[3],
        'datePeremption': _jour(s[4]),
      });
    }

    // journal : [produit, quantite, unite, raison, cout, il y a combien de jours]
    List<List> pertes = [
      ['Pain', 20, 'pièce', 'Surproduction', 4.0, 1],
      ['Couscous', 6, 'pièce', 'Surproduction', 36.0, 2],
      ['Lait', 2, 'L', 'Périmé', 2.8, 4],
      ['Salade verte', 1.5, 'kg', 'Abîmé', 4.5, 6],
      ['Ojja', 2, 'pièce', 'Retour client', 17.0, 9],
      ['Poisson', 1, 'kg', 'Périmé', 28.0, 12],
      ['Lablabi', 5, 'pièce', 'Surproduction', 17.5, 15],
      ['Tomate', 2, 'kg', 'Abîmé', 3.6, 21],
      ['Couscous', 4, 'pièce', 'Surproduction', 24.0, 40],
    ];
    for (var p in pertes) {
      await db.insert('pertes', {
        'restaurantId': 1,
        'produit': p[0],
        'quantite': p[1],
        'unite': p[2],
        'raison': p[3],
        'cout': p[4],
        'date': _jour(-p[5]),
      });
    }

    // historique des ventes des 4 dernieres semaines pour 3 plats
    // (le week-end on vend plus, et on prepare toujours la meme quantite)
    Random r = Random(4);
    List<List> plats = [
      ['Couscous', 30, 18],
      ['Ojja', 20, 12],
      ['Lablabi', 25, 15],
    ];
    for (int n = 28; n >= 1; n--) {
      DateTime d = aujourdhui().subtract(Duration(days: n));
      for (var p in plats) {
        int base = p[2];
        if (d.weekday == 5) base = base + 4; // vendredi
        if (d.weekday >= 6) base = base + 8; // samedi et dimanche
        int vendues = base + r.nextInt(5) - 2;
        if (vendues > p[1]) vendues = p[1];
        await db.insert('ventes', {
          'restaurantId': 1,
          'plat': p[0],
          'preparees': p[1],
          'vendues': vendues,
          'date': formatDate(d),
        });
      }
    }

    // 2 offres anti-gaspi pour ce soir
    await db.insert('offres', {
      'restaurantId': 1,
      'plat': 'Couscous au poulet',
      'prixInitial': 18.0,
      'prixReduit': 10.0,
      'quantite': 6,
      'date': _jour(0),
      'heureFin': '23:00',
    });
    await db.insert('offres', {
      'restaurantId': 1,
      'plat': 'Ojja merguez',
      'prixInitial': 12.0,
      'prixReduit': 7.5,
      'quantite': 4,
      'date': _jour(0),
      'heureFin': '22:30',
    });
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

  // reservations d'un client avec les infos de l'offre (jointure)
  Future<List<ReservationOffre>> getReservationsClient(int clientId) async {
    Database d = await db;
    List<Map<String, dynamic>> res = await d.rawQuery('''
      SELECT r.*, o.plat, o.prixReduit, o.heureFin, o.date AS dateOffre
      FROM reservations_offres r
      JOIN offres o ON o.id = r.offreId
      WHERE r.clientId = ?
      ORDER BY r.id DESC
    ''', [clientId]);
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
