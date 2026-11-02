// Dev seed — reproduces the same test data as tablego-backend/seeds/seed.js.
// Runs only in kDebugMode. Idempotent: checked by client email before inserting.
//
// IMPORTANT: [DevSeed.run] is called from [DatabaseHelper._onCreate], which
// sqflite already wraps in a transaction. It must therefore NOT call anything
// that opens another transaction (e.g. `db.transaction(...)` or
// `AuthRepository.register`) — nesting a transaction freezes the app. Rows are
// inserted directly on the passed [Database] handle instead.
//
// Test accounts (all passwords: password123)
// Security question : "Nom de votre animal de compagnie ?"
// Security answer   : "médor"
//
//   client@test.com       — client   — Alice Dupont (halal, végétarien;
//                                       allergie : arachides)
//   resto@test.com        — restaurant — Le Gourmet Parisien (French)
//   burgerking@test.com   — restaurant — Burger Palace (American)
//   sushi@test.com        — restaurant — Tokyo Sushi Bar (Japanese)
//
// Recommendation demo clients (see [DevSeed.applyRecommendationDemo]):
//   karim@test.com        — Karim Benali  (halal)
//   sophie@test.com       — Sophie Martin (végétarien)
//   yuki@test.com         — Yuki Tanaka   (allergie : lactose)
//   lucas@test.com        — Lucas Petit   (aucune contrainte)

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../utils/password_hasher.dart';

// ── Opening hours ─────────────────────────────────────────────────────────────

const _hoursGourmet = {
  'mon': {'open': '11:00', 'close': '23:00'},
  'tue': {'open': '11:00', 'close': '23:00'},
  'wed': {'open': '11:00', 'close': '23:00'},
  'thu': {'open': '11:00', 'close': '23:00'},
  'fri': {'open': '11:00', 'close': '00:00'},
  'sat': {'open': '10:00', 'close': '00:00'},
  'sun': {'open': '10:00', 'close': '22:00'},
};
const _hoursBurger = {
  'mon': {'open': '10:00', 'close': '23:00'},
  'tue': {'open': '10:00', 'close': '23:00'},
  'wed': {'open': '10:00', 'close': '23:00'},
  'thu': {'open': '10:00', 'close': '23:00'},
  'fri': {'open': '10:00', 'close': '01:00'},
  'sat': {'open': '10:00', 'close': '01:00'},
  'sun': {'open': '11:00', 'close': '22:00'},
};
const _hoursSushi = {
  'mon': {'open': '12:00', 'close': '22:00'},
  'tue': {'open': '12:00', 'close': '22:00'},
  'wed': {'open': '12:00', 'close': '22:00'},
  'thu': {'open': '12:00', 'close': '22:00'},
  'fri': {'open': '12:00', 'close': '23:00'},
  'sat': {'open': '11:00', 'close': '23:00'},
  'sun': {'open': '11:00', 'close': '21:00'},
};

const _seedQuestion = 'Nom de votre animal de compagnie ?';
const _seedAnswer   = 'médor';
const _seedPassword = 'password123';

// ── Seed photos ───────────────────────────────────────────────────────────────
// Bundled assets (declared in pubspec.yaml; sources and licenses in
// assets/images/CREDITS.md).  Applied by [DevSeed.applySeedPhotos].

const _seedImages = 'assets/images/seed';

/// Client avatar, keyed by account email.
const _clientPhotos = {
  'client@test.com': '$_seedImages/avatars/alice.jpg',
};

/// Restaurant photos (first = cover), keyed by account email.
const _restaurantPhotos = {
  'resto@test.com': [
    '$_seedImages/restaurants/gourmet_1.jpg',
    '$_seedImages/restaurants/gourmet_2.jpg',
    '$_seedImages/restaurants/gourmet_3.jpg',
  ],
  'burgerking@test.com': [
    '$_seedImages/restaurants/burger_1.jpg',
    '$_seedImages/restaurants/burger_2.jpg',
    '$_seedImages/restaurants/burger_3.jpg',
  ],
  'sushi@test.com': [
    '$_seedImages/restaurants/sushi_1.jpg',
    '$_seedImages/restaurants/sushi_2.jpg',
    '$_seedImages/restaurants/sushi_3.jpg',
  ],
};

