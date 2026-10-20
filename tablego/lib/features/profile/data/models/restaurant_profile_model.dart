import 'dart:convert';

/// Typed model for a restaurant account's profile data.
///
/// Combines columns from both the [users] table and the
/// [restaurant_profiles] table.
///
/// JSON columns ([openingHours], [photoPaths]) are decoded inside
/// [fromMap] with safe fallbacks.
class RestaurantProfileModel {
  const RestaurantProfileModel({
    required this.id,
    required this.email,
    required this.userType,
    required this.createdAt,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.cuisineType,
    this.description,
    this.openingHours = const {},
    this.photoPaths = const [],
  });

  // ── From users table ──────────────────────────────────────────────────────
  final int id;

  /// Always lowercase.
  final String email;
  final String userType;
  final String createdAt;

  // ── From restaurant_profiles table ────────────────────────────────────────

  /// Restaurant display name. Always non-empty (enforced by DB CHECK).
  final String name;

  final String? address;
  final double? latitude;
  final double? longitude;
  final String? cuisineType;
  final String? description;

  /// Decoded opening-hours map, e.g.
  /// `{'mon': {'open': '11:00', 'close': '23:00'}, ...}`.
  /// Empty map when not set.
  final Map<String, dynamic> openingHours;

  /// Absolute paths to photos on-device. Empty list when not set.
  final List<String> photoPaths;

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory RestaurantProfileModel.fromMap(Map<String, dynamic> map) =>
      RestaurantProfileModel(
        id:           map['id']           as int,
        email:        map['email']        as String,
        userType:     map['user_type']    as String,
        createdAt:    map['created_at']   as String,
        name:         (map['name']        as String?) ?? '',
        address:      map['address']      as String?,
        latitude:     _toDouble(map['latitude']),
        longitude:    _toDouble(map['longitude']),
        cuisineType:  map['cuisine_type'] as String?,
        description:  map['description'] as String?,
        openingHours: decodeMap(map['opening_hours']),
        photoPaths:   decodeList(map['photo_paths']),
      );

  Map<String, dynamic> toMap() => {
        'id':            id,
        'email':         email,
        'user_type':     userType,
        'created_at':    createdAt,
        'name':          name,
        'address':       address,
        'latitude':      latitude,
        'longitude':     longitude,
        'cuisine_type':  cuisineType,
        'description':   description,
        'opening_hours': jsonEncode(openingHours),
        'photo_paths':   jsonEncode(photoPaths),
      };

  RestaurantProfileModel copyWith({
    String?               name,
    String?               address,
    double?               latitude,
    double?               longitude,
    String?               cuisineType,
    String?               description,
    Map<String, dynamic>? openingHours,
    List<String>?         photoPaths,
  }) =>
      RestaurantProfileModel(
        id:           id,
        email:        email,
        userType:     userType,
        createdAt:    createdAt,
        name:         name         ?? this.name,
        address:      address      ?? this.address,
        latitude:     latitude     ?? this.latitude,
        longitude:    longitude    ?? this.longitude,
        cuisineType:  cuisineType  ?? this.cuisineType,
        description:  description  ?? this.description,
        openingHours: openingHours ?? this.openingHours,
        photoPaths:   photoPaths   ?? this.photoPaths,
      );

  // ── Static decode helpers (package-visible, used by ProfileRepository) ────

  /// Safely decodes a value that may be null, a List, or a JSON string.
  static List<String> decodeList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  /// Safely decodes a value that may be null, a Map, or a JSON string.
  static Map<String, dynamic> decodeMap(dynamic value) {
    if (value == null) return const {};
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  String toString() =>
      'RestaurantProfileModel(id: $id, email: $email, name: $name)';
}
