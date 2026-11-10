import 'package:sqflite/sqflite.dart';

/// Returns the `restaurant_profiles.id` owned by the restaurant user
/// [userId], or null when that user has no restaurant profile.
///
/// Modules that work "as the logged-in restaurant" (menu management,
/// incoming orders, events, reservations) use this to turn the session's
/// `users.id` (from `authProvider`) into the restaurant id their tables
/// reference.
Future<int?> restaurantIdForUser(DatabaseExecutor db, int userId) async {
  final rows = await db.query(
    'restaurant_profiles',
    columns: ['id'],
    where: 'user_id = ?',
    whereArgs: [userId],
    limit: 1,
  );
  return rows.isEmpty ? null : rows.first['id']! as int;
}

/// Returns the display name of restaurant [restaurantId], or null.
Future<String?> restaurantName(DatabaseExecutor db, int restaurantId) async {
  final rows = await db.query(
    'restaurant_profiles',
    columns: ['name'],
    where: 'id = ?',
    whereArgs: [restaurantId],
    limit: 1,
  );
  return rows.isEmpty ? null : rows.first['name'] as String?;
}
