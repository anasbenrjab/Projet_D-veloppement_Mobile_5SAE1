import '../../../profile/data/models/restaurant_profile_model.dart';

/// Lightweight restaurant model returned by the favorites JOIN query.
///
/// Fields mirror the backend's `getFavoriteRestaurants` SELECT:
/// id, name, address, latitude, longitude, cuisine_type, photo_paths,
/// description, opening_hours, favorited_at.
class RestaurantSummaryModel {
  const RestaurantSummaryModel({
    required this.id,
    required this.name,
    required this.address,
    required this.cuisineType,
    required this.favoritedAt,
    this.latitude,
    this.longitude,
    this.description,
    this.openingHours = const {},
    this.photoPaths = const [],
  });

  final int    id;
  final String name;
  final String address;
  final String cuisineType;

  /// ISO-8601 timestamp when this row was added to favorites.
  final String favoritedAt;

  final double? latitude;
  final double? longitude;
  final String? description;

  /// Decoded opening-hours map.
  final Map<String, dynamic> openingHours;

  /// Absolute paths to local photo files (empty list when not set).
  final List<String> photoPaths;

  /// Convenience: first photo path, or null.
  String? get firstPhotoPath =>
      photoPaths.isNotEmpty ? photoPaths.first : null;

  factory RestaurantSummaryModel.fromMap(Map<String, dynamic> map) =>
      RestaurantSummaryModel(
        id:           map['id']           as int,
        name:         (map['name']        as String?) ?? '',
        address:      (map['address']     as String?) ?? '',
        cuisineType:  (map['cuisine_type'] as String?) ?? '',
        favoritedAt:  (map['favorited_at'] as String?) ?? '',
        latitude:     _toDouble(map['latitude']),
        longitude:    _toDouble(map['longitude']),
        description:  map['description']  as String?,
        openingHours: RestaurantProfileModel.decodeMap(map['opening_hours']),
        photoPaths:   RestaurantProfileModel.decodeList(map['photo_paths']),
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  String toString() =>
      'RestaurantSummaryModel(id: $id, name: $name)';
}
