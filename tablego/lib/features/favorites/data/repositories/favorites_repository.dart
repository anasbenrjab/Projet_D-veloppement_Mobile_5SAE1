import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/favorites_exception.dart';
import '../models/dish_summary_model.dart';
import '../models/restaurant_summary_model.dart';

class FavoritesRepository {
  FavoritesRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;
  Future<Database> get _database => _db.database;

  // ── Guard ─────────────────────────────────────────────────────────────────

  /// Throws [FavoritesException] if [userId] is not a 'client'.
  ///
  /// Only client accounts can have favorites — restaurant accounts manage
  /// their own content but do not bookmark others'.
  Future<void> _assertClientUser(int userId) async {
    final db   = await _database;
    final rows = await db.query(
      'users',
      columns: ['user_type'],
      where: 'id = ? AND is_active = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const FavoritesException('Utilisateur introuvable');
    }
    if (rows.first['user_type'] != 'client') {
      throw const FavoritesException(
          'Seuls les comptes client peuvent avoir des favoris');
    }
  }

  // ── Favorite restaurants ──────────────────────────────────────────────────

  /// Returns all favorite restaurants for [userId], ordered by most recently
  /// added.  Mirrors the backend JOIN:
  /// rp.id, name, address, latitude, longitude, cuisine_type,
  /// photo_paths, description, opening_hours, fr.created_at AS favorited_at.
  Future<List<RestaurantSummaryModel>> getFavoriteRestaurants(
      int userId) async {
    await _assertClientUser(userId);
    final db   = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT rp.id, rp.name, rp.address, rp.latitude, rp.longitude,
             rp.cuisine_type, rp.photo_paths, rp.description,
             rp.opening_hours,
             fr.created_at AS favorited_at
        FROM favorite_restaurants fr
        JOIN restaurant_profiles rp ON rp.id = fr.restaurant_id
       WHERE fr.user_id = ?
       ORDER BY fr.created_at DESC
      ''',
      [userId],
    );
    return rows
        .map((r) => RestaurantSummaryModel.fromMap(
            Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Adds [restaurantId] to [userId]'s favorites.
  ///
  /// Uses [ConflictAlgorithm.ignore] — adding an existing favorite is a
  /// no-op, never an error.
  Future<void> addFavoriteRestaurant(int userId, int restaurantId) async {
    await _assertClientUser(userId);
    final db = await _database;
    await db.insert(
      'favorite_restaurants',
      {'user_id': userId, 'restaurant_id': restaurantId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes [restaurantId] from [userId]'s favorites.
  /// Removing a non-existent favorite is a no-op.
  Future<void> removeFavoriteRestaurant(int userId, int restaurantId) async {
    await _assertClientUser(userId);
    final db = await _database;
    await db.delete(
      'favorite_restaurants',
      where: 'user_id = ? AND restaurant_id = ?',
      whereArgs: [userId, restaurantId],
    );
  }

  // ── Favorite dishes ───────────────────────────────────────────────────────

  /// Returns all favorite dishes for [userId], ordered by most recently
  /// added.  Mirrors the backend JOIN:
  /// d.id, name, description, price, photo_path, tags,
  /// rp.id AS restaurant_id, rp.name AS restaurant_name,
  /// rp.address AS restaurant_address, rp.cuisine_type,
  /// fd.created_at AS favorited_at.
  Future<List<DishSummaryModel>> getFavoriteDishes(int userId) async {
    await _assertClientUser(userId);
    final db   = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT d.id, d.name, d.description, d.price, d.photo_path, d.tags,
             rp.id      AS restaurant_id,
             rp.name    AS restaurant_name,
             rp.address AS restaurant_address,
             rp.cuisine_type,
             fd.created_at AS favorited_at
        FROM favorite_dishes fd
        JOIN dishes d               ON d.id  = fd.dish_id
        JOIN restaurant_profiles rp ON rp.id = d.restaurant_id
       WHERE fd.user_id = ?
       ORDER BY fd.created_at DESC
      ''',
      [userId],
    );
    return rows
        .map((r) => DishSummaryModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Adds [dishId] to [userId]'s favorites.
  /// Uses [ConflictAlgorithm.ignore] — duplicate adds are silent no-ops.
  Future<void> addFavoriteDish(int userId, int dishId) async {
    await _assertClientUser(userId);
    final db = await _database;
    await db.insert(
      'favorite_dishes',
      {'user_id': userId, 'dish_id': dishId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes [dishId] from [userId]'s favorites.
  /// Removing a non-existent favorite is a no-op.
  Future<void> removeFavoriteDish(int userId, int dishId) async {
    await _assertClientUser(userId);
    final db = await _database;
    await db.delete(
      'favorite_dishes',
      where: 'user_id = ? AND dish_id = ?',
      whereArgs: [userId, dishId],
    );
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (_) => FavoritesRepository(),
);
