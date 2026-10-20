import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
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

  /// Copies [sourcePath] into `<documents>/profile_photos/` with a UUID
  /// filename, writes the new path to the DB, then deletes the old file
  /// (client only — old path replaced) after the DB write succeeds.
  ///
  /// Returns the absolute path of the saved file.
  ///
  /// If the stored file no longer exists at read time the caller should
  /// fall back to the default avatar — this method only handles writes.
  Future<String> saveProfilePhoto({
    required int    userId,
    required String userType,
    required String sourcePath,
  }) async {
    final destPath = await _copyPhotoToDocuments(sourcePath);
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
      if (oldPath != null) await _deleteFileIfExists(oldPath);
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

  Future<String> _copyPhotoToDocuments(String sourcePath) async {
    final docsDir   = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docsDir.path, 'profile_photos'));
    if (!photosDir.existsSync()) await photosDir.create(recursive: true);

    final ext      = p.extension(sourcePath); // e.g. '.jpg'
    final filename = '${const Uuid().v4()}$ext';
    final destPath = p.join(photosDir.path, filename);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<void> _deleteFileIfExists(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort — do not propagate file-deletion errors.
    }
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => ProfileRepository(),
);
