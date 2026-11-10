import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'in_memory_store.dart';
import 'seed_images.dart';

/// Unified database helper.
/// - Web → delegates to InMemoryStore (pure Dart, persisted in localStorage)
/// - Android/iOS → native sqflite
/// - Windows/Linux/macOS → sqflite_common_ffi
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  // Delegate to in-memory store on web
  bool get _isWeb => kIsWeb;

  static sqflite.Database? _db;
  static const int _version = 1;

  /// Call once at startup (main). On web, restores the persisted store.
  Future<void> init() async {
    if (_isWeb) {
      await InMemoryStore.instance.init();
    } else {
      await _database;
    }
  }

  Future<sqflite.Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<sqflite.Database> _initDb() async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final dir = await factory.getDatabasesPath();
      final path = p.join(dir, 'tablego_module2.db');
      return factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _version,
          onCreate: _onCreate,

        ),
      );
    }
    final dir = await sqflite.getDatabasesPath();
    final path = p.join(dir, 'tablego_module2.db');
    return sqflite.openDatabase(path,
        version: _version, onCreate: _onCreate);
  }
  Future<void> _onCreate(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        price REAL NOT NULL,
        category TEXT NOT NULL,
        image_path TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        allergens TEXT NOT NULL DEFAULT '',
        restaurant_id INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dish_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        added_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'reçue',
        total_price REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        client_name TEXT NOT NULL DEFAULT 'Client',
        restaurant_id INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        dish_id INTEGER NOT NULL,
        dish_name TEXT NOT NULL,
        dish_price REAL NOT NULL,
        quantity INTEGER NOT NULL
      )
    ''');
    await _seedDb(db);
    debugPrint('[DB] ✓ created & seeded');
  }

  Future<void> _seedDb(sqflite.Database db) async {
    final now = DateTime.now().toIso8601String();
    final dishes = <Map<String, dynamic>>[
      {
        'name': 'Couscous Royal',
        'description': 'Semoule fine avec légumes mijotés, merguez, poulet et agneau.',
        'price': 28.500, 'category': 'Plat principal',
        'is_available': 1, 'allergens': 'Gluten, Lait',
        'restaurant_id': 1, 'created_at': now,
      },
      {
        'name': 'Salade Méchouia',
        'description': 'Poivrons et tomates grillés, thon, câpres et œufs durs.',
        'price': 12.000, 'category': 'Entrée',
        'is_available': 1, 'allergens': 'Poisson, Œuf',
        'restaurant_id': 1, 'created_at': now,
      },
      {
        'name': 'Tajine Agneau',
        'description': 'Agneau tendre aux épices, citrons confits et olives.',
        'price': 32.000, 'category': 'Plat principal',
        'is_available': 1, 'allergens': 'Aucun',
        'restaurant_id': 1, 'created_at': now,
      },
      {
        'name': 'Brik au Thon',
        'description': 'Feuille de brick croustillante, thon, câpres et œuf.',
        'price': 7.500, 'category': 'Entrée',
        'is_available': 1, 'allergens': 'Gluten, Poisson, Œuf',
        'restaurant_id': 1, 'created_at': now,
      },
      {
        'name': 'Lablabi',
        'description': 'Soupe de pois chiches au cumin, harissa et croûtons.',
        'price': 9.000, 'category': 'Entrée',
        'is_available': 1, 'allergens': 'Gluten',
        'restaurant_id': 1, 'created_at': now,
      },
      {
        'name': 'Makroudh',
        'description': 'Gâteau de semoule aux dattes, frit et trempé au miel.',
        'price': 5.000, 'category': 'Dessert',
        'is_available': 1, 'allergens': 'Gluten, Fruits à coque',
        'restaurant_id': 1, 'created_at': now,
      },
      {
        'name': 'Thé à la Menthe',
        'description': 'Thé vert parfumé à la menthe fraîche et pignons.',
        'price': 4.000, 'category': 'Boisson',
        'is_available': 1, 'allergens': 'Fruits à coque',
        'restaurant_id': 1, 'created_at': now,
      },
      {
        'name': 'Crème Caramel',
        'description': 'Crème onctueuse renversée au caramel doré.',
        'price': 8.000, 'category': 'Dessert',
        'is_available': 1, 'allergens': 'Lait, Œuf',
        'restaurant_id': 1, 'created_at': now,
      },
    ];
    for (final d in dishes) {
      await db.insert('dishes', {...d, 'image_path': kSeedDishImages[d['name']]});
    }
  }

  // ── Public CRUD (delegates to InMemoryStore on web, sqflite elsewhere) ──────

  Future<int> insert(String table, Map<String, dynamic> row) async {
    if (_isWeb) return InMemoryStore.instance.insert(table, row);
    return (await _database).insert(table, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    if (_isWeb) {
      return InMemoryStore.instance.query(table,
          where: where, whereArgs: whereArgs, orderBy: orderBy);
    }
    return (await _database).query(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> row, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    if (_isWeb) {
      return InMemoryStore.instance.update(table, row,
          where: where, whereArgs: whereArgs);
    }
    return (await _database).update(table, row,
        where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    if (_isWeb) {
      return InMemoryStore.instance.delete(table,
          where: where, whereArgs: whereArgs);
    }
    return (await _database)
        .delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
      String sql, List<dynamic> args) async {
    if (_isWeb) return InMemoryStore.instance.rawQuery(sql, args);
    return (await _database).rawQuery(sql, args);
  }
}
