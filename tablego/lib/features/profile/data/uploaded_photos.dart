import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../core/utils/photo_ref.dart';
import 'models/restaurant_profile_model.dart';

/// Reads photos uploaded on web, which live as bytes in `profile_photos`
/// rather than as references in the profile rows.
///
/// Every query that shows profile photos goes through here, so the profile
/// screen and the restaurant cards (home, recommendations, favorites) see the
/// same list.  On mobile uploads are files referenced from the profile rows
/// and `profile_photos` stays empty, so these helpers add nothing there.
class UploadedPhotos {
  UploadedPhotos._();

  /// Stays well under SQLite's limit on bound variables per statement.
  static const _maxIdsPerQuery = 500;

  /// Returns each user's uploaded photos as `data:` URIs, ordered by
  /// position.  Users without uploads are absent from the map.
  static Future<Map<int, List<String>>> refsByUser(
    DatabaseExecutor db,
    String userType,
    Iterable<int> userIds,
  ) async {
    final ids = userIds.toSet().toList();
    final refs = <int, List<String>>{};

    for (var start = 0; start < ids.length; start += _maxIdsPerQuery) {
      final chunk = ids.sublist(
          start, (start + _maxIdsPerQuery).clamp(0, ids.length));
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await db.rawQuery(
        'SELECT user_id, mime_type, data FROM profile_photos '
        'WHERE user_type = ? AND user_id IN ($marks) '
        'ORDER BY user_id, position ASC, id ASC',
        [userType, ...chunk],
      );
      for (final row in rows) {
        final mime = (row['mime_type'] as String?) ?? 'image/jpeg';
        final data = row['data'];
        final bytes = data is Uint8List
            ? data
            : Uint8List.fromList((data! as List).cast<int>());
        refs
            .putIfAbsent(row['user_id']! as int, () => [])
            .add(encodePhotoDataUri(mime, bytes));
      }
    }
    return refs;
  }

  /// Returns copies of restaurant [rows] whose `photo_paths` also list the
  /// restaurant's uploaded photos, after the stored references — the order
  /// mobile uses when it appends an upload.
  ///
  /// Each row must include the restaurant's `user_id`.
  static Future<List<Map<String, dynamic>>> withRestaurantUploads(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows,
  ) async {
    final uploads = await refsByUser(
        db, 'restaurant', rows.map((r) => r['user_id']! as int));

    return rows.map((r) {
      final row = Map<String, dynamic>.from(r);
      final extra = uploads[row['user_id']];
      if (extra != null) {
        row['photo_paths'] = jsonEncode([
          ...RestaurantProfileModel.decodeList(row['photo_paths']),
          ...extra,
        ]);
      }
      return row;
    }).toList();
  }
}
