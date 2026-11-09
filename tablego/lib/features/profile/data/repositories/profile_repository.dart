import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/utils/photo_files.dart';
import '../../../../core/utils/photo_ref.dart';
import '../../domain/profile_exception.dart';
import '../models/client_profile_model.dart';
import '../models/restaurant_profile_model.dart';
import '../uploaded_photos.dart';

// ── Validation constants ──────────────────────────────────────────────────────

const _kMaxFullNameLength = 120;
const _kMaxPhoneLength    = 30;
const _kMaxDescLength     = 1000;

/// Minimal phone pattern: optional leading +, then digits/spaces/dashes/
/// parens, at least 7 characters total.
final _kPhoneRegex = RegExp(r'^\+?[\d\s\-().]{7,}$');

// ── Repository ────────────────────────────────────────────────────────────────

class ProfileRepository {
  ProfileRepository({DatabaseHelper? dbHelper, GeocodingService? geocoder})
      : _db = dbHelper ?? DatabaseHelper.instance,
        _geocoder = geocoder ?? GeocodingService();

  final DatabaseHelper _db;
  final GeocodingService _geocoder;

  Future<Database> get _database => _db.database;

  // ── Client profile ────────────────────────────────────────────────────────

  /// Returns the combined user + client_profiles row for [userId].
  ///
  /// Throws [ProfileException] if the user does not exist or is not a client.
  Future<ClientProfileModel> getClientProfile(int userId) async {
    final db   = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT u.id, u.email, u.user_type, u.created_at,
             cp.full_name, cp.phone, cp.photo_path,
             cp.dietary_preferences, cp.allergies
        FROM users u
        LEFT JOIN client_profiles cp ON cp.user_id = u.id
       WHERE u.id = ? AND u.is_active = 1
      ''',
      [userId],
    );
    if (rows.isEmpty) throw const ProfileException('Utilisateur introuvable');
    final row = Map<String, dynamic>.from(rows.first);
    if (row['user_type'] != 'client') {
      throw const ProfileException('Ce compte n\'est pas un compte client');
    }
    // Web keeps the bytes in `profile_photos`; surface them as a data URI so
    // the UI can render them with Image.memory.
    final refs = await _webPhotoRefs(userId, 'client');
    if (refs.isNotEmpty) row['photo_path'] = refs.first;
    return ClientProfileModel.fromMap(row);
  }

  /// Updates the client profile for [userId].
  ///
  /// - Throws [ProfileException] if the user is not a 'client'.
  /// - Validates [fullName] length, [phone] length and format.
  /// - Always sets [updated_at].
  Future<void> updateClientProfile({
    required int userId,
    String? fullName,
    String? phone,
    List<String>? dietaryPreferences,
    List<String>? allergies,
  }) async {
    await _assertUserType(userId, 'client');
    _validateClientFields(fullName: fullName, phone: phone);

    final db  = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'client_profiles',
      {
        'full_name':            ?fullName,
        'phone':                ?phone,
        if (dietaryPreferences != null)
          'dietary_preferences': jsonEncode(dietaryPreferences),
        if (allergies != null) 'allergies': jsonEncode(allergies),
        'updated_at': now,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ── Restaurant profile ────────────────────────────────────────────────────

  /// Returns the combined user + restaurant_profiles row for [userId].
  ///
  /// Throws [ProfileException] if the user does not exist or is not a
  /// restaurant.
  Future<RestaurantProfileModel> getRestaurantProfile(int userId) async {
    final db   = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT u.id, u.email, u.user_type, u.created_at,
             rp.name, rp.address, rp.latitude, rp.longitude,
             rp.opening_hours, rp.cuisine_type, rp.photo_paths,
             rp.description
        FROM users u
        LEFT JOIN restaurant_profiles rp ON rp.user_id = u.id
       WHERE u.id = ? AND u.is_active = 1
      ''',
      [userId],
    );
    if (rows.isEmpty) throw const ProfileException('Utilisateur introuvable');
    final row = Map<String, dynamic>.from(rows.first);
    if (row['user_type'] != 'restaurant') {
      throw const ProfileException(
          'Ce compte n\'est pas un compte restaurant');
    }
    // Web keeps uploaded bytes in `profile_photos`; surface them as data URIs
    // after the stored references (e.g. bundled seed photos), the same order
    // as mobile, which appends new uploads to `photo_paths`.
    final refs = await _webPhotoRefs(userId, 'restaurant');
    if (refs.isNotEmpty) {
      row['photo_paths'] = jsonEncode([
        ...RestaurantProfileModel.decodeList(row['photo_paths']),
        ...refs,
      ]);
    }
    return RestaurantProfileModel.fromMap(row);
  }

  /// Updates the restaurant profile for [userId].
  ///
  /// - Throws [ProfileException] if the user is not a 'restaurant'.
  /// - Throws [ProfileException] if [name] would become empty.
  /// - Validates [description] length.
  /// - Always sets [updated_at].
  /// - When [address] changes and no coordinates are passed, the old
  ///   coordinates are cleared (they belong to the old address).
  ///
  /// Never calls the network.  Returns `true` when the stored address should
  /// be geocoded with [geocodeRestaurantAddress]: it changed, or it has no
  /// coordinates yet (e.g. an earlier geocoding attempt failed).
  Future<bool> updateRestaurantProfile({
    required int userId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? openingHours,
    String? cuisineType,
    String? description,
  }) async {
    await _assertUserType(userId, 'restaurant');
    _validateRestaurantFields(name: name, description: description);

    final db  = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    final current = await db.query(
      'restaurant_profiles',
      columns: ['address', 'latitude', 'longitude'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    final oldAddress = _normalizeAddress(
        current.isEmpty ? null : current.first['address'] as String?);
    final newAddress =
        address == null ? oldAddress : _normalizeAddress(address);
    final addressChanged = newAddress != oldAddress;
    final coordsGiven = latitude != null && longitude != null;
    final clearCoords = addressChanged && !coordsGiven;
    final hadCoords = current.isNotEmpty &&
        current.first['latitude'] != null &&
        current.first['longitude'] != null;

    await db.update(
      'restaurant_profiles',
      {
        'name':         ?name,
        'address':      ?address,
        'latitude':     ?latitude,
        'longitude':    ?longitude,
        if (clearCoords) ...{'latitude': null, 'longitude': null},
        if (openingHours != null)
          'opening_hours': jsonEncode(openingHours),
        'cuisine_type': ?cuisineType,
        'description':  ?description,
        'updated_at': now,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (newAddress.isEmpty || coordsGiven) return false;
    return addressChanged || !hadCoords;
  }

  /// Geocodes the stored address of [userId]'s restaurant with
  /// [GeocodingService] and stores the coordinates.
  ///
  /// Returns `true` if coordinates were written.  Returns `false` — never
  /// throws for a network problem — when there is no address, the service
  /// finds nothing or is unreachable, or the address changed meanwhile (the
  /// coordinates are only written for the address that was looked up).
  Future<bool> geocodeRestaurantAddress(int userId) async {
    final db = await _database;
    final rows = await db.query(
      'restaurant_profiles',
      columns: ['address'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final address = rows.first['address'] as String?;
    if (_normalizeAddress(address).isEmpty) return false;

    final point = await _geocoder.geocode(address!);
    if (point == null) return false;

    final updated = await db.update(
      'restaurant_profiles',
      {'latitude': point.latitude, 'longitude': point.longitude},
      where: 'user_id = ? AND address = ?',
      whereArgs: [userId, address],
    );
    return updated > 0;
  }

  /// Trimmed, single-spaced, case-insensitive form used to compare addresses.
  static String _normalizeAddress(String? address) =>
      (address ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  // ── Photo management ──────────────────────────────────────────────────────

  /// Stores a picked photo and returns the reference written for the profile.
  ///
  /// **Mobile** — [sourcePath] is copied into `<documents>/profile_photos/`
  /// with a UUID filename, the new path replaces `client_profiles.photo_path`
  /// (single photo) or is appended to `restaurant_profiles.photo_paths`, and
  /// the previous client file is deleted after the DB write succeeds.
  ///
  /// **Web** — there is no file system, so [bytes] are inserted into the
  /// `profile_photos` table and returned as a `data:` URI; [sourcePath] is
  /// ignored.
  Future<String> saveProfilePhoto({
    required int       userId,
    required String    userType,
    required List<int> bytes,
    String?            mimeType,
    String?            sourcePath,
  }) async {
    if (kIsWeb) {
      return _saveWebPhoto(
        userId:   userId,
        userType: userType,
        bytes:    bytes,
        mimeType: mimeType ?? _guessImageMime(sourcePath),
      );
    }

    final source = sourcePath;
    if (source == null || source.isEmpty) {
      throw const ProfileException('Photo introuvable');
    }

    final destPath = await copyPhotoToDocuments(source);
    final db       = await _database;
    final now      = DateTime.now().toUtc().toIso8601String();

    if (userType == 'client') {
      final rows = await db.query(
        'client_profiles',
        columns: ['photo_path'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final oldPath =
          rows.isNotEmpty ? rows.first['photo_path'] as String? : null;

      await db.update(
        'client_profiles',
        {'photo_path': destPath, 'updated_at': now},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Delete the old file only after the DB write succeeds — and never a
      // bundled asset (e.g. the seed avatar), which is not ours to delete.
      if (oldPath != null && !isAssetPhoto(oldPath)) {
        await deleteStoredPhoto(oldPath);
      }
    } else {
      // Restaurant: append to the JSON photo_paths array.
      final rows = await db.query(
        'restaurant_profiles',
        columns: ['photo_paths'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final existing = RestaurantProfileModel.decodeList(
          rows.isNotEmpty ? rows.first['photo_paths'] : null);
      final updated = [...existing, destPath];

      await db.update(
        'restaurant_profiles',
        {
          'photo_paths': jsonEncode(updated),
          'updated_at':  now,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }

    return destPath;
  }

  // ── Web photo storage ─────────────────────────────────────────────────────

  /// Inserts [bytes] into `profile_photos` and returns the resulting data URI.
  ///
  /// A client has a single photo, so any previous row is replaced first —
  /// mirroring the "overwrite the path" behaviour on mobile.
  Future<String> _saveWebPhoto({
    required int       userId,
    required String    userType,
    required List<int> bytes,
    required String    mimeType,
  }) async {
    final db  = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    final blob = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    if (userType == 'client') {
      await db.delete(
        'profile_photos',
        where: 'user_id = ? AND user_type = ?',
        whereArgs: [userId, 'client'],
      );
    }

    final res = await db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next_position '
      'FROM profile_photos WHERE user_id = ? AND user_type = ?',
      [userId, userType],
    );
    final position = (res.first['next_position'] as int?) ?? 0;

    await db.insert('profile_photos', {
      'user_id':    userId,
      'user_type':  userType,
      'position':   position,
      'mime_type':  mimeType,
      'data':       blob,
      'created_at': now,
    });

    // Keep `updated_at` meaningful on the owning profile row.
    await db.update(
      userType == 'client' ? 'client_profiles' : 'restaurant_profiles',
      {'updated_at': now},
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return encodePhotoDataUri(mimeType, blob);
  }

  /// Reads the user's web uploads back as `data:` URIs, ordered by position.
  ///
  /// Empty on mobile, where uploads are file paths stored in the profile row
  /// and `profile_photos` is never written.
  Future<List<String>> _webPhotoRefs(int userId, String userType) async {
    final db = await _database;
    final refs = await UploadedPhotos.refsByUser(db, userType, [userId]);
    return refs[userId] ?? const [];
  }

  /// Best-effort MIME type from a file name/extension; defaults to JPEG, which
  /// is only cosmetic — the decoder sniffs the real format from the bytes.
  String _guessImageMime(String? pathOrName) {
    switch (p.extension(pathOrName ?? '').toLowerCase()) {
      case '.png':  return 'image/png';
      case '.gif':  return 'image/gif';
      case '.webp': return 'image/webp';
      case '.bmp':  return 'image/bmp';
      default:      return 'image/jpeg';
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Throws [ProfileException] if [userId]'s user_type ≠ [expected].
  Future<void> _assertUserType(int userId, String expected) async {
    final db   = await _database;
    final rows = await db.query(
      'users',
      columns: ['user_type'],
      where: 'id = ? AND is_active = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) throw const ProfileException('Utilisateur introuvable');
    final actual = rows.first['user_type'] as String;
    if (actual != expected) {
      throw ProfileException(
        expected == 'client'
            ? 'Seuls les comptes client peuvent modifier ce profil'
            : 'Seuls les comptes restaurant peuvent modifier ce profil',
      );
    }
  }

  void _validateClientFields({String? fullName, String? phone}) {
    if (fullName != null) {
      if (fullName.trim().isEmpty) {
        throw const ProfileException('Le nom ne peut pas être vide');
      }
      if (fullName.length > _kMaxFullNameLength) {
        throw ProfileException(
            'Le nom ne peut pas dépasser $_kMaxFullNameLength caractères');
      }
    }
    if (phone != null && phone.trim().isNotEmpty) {
      if (phone.length > _kMaxPhoneLength) {
        throw ProfileException(
            'Le téléphone ne peut pas dépasser $_kMaxPhoneLength caractères');
      }
      if (!_kPhoneRegex.hasMatch(phone.trim())) {
        throw const ProfileException('Format de téléphone invalide');
      }
    }
  }

  void _validateRestaurantFields({String? name, String? description}) {
    if (name != null && name.trim().isEmpty) {
      throw const ProfileException(
          'Le nom du restaurant ne peut pas être vide');
    }
    if (description != null && description.length > _kMaxDescLength) {
      throw ProfileException(
          'La description ne peut pas dépasser $_kMaxDescLength caractères');
    }
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(geocoder: ref.watch(geocodingServiceProvider)),
);
