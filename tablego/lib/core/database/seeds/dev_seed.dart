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
//   client@test.com       — client   — Alice Dupont
//   resto@test.com        — restaurant — Le Gourmet Parisien (French)
//   burgerking@test.com   — restaurant — Burger Palace (American)
//   sushi@test.com        — restaurant — Tokyo Sushi Bar (Japanese)

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

// ── Seed entry point ──────────────────────────────────────────────────────────

class DevSeed {
  DevSeed._();

  static Future<void> run(Database db) async {
    if (!kDebugMode) return;

    // Idempotency: skip if client@test.com already exists.
    final check = await db.query('users',
        columns: ['id'], where: 'email = ?',
        whereArgs: ['client@test.com'], limit: 1);
    if (check.isNotEmpty) {
      debugPrint('[DevSeed] already seeded — skipping');
      return;
    }

    debugPrint('[DevSeed] seeding test accounts...');

    final now = DateTime.now().toUtc().toIso8601String();

    // Hash once and reuse for every seed account. These are debug-only
    // credentials, so a shared salt is acceptable and keeps startup fast.
    final salt       = PasswordHasher.generateSalt();
    final passHash   = await PasswordHasher.hash(_seedPassword, salt);
    final answerHash = await PasswordHasher.hash(
        _seedAnswer.trim().toLowerCase(), salt);

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

    debugPrint('[DevSeed] done — 4 users, 5 dishes, 2 fav restaurants, '
        '2 fav dishes, 4 orders');
  }
}