/// Dish photos, keyed by the owning restaurant's email, then dish name.
const _dishPhotos = {
  'resto@test.com': {
    "Soupe à l'oignon": '$_seedImages/dishes/soupe_oignon.jpg',
    'Poulet rôti':      '$_seedImages/dishes/poulet_roti.jpg',
  },
  'burgerking@test.com': {
    'Smash Burger Classic':  '$_seedImages/dishes/smash_burger.jpg',
    'Crispy Chicken Burger': '$_seedImages/dishes/crispy_chicken_burger.jpg',
  },
  'sushi@test.com': {
    'Salmon Sashimi (8 pcs)': '$_seedImages/dishes/salmon_sashimi.jpg',
  },
};

// ── Recommendation demo ───────────────────────────────────────────────────────
// A richer menu (diet tags and allergens in the normalised French format of
// docs/integration-recommandations.md) and extra clients with dated orders
// and favorites, so the recommender gives visibly different results per
// client.  Applied by [DevSeed.applyRecommendationDemo].

class _SeedDish {
  const _SeedDish(this.restaurant, this.name, this.description, this.price,
      this.tags, this.allergens);

  /// Owning restaurant's account email.
  final String restaurant;
  final String name;
  final String description;
  final double price;
  final List<String> tags;
  final List<String> allergens;
}

const _menu = [
  // Le Gourmet Parisien (French)
  _SeedDish('resto@test.com', "Soupe à l'oignon",
      'Classic French onion soup with gruyère crouton', 12.50,
      ['vegetarien'], ['gluten', 'lactose']),
  _SeedDish('resto@test.com', 'Poulet rôti',
      'Oven-roasted chicken with seasonal vegetables', 18.90,
      ['halal'], []),
  _SeedDish('resto@test.com', 'Ratatouille provençale',
      "Légumes du soleil mijotés à l'huile d'olive", 13.00,
      ['vegetarien', 'vegan', 'halal'], []),
  _SeedDish('resto@test.com', 'Croque-monsieur',
      'Jambon, béchamel et emmental gratinés', 9.50,
      [], ['gluten', 'lactose']),
  _SeedDish('resto@test.com', 'Tarte aux pommes',
      'Pâte sablée et pommes caramélisées', 6.50,
      ['vegetarien', 'halal'], ['gluten', 'lactose', 'oeufs']),
  // Burger Palace (American)
  _SeedDish('burgerking@test.com', 'Smash Burger Classic',
      'Double smash patty, cheddar, pickles, house sauce', 14.00,
      [], ['gluten', 'lactose', 'oeufs']),
  _SeedDish('burgerking@test.com', 'Crispy Chicken Burger',
      'Crispy fried chicken, coleslaw, sriracha mayo', 13.50,
      ['halal'], ['gluten', 'oeufs']),
  _SeedDish('burgerking@test.com', 'Veggie Burger',
      'Galette de pois chiches, sauce maison', 12.50,
      ['vegetarien', 'halal'], ['gluten', 'soja']),
  _SeedDish('burgerking@test.com', 'Frites maison',
      'Pommes de terre fraîches, sel de Guérande', 4.50,
      ['vegan', 'vegetarien', 'halal'], []),
  _SeedDish('burgerking@test.com', 'Cookie beurre de cacahuète',
      'Cookie moelleux au beurre de cacahuète', 3.90,
      ['vegetarien', 'halal'], ['gluten', 'lactose', 'oeufs', 'arachides']),
  // Tokyo Sushi Bar (Japanese)
  _SeedDish('sushi@test.com', 'Salmon Sashimi (8 pcs)',
      'Premium Atlantic salmon, fresh wasabi', 16.00,
      ['pescetarien'], ['poisson']),
  _SeedDish('sushi@test.com', 'Maki avocat-concombre',
      '6 makis avocat et concombre', 7.50,
      ['vegan', 'vegetarien'], ['soja']),
  _SeedDish('sushi@test.com', 'Ramen au poulet',
      'Bouillon de poulet, nouilles, œuf mollet', 14.50,
      ['halal'], ['gluten', 'soja', 'oeufs']),
  _SeedDish('sushi@test.com', 'Edamame',
      'Fèves de soja au sel', 5.00,
      ['vegan', 'vegetarien'], ['soja']),
];

class _DemoClient {
  const _DemoClient({
    required this.email,
    required this.fullName,
    this.diets = const [],
    this.allergies = const [],
    this.favoriteRestaurants = const [],
    this.favoriteDishes = const [],
    this.orders = const [],
  });

  final String email;
  final String fullName;

