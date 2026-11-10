/// Module 2 (Menu + Commande) demo data — debug builds only.
///
/// * [MenuSeed.insertOrder] writes one seeded order (`orders` + one
///   `order_items` line).  The dev seed uses it wherever it used to insert
///   into the old `order_history` table, which is now a view.
/// * [MenuSeed.applyMenuDemo] adds Module 2's Tunisian demo menu (with
///   categories and photos) to the `resto@test.com` restaurant, idempotently.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Photos for the seeded dishes (TheMealDB + Unsplash, both CORS-friendly).
const _mealDb = 'https://www.themealdb.com/images/media/meals';
const _unsplash = 'https://images.unsplash.com/photo';

const Map<String, String> kSeedDishImages = {
  'Couscous Royal': '$_mealDb/qxytrx1511304021.jpg',
  'Salade Méchouia': '$_unsplash-1540189549336-e6e99c3679fe?w=600&q=70',
  'Tajine Agneau': '$_mealDb/yuwtuu1511295751.jpg',
  'Brik au Thon': '$_mealDb/2dsltq1560461468.jpg',
  'Lablabi': '$_mealDb/t8mn9g1560460231.jpg',
  'Makroudh': '$_mealDb/u4scbo1764446514.jpg',
  'Thé à la Menthe': '$_unsplash-1556679343-c7306c1976bc?w=600&q=70',
  'Crème Caramel': '$_unsplash-1488477181946-6428a0291777?w=600&q=70',
};

/// Module 2's seeded menu: (name, description, price, category, allergens).
/// Allergens use the shared normalised vocabulary
/// (docs/integration-recommandations.md); `[]` = declared, none.
const _demoMenu = <(String, String, double, String, List<String>)>[
  (
    'Couscous Royal',
    'Semoule fine avec légumes mijotés, merguez, poulet et agneau.',
    28.500,
    'Plat principal',
    ['gluten', 'lactose'],
  ),
  (
    'Salade Méchouia',
    'Poivrons et tomates grillés, thon, câpres et œufs durs.',
    12.000,
    'Entrée',
    ['poisson', 'oeufs'],
  ),
  (
    'Tajine Agneau',
    'Agneau tendre aux épices, citrons confits et olives.',
    32.000,
    'Plat principal',
    [],
  ),
  (
    'Brik au Thon',
    'Feuille de brick croustillante, thon, câpres et œuf.',
    7.500,
    'Entrée',
    ['gluten', 'poisson', 'oeufs'],
  ),
  (
    'Lablabi',
    'Soupe de pois chiches au cumin, harissa et croûtons.',
    9.000,
    'Entrée',
    ['gluten'],
  ),
  (
    'Makroudh',
    'Gâteau de semoule aux dattes, frit et trempé au miel.',
    5.000,
    'Dessert',
    ['gluten', 'fruits a coque'],
  ),
  (
    'Thé à la Menthe',
    'Thé vert parfumé à la menthe fraîche et pignons.',
    4.000,
    'Boisson',
    ['fruits a coque'],
  ),
  (
    'Crème Caramel',
    'Crème onctueuse renversée au caramel doré.',
    8.000,
    'Dessert',
    ['lactose', 'oeufs'],
  ),
];

const _demoRestaurantEmail = 'resto@test.com';

class MenuSeed {
  MenuSeed._();

  /// Inserts one seeded order with a single line for [dishId], dated [at]
  /// (default: now).  The dish name and price are snapshotted like a real
  /// checkout.  Opens no transaction (safe inside `onCreate`).
  static Future<void> insertOrder(
    DatabaseExecutor db, {
    required int userId,
    required int restaurantId,
    required int dishId,
    DateTime? at,
  }) async {
    final dish = (await db.query(
      'dishes',
      columns: ['name', 'price'],
      where: 'id = ?',
      whereArgs: [dishId],
      limit: 1,
    )).firstOrNull;
    final price = (dish?['price'] as num?)?.toDouble() ?? 0.0;
    final orderId = await db.insert('orders', {
      'user_id': userId,
      'restaurant_id': restaurantId,
      'order_type': 'sur place',
      'status': 'prête',
      'total_price': price,
      'created_at': (at ?? DateTime.now()).toUtc().toIso8601String(),
    });
    await db.insert('order_items', {
      'order_id': orderId,
      'dish_id': dishId,
      'dish_name': dish?['name'] ?? 'Plat supprimé',
      'dish_price': price,
      'quantity': 1,
    });
  }

  /// Adds Module 2's demo menu to `resto@test.com` and fills in the category
  /// of seed dishes that have none.  Idempotent; no-op outside debug builds.
  static Future<void> applyMenuDemo(DatabaseExecutor db) async {
    if (!kDebugMode) return;
    final rows = await db.rawQuery(
      '''
      SELECT rp.id FROM restaurant_profiles rp
        JOIN users u ON u.id = rp.user_id
       WHERE u.email = ?
    ''',
      [_demoRestaurantEmail],
    );
    if (rows.isEmpty) return;
    final restaurantId = rows.first['id']! as int;

    var added = 0;
    for (final (name, description, price, category, allergens) in _demoMenu) {
      final exists = await db.query(
        'dishes',
        columns: ['id'],
        where: 'restaurant_id = ? AND name = ?',
        whereArgs: [restaurantId, name],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;
      await db.insert('dishes', {
        'restaurant_id': restaurantId,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'photo_path': kSeedDishImages[name],
        'is_available': 1,
        'tags': jsonEncode(<String>[]),
        'allergens': jsonEncode(allergens),
      });
      added++;
    }
    if (added > 0) debugPrint('[MenuSeed] $added Module 2 demo dishes added');
  }
}

/// Number of dishes in Module 2's demo menu (for tests).
@visibleForTesting
int get menuDemoSize => _demoMenu.length;

/// Names of Module 2's demo dishes (for tests).
@visibleForTesting
Iterable<String> get menuDemoDishNames => _demoMenu.map((d) => d.$1);
