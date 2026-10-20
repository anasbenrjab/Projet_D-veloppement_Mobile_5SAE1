import '../../../profile/data/models/restaurant_profile_model.dart';

/// Lightweight dish model returned by the favorites JOIN query.
///
/// Fields mirror the backend's `getFavoriteDishes` SELECT:
/// id, name, description, price, photo_path, tags,
/// restaurant_id, restaurant_name, restaurant_address,
/// cuisine_type, favorited_at.
class DishSummaryModel {
  const DishSummaryModel({
    required this.id,
    required this.name,
    required this.price,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.cuisineType,
    required this.favoritedAt,
    this.description,
    this.photoPath,
    this.tags = const [],
  });

  final int    id;
  final String name;
  final double price;

  /// ISO-8601 timestamp when this row was added to favorites.
  final String favoritedAt;

  final String? description;

  /// Absolute path to local photo file, or null.
  final String? photoPath;

  /// Decoded tags list.
  final List<String> tags;

  // ── Denormalised restaurant info (from JOIN) ──────────────────────────────
  final int    restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String cuisineType;

  factory DishSummaryModel.fromMap(Map<String, dynamic> map) =>
      DishSummaryModel(
        id:                map['id']                 as int,
        name:              (map['name']              as String?) ?? '',
        price:             _toDouble(map['price']),
        restaurantId:      map['restaurant_id']      as int,
        restaurantName:    (map['restaurant_name']   as String?) ?? '',
        restaurantAddress: (map['restaurant_address'] as String?) ?? '',
        cuisineType:       (map['cuisine_type']      as String?) ?? '',
        favoritedAt:       (map['favorited_at']       as String?) ?? '',
        description:       map['description']        as String?,
        photoPath:         map['photo_path']         as String?,
        tags:              RestaurantProfileModel.decodeList(map['tags']),
      );

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  String toString() =>
      'DishSummaryModel(id: $id, name: $name, price: $price)';
}