  /// Stored with the profile screen's values (normalised on read).
  final List<String> diets;
  final List<String> allergies;
  final List<String> favoriteRestaurants; // restaurant account emails
  final List<String> favoriteDishes;      // dish names
  final List<(String, int)> orders;       // (dish name, days ago)
}

const _demoClients = [
  _DemoClient(
    email: 'karim@test.com',
    fullName: 'Karim Benali',
    diets: ['halal'],
    favoriteRestaurants: ['burgerking@test.com'],
    favoriteDishes: ['Crispy Chicken Burger'],
    orders: [
      ('Crispy Chicken Burger', 2), ('Crispy Chicken Burger', 9),
      ('Crispy Chicken Burger', 20), ('Frites maison', 2),
      ('Frites maison', 9), ('Poulet rôti', 5), ('Poulet rôti', 30),
      ('Ramen au poulet', 12),
    ],
  ),
  _DemoClient(
    email: 'sophie@test.com',
    fullName: 'Sophie Martin',
    diets: ['vegetarian'],
    favoriteRestaurants: ['resto@test.com'],
    favoriteDishes: ['Ratatouille provençale'],
    orders: [
      ('Ratatouille provençale', 1), ('Ratatouille provençale', 15),
      ('Tarte aux pommes', 1), ('Maki avocat-concombre', 7),
      ('Maki avocat-concombre', 21), ('Edamame', 7),
      ('Veggie Burger', 25), ('Frites maison', 25),
    ],
  ),
  _DemoClient(
    email: 'yuki@test.com',
    fullName: 'Yuki Tanaka',
    allergies: ['dairy'],
    favoriteRestaurants: ['sushi@test.com'],
    favoriteDishes: ['Salmon Sashimi (8 pcs)'],
    orders: [
      ('Salmon Sashimi (8 pcs)', 3), ('Salmon Sashimi (8 pcs)', 10),
      ('Salmon Sashimi (8 pcs)', 24), ('Ramen au poulet', 3),
      ('Ramen au poulet', 17), ('Edamame', 10),
      ('Maki avocat-concombre', 24),
    ],
  ),
  _DemoClient(
    email: 'lucas@test.com',
    fullName: 'Lucas Petit',
    favoriteRestaurants: ['burgerking@test.com'],
    favoriteDishes: ['Smash Burger Classic'],
    orders: [
      ('Smash Burger Classic', 1), ('Smash Burger Classic', 8),
      ('Smash Burger Classic', 16), ('Frites maison', 1),
      ('Frites maison', 8), ('Croque-monsieur', 4),
      ('Croque-monsieur', 19), ('Cookie beurre de cacahuète', 8),
    ],
  ),
];

/// Email of every account the seed creates (base accounts + demo clients).
@visibleForTesting
Iterable<String> get seedAccountEmails => [
      'client@test.com',
      'resto@test.com',
      'burgerking@test.com',
      'sushi@test.com',
      for (final c in _demoClients) c.email,
    ];

/// Number of dishes on the seed menu.
@visibleForTesting
int get seedMenuSize => _menu.length;

/// Every asset path the seed references — exposed so tests can check that
/// each one exists and is bundled.
@visibleForTesting
Iterable<String> get seedPhotoAssets => [
      ..._clientPhotos.values,
      for (final paths in _restaurantPhotos.values) ...paths,
      for (final dishes in _dishPhotos.values) ...dishes.values,
    ];

// ── Seed entry point ──────────────────────────────────────────────────────────

class DevSeed {
  DevSeed._();

