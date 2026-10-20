import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/photo_files.dart';
import '../../../../core/utils/photo_ref.dart';
import '../../domain/profile_exception.dart';
import '../models/client_profile_model.dart';
import '../models/restaurant_profile_model.dart';

// ── Validation constants ──────────────────────────────────────────────────────

const _kMaxFullNameLength = 120;
const _kMaxPhoneLength    = 30;
const _kMaxDescLength     = 1000;

/// Minimal phone pattern: optional leading +, then digits/spaces/dashes/
/// parens, at least 7 characters total.
final _kPhoneRegex = RegExp(r'^\+?[\d\s\-().]{7,}$');

// ── Repository ────────────────────────────────────────────────────────────────

class ProfileRepository {
  ProfileRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

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
    // Web keeps the bytes in `profile_photos`; surface them as data URIs.
    final refs = await _webPhotoRefs(userId, 'restaurant');
    if (refs.isNotEmpty) row['photo_paths'] = jsonEncode(refs);
    return RestaurantProfileModel.fromMap(row);
  }

  /// Updates the restaurant profile for [userId].
  ///
  /// - Throws [ProfileException] if the user is not a 'restaurant'.
  /// - Throws [ProfileException] if [name] would become empty.
  /// - Validates [description] length.
  /// - Always sets [updated_at].
  Future<void> updateRestaurantProfile({
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

    await db.update(
      'restaurant_profiles',
      {
        'name':         ?name,
        'address':      ?address,
        'latitude':     ?latitude,
        'longitude':    ?longitude,
        if (openingHours != null)
          'opening_hours': jsonEncode(openingHours),
        'cuisine_type': ?cuisineType,
        'description':  ?description,
        'updated_at': now,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

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

      // Delete old file only after the DB write succeeds.
      if (oldPath != null) await deleteStoredPhoto(oldPath);
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

  /// Reads `profile_photos` rows back as `data:` URIs, ordered by position.
  ///
  /// Returns an empty list on mobile — there the photo reference is a file
  /// path already stored in the profile row.
  Future<List<String>> _webPhotoRefs(int userId, String userType) async {
    if (!kIsWeb) return const [];
    final db = await _database;
    final rows = await db.query(
      'profile_photos',
      columns: ['mime_type', 'data'],
      where: 'user_id = ? AND user_type = ?',
      whereArgs: [userId, userType],
      orderBy: 'position ASC, id ASC',
    );
    return rows.map((row) {
      final mime  = (row['mime_type'] as String?) ?? 'image/jpeg';
      final data  = row['data'];
      final bytes = data is Uint8List
          ? data
          : Uint8List.fromList((data as List).cast<int>());
      return encodePhotoDataUri(mime, bytes);
    }).toList();
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
  (_) => ProfileRepository(),
);
