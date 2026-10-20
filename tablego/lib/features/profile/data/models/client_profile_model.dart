import 'dart:convert';

/// Typed model for a client account's profile data.
///
/// Combines columns from both the [users] table (id, email, userType,
/// createdAt) and the [client_profiles] table (fullName, phone, …).
///
/// JSON columns ([dietaryPreferences], [allergies]) are decoded inside
/// [fromMap] with safe fallbacks so callers never receive raw strings.
class ClientProfileModel {
  const ClientProfileModel({
    required this.id,
    required this.email,
    required this.userType,
    required this.createdAt,
    this.fullName,
    this.phone,
    this.photoPath,
    this.dietaryPreferences = const [],
    this.allergies = const [],
  });

  // ── From users table ──────────────────────────────────────────────────────
  final int id;

  /// Always lowercase.
  final String email;
  final String userType;
  final String createdAt;

  // ── From client_profiles table ────────────────────────────────────────────
  final String? fullName;
  final String? phone;

  /// Absolute path to the profile photo on-device, or null if not set.
  final String? photoPath;

  /// Decoded list; never null (defaults to empty list).
  final List<String> dietaryPreferences;

  /// Decoded list; never null (defaults to empty list).
  final List<String> allergies;

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory ClientProfileModel.fromMap(Map<String, dynamic> map) =>
      ClientProfileModel(
        id:                  map['id']         as int,
        email:               map['email']       as String,
        userType:            map['user_type']   as String,
        createdAt:           map['created_at']  as String,
        fullName:            map['full_name']   as String?,
        phone:               map['phone']       as String?,
        photoPath:           map['photo_path']  as String?,
        dietaryPreferences:  _decodeList(map['dietary_preferences']),
        allergies:           _decodeList(map['allergies']),
      );

  Map<String, dynamic> toMap() => {
        'id':                   id,
        'email':                email,
        'user_type':            userType,
        'created_at':           createdAt,
        'full_name':            fullName,
        'phone':                phone,
        'photo_path':           photoPath,
        'dietary_preferences':  jsonEncode(dietaryPreferences),
        'allergies':            jsonEncode(allergies),
      };

  ClientProfileModel copyWith({
    String?       fullName,
    String?       phone,
    String?       photoPath,
    List<String>? dietaryPreferences,
    List<String>? allergies,
    bool          clearPhotoPath = false,
  }) =>
      ClientProfileModel(
        id:                  id,
        email:               email,
        userType:            userType,
        createdAt:           createdAt,
        fullName:            fullName            ?? this.fullName,
        phone:               phone               ?? this.phone,
        photoPath:           clearPhotoPath ? null : photoPath ?? this.photoPath,
        dietaryPreferences:  dietaryPreferences  ?? this.dietaryPreferences,
        allergies:           allergies           ?? this.allergies,
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Safely decodes a value that may be:
  /// - null → []
  /// - already a List (sqflite sometimes returns native types) → cast
  /// - a JSON string → decode
  /// - anything else → []
  static List<String> _decodeList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  @override
  String toString() =>
      'ClientProfileModel(id: $id, email: $email, fullName: $fullName)';
}