  static Future<void> run(Database db) async {
    if (!kDebugMode) return;

    final sw = Stopwatch()..start();
    debugPrint('[DevSeed] start');

    // Idempotency: skip if client@test.com already exists.
    final check = await db.query('users',
        columns: ['id'], where: 'email = ?',
        whereArgs: ['client@test.com'], limit: 1);
    if (check.isNotEmpty) {
      debugPrint('[DevSeed] already seeded — skipping '
          '(${sw.elapsedMilliseconds}ms)');
      return;
    }

    debugPrint('[DevSeed] seeding test accounts...');

    final now = DateTime.now().toUtc().toIso8601String();

    // Hash once and reuse for every seed account. These are debug-only
    // credentials, so a shared salt is acceptable and keeps startup fast.
    final salt = PasswordHasher.generateSalt();
    debugPrint('[DevSeed] hash password: start (${sw.elapsedMilliseconds}ms)');
    final passHash = await PasswordHasher.hash(_seedPassword, salt);
    debugPrint('[DevSeed] hash password: end (${sw.elapsedMilliseconds}ms)');
    debugPrint('[DevSeed] hash answer: start (${sw.elapsedMilliseconds}ms)');
    final answerHash = await PasswordHasher.hash(
        _seedAnswer.trim().toLowerCase(), salt);
    debugPrint('[DevSeed] hash answer: end (${sw.elapsedMilliseconds}ms)');

    // Inserts a user row plus its profile row directly on [db].
    // Deliberately avoids AuthRepository.register (which opens a transaction).
    Future<int> insertUser({
      required String email,
      required String userType,
      String? restaurantName,
    }) async {
      final userId = await db.insert('users', {
        'email':               email,
        'password_hash':       passHash,
        'salt':                salt,
        'password_iterations': PasswordHasher.kPasswordIterations,
        'user_type':           userType,
        'is_active':           1,
        'reset_question':      _seedQuestion,
        'reset_answer_hash':   answerHash,
        'reset_answer_salt':   salt,
        'created_at':          now,
        'updated_at':          now,
      });

      if (userType == 'client') {
        await db.insert('client_profiles',
            {'user_id': userId, 'created_at': now, 'updated_at': now});
      } else {
        await db.insert('restaurant_profiles', {
          'user_id':    userId,
          'name':       restaurantName!,
          'created_at': now,
          'updated_at': now,
        });
      }
      return userId;
    }

    final clientId      = await insertUser(
        email: 'client@test.com', userType: 'client');
    final gourmetUserId = await insertUser(
        email: 'resto@test.com', userType: 'restaurant',
        restaurantName: 'Le Gourmet Parisien');
    final burgerUserId  = await insertUser(
        email: 'burgerking@test.com', userType: 'restaurant',
        restaurantName: 'Burger Palace');
    final sushiUserId   = await insertUser(
        email: 'sushi@test.com', userType: 'restaurant',
        restaurantName: 'Tokyo Sushi Bar');

    // ── Update client profile ─────────────────────────────────────────────────
    await db.update('client_profiles', {
      'full_name': 'Alice Dupont',
      'phone':     '+33 6 12 34 56 78',
      'dietary_preferences': jsonEncode(['halal', 'vegetarian']),
      'allergies':           jsonEncode(['peanuts']),
      'updated_at': now,
    }, where: 'user_id = ?', whereArgs: [clientId]);

    // Helper: resolve restaurant_profiles.id from users.id
    Future<int> rpId(int uid) async {
      final r = await db.query('restaurant_profiles',
          columns: ['id'], where: 'user_id = ?', whereArgs: [uid], limit: 1);
      return r.first['id'] as int;
    }

    final gourmetRpId = await rpId(gourmetUserId);
    final burgerRpId  = await rpId(burgerUserId);
    final sushiRpId   = await rpId(sushiUserId);

    // ── Update restaurant profiles ────────────────────────────────────────────
    await db.update('restaurant_profiles', {
      'address': '12 Rue de Rivoli, Paris 75001',
      'latitude': 48.85600, 'longitude': 2.34200,
      'opening_hours': jsonEncode(_hoursGourmet),
      'cuisine_type': 'French',
      'description': 'Authentic Parisian cuisine in the heart of Paris.',
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [gourmetRpId]);

    await db.update('restaurant_profiles', {
      'address': '45 Avenue des Champs-Élysées, Paris 75008',
      'latitude': 48.87320, 'longitude': 2.29540,
      'opening_hours': jsonEncode(_hoursBurger),
      'cuisine_type': 'American',
      'description': 'Best smash burgers in Paris.',
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [burgerRpId]);

    await db.update('restaurant_profiles', {
      'address': '8 Rue Saint-Anne, Paris 75001',
      'latitude': 48.86500, 'longitude': 2.33800,
      'opening_hours': jsonEncode(_hoursSushi),
      'cuisine_type': 'Japanese',
      'description': 'Fresh sushi and ramen from Tokyo recipes.',
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [sushiRpId]);

    // ── Dishes ────────────────────────────────────────────────────────────────
    final d1 = await db.insert('dishes', {
      'restaurant_id': gourmetRpId, 'name': "Soupe à l'oignon",
      'description': 'Classic French onion soup with gruyère crouton',
      'price': 12.50, 'is_available': 1, 'tags': jsonEncode(['vegetarian'])});
    final d2 = await db.insert('dishes', {
      'restaurant_id': gourmetRpId, 'name': 'Poulet rôti',
      'description': 'Oven-roasted chicken with seasonal vegetables',
      'price': 18.90, 'is_available': 1, 'tags': jsonEncode(['halal'])});
    final d3 = await db.insert('dishes', {
      'restaurant_id': burgerRpId, 'name': 'Smash Burger Classic',
      'description': 'Double smash patty, cheddar, pickles, house sauce',
      'price': 14.00, 'is_available': 1, 'tags': jsonEncode(<String>[])});
    final d4 = await db.insert('dishes', {
      'restaurant_id': burgerRpId, 'name': 'Crispy Chicken Burger',
      'description': 'Crispy fried chicken, coleslaw, sriracha mayo',
      'price': 13.50, 'is_available': 1, 'tags': jsonEncode(['halal'])});
    final d5 = await db.insert('dishes', {
      'restaurant_id': sushiRpId, 'name': 'Salmon Sashimi (8 pcs)',
      'description': 'Premium Atlantic salmon, fresh wasabi',
      'price': 16.00, 'is_available': 1, 'tags': jsonEncode(<String>[])});

    // ── Favorites ─────────────────────────────────────────────────────────────
    await db.insert('favorite_restaurants',
        {'user_id': clientId, 'restaurant_id': gourmetRpId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('favorite_restaurants',
        {'user_id': clientId, 'restaurant_id': sushiRpId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('favorite_dishes',
        {'user_id': clientId, 'dish_id': d4},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('favorite_dishes',
        {'user_id': clientId, 'dish_id': d5},
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // ── Order history (same 4 rows as seed.js) ────────────────────────────────
    for (final row in [
      {'user_id': clientId, 'restaurant_id': gourmetRpId, 'dish_id': d1},
      {'user_id': clientId, 'restaurant_id': gourmetRpId, 'dish_id': d2},
      {'user_id': clientId, 'restaurant_id': sushiRpId,   'dish_id': d5},
      {'user_id': clientId, 'restaurant_id': burgerRpId,  'dish_id': d3},
    ]) {
      await db.insert('order_history', row);
    }

    await applyRecommendationDemo(db);
    await applySeedPhotos(db);

    debugPrint('[DevSeed] end — base accounts + recommendation demo '
        '(${sw.elapsedMilliseconds}ms)');
  }

  /// Adds the recommendation demo — full menu with diet tags and allergens,
  /// extra clients with orders and favorites — to a seeded database.
  ///
  /// Called at the end of [run] for new databases, and by `DatabaseHelper`
  /// on every open so databases seeded before the demo existed get it too.
  /// Idempotent: missing dishes are inserted, seed dishes whose `allergens`
  /// is still NULL get their tags and allergens, and a demo client (with
  /// their orders and favorites) is only created if their email is absent.
  /// Debug builds only; opens no transaction, so it is safe in `onCreate`.
  static Future<void> applyRecommendationDemo(DatabaseExecutor db) async {
    if (!kDebugMode) return;

    // Seed restaurants: email → restaurant_profiles.id.  A database without
    // them was not seeded: leave it alone.
    final restaurantIds = <String, int>{};
    for (final email in {for (final d in _menu) d.restaurant}) {
      final rows = await db.rawQuery('''
        SELECT rp.id FROM restaurant_profiles rp
          JOIN users u ON u.id = rp.user_id
         WHERE u.email = ?
      ''', [email]);
      if (rows.isEmpty) return;
      restaurantIds[email] = rows.first['id']! as int;
    }

    // Menu.
    var dishChanges = 0;
    final dishIds = <String, int>{};
    for (final d in _menu) {
      final restaurantId = restaurantIds[d.restaurant]!;
      final rows = await db.query('dishes',
          columns: ['id', 'allergens'],
          where: 'restaurant_id = ? AND name = ?',
          whereArgs: [restaurantId, d.name],
          limit: 1);
      if (rows.isEmpty) {
        dishIds[d.name] = await db.insert('dishes', {
          'restaurant_id': restaurantId,
          'name':          d.name,
          'description':   d.description,
          'price':         d.price,
          'is_available':  1,
          'tags':          jsonEncode(d.tags),
          'allergens':     jsonEncode(d.allergens),
        });
        dishChanges++;
      } else {
        dishIds[d.name] = rows.first['id']! as int;
        if (rows.first['allergens'] == null) {
          dishChanges += await db.update(
            'dishes',
            {'tags': jsonEncode(d.tags), 'allergens': jsonEncode(d.allergens)},
            where: 'id = ?',
            whereArgs: [dishIds[d.name]],
          );
        }
      }
    }

    // Demo clients.
    final missing = <_DemoClient>[];
    for (final c in _demoClients) {
      final rows = await db.query('users',
          columns: ['id'], where: 'email = ?', whereArgs: [c.email], limit: 1);
      if (rows.isEmpty) missing.add(c);
    }
    if (missing.isNotEmpty) {
      final salt = PasswordHasher.generateSalt();
      final passHash = await PasswordHasher.hash(_seedPassword, salt);
      final answerHash =
          await PasswordHasher.hash(_seedAnswer.trim().toLowerCase(), salt);
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();

      for (final c in missing) {
        final userId = await db.insert('users', {
          'email':               c.email,
          'password_hash':       passHash,
          'salt':                salt,
          'password_iterations': PasswordHasher.kPasswordIterations,
          'user_type':           'client',
          'is_active':           1,
          'reset_question':      _seedQuestion,
          'reset_answer_hash':   answerHash,
          'reset_answer_salt':   salt,
          'created_at':          nowIso,
          'updated_at':          nowIso,
        });
        await db.insert('client_profiles', {
          'user_id':             userId,
          'full_name':           c.fullName,
          'dietary_preferences': jsonEncode(c.diets),
          'allergies':           jsonEncode(c.allergies),
          'created_at':          nowIso,
          'updated_at':          nowIso,
        });
        for (final email in c.favoriteRestaurants) {
          await db.insert('favorite_restaurants',
              {'user_id': userId, 'restaurant_id': restaurantIds[email]},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        for (final name in c.favoriteDishes) {
          await db.insert('favorite_dishes',
              {'user_id': userId, 'dish_id': dishIds[name]},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        for (final (name, daysAgo) in c.orders) {
          final dish = _menu.firstWhere((d) => d.name == name);
          await db.insert('order_history', {
            'user_id':       userId,
            'restaurant_id': restaurantIds[dish.restaurant],
            'dish_id':       dishIds[name],
            'ordered_at': now
                .subtract(Duration(days: daysAgo))
                .toIso8601String(),
          });
        }
      }
    }

    if (dishChanges > 0 || missing.isNotEmpty) {
      debugPrint('[DevSeed] recommendation demo: $dishChanges dishes set, '
          '${missing.length} demo clients added');
    }
  }

  /// Sets the bundled seed photos on seed rows that have no photo yet.
  ///
  /// Called at the end of [run] for new databases, and by `DatabaseHelper`
  /// on every open so databases seeded before the photos existed get them
  /// too.  Idempotent, and never overwrites a photo a user has set.  Like
  /// [run], it does nothing outside debug builds and opens no transaction,
  /// so it is safe inside `onCreate`.
  static Future<void> applySeedPhotos(DatabaseExecutor db) async {
    if (!kDebugMode) return;
    var updated = 0;

    for (final e in _clientPhotos.entries) {
      updated += await db.rawUpdate('''
        UPDATE client_profiles SET photo_path = ?
         WHERE (photo_path IS NULL OR photo_path = '')
           AND user_id = (SELECT id FROM users WHERE email = ?)
      ''', [e.value, e.key]);
    }

    for (final e in _restaurantPhotos.entries) {
      updated += await db.rawUpdate('''
        UPDATE restaurant_profiles SET photo_paths = ?
         WHERE (photo_paths IS NULL OR photo_paths IN ('', '[]'))
           AND user_id = (SELECT id FROM users WHERE email = ?)
      ''', [jsonEncode(e.value), e.key]);
    }

    for (final restaurant in _dishPhotos.entries) {
      for (final dish in restaurant.value.entries) {
        updated += await db.rawUpdate('''
          UPDATE dishes SET photo_path = ?
           WHERE (photo_path IS NULL OR photo_path = '')
             AND name = ?
             AND restaurant_id IN (
                   SELECT rp.id FROM restaurant_profiles rp
                     JOIN users u ON u.id = rp.user_id
                    WHERE u.email = ?)
        ''', [dish.value, dish.key, restaurant.key]);
      }
    }

    if (updated > 0) debugPrint('[DevSeed] seed photos set on $updated rows');
  }
}
