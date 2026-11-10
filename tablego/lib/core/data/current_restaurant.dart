import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../database/database_helper.dart';

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

/// `restaurant_profiles.id` of the logged-in restaurant account, or null
/// (logged out, client account, or no restaurant profile).
final currentRestaurantIdProvider = FutureProvider<int?>((ref) async {
  final user = ref.watch(authProvider.select((s) => s.user));
  if (user == null || user.userType != 'restaurant') return null;
  return restaurantIdForUser(await DatabaseHelper.instance.database, user.id);
});
