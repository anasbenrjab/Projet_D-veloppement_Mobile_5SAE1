import 'dart:convert';

import '../../../../core/utils/json_utils.dart';
import '../../../recommendations/domain/food_labels.dart';

class DishModel {
  final int? id;
  final String name;
  final String description;
  final double price;
  final String category;

  /// Stored in the shared `dishes.photo_path` column: a network URL
  /// (TheMealDB), a `data:` URI (imported photo), a bundled asset or a file
  /// path — see `DishImage`.
  final String? imagePath;
  final bool isAvailable;

  /// Display label, e.g. `"Gluten, Lactose"`; `"Aucun"` = declared none,
  /// `""` = not declared.  Stored in the shared `dishes.allergens` column as
  /// a normalised JSON array (see [allergensToDb] / [allergensFromDb]), the
  /// format the recommender reads.
  final String allergens;

  /// `restaurant_profiles.id`.  Set by `DishNotifier` from the logged-in
  /// restaurant when a dish is created.
  final int restaurantId;
  final DateTime createdAt;

  const DishModel({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imagePath,
    this.isAvailable = true,
    this.allergens = '',
    this.restaurantId = 0,
    required this.createdAt,
  });

  // All dish categories used in the app
  static const List<String> categories = [
    'Entrée',
    'Plat principal',
    'Dessert',
    'Boisson',
    'Snack',
    'Menu enfant',
    'Spécialité',
  ];

  /// Category of dishes created before `dishes.category` existed (v4).
  static const String defaultCategory = 'Plat principal';

  static const String noAllergen = 'Aucun';

  /// Label → JSON column: `""` → NULL (not declared), `"Aucun"` → `[]`,
  /// otherwise the canonical names (`"Lait, Œuf"` → `["lactose","oeufs"]`).
  static String? allergensToDb(String label) {
    final parts = label
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.length == 1 && parts.first.toLowerCase() == 'aucun') {
      return jsonEncode(<String>[]);
    }
    return jsonEncode(FoodLabels.canonicalSet(parts).toList());
  }

  /// JSON column → label (inverse of [allergensToDb]).
  static String allergensFromDb(Object? value) {
    if (value == null) return '';
    final list = parseStringList(value);
    if (list.isEmpty) return noAllergen;
    return list
        .map((a) {
          final d = FoodLabels.display(FoodLabels.canonical(a));
          return d.isEmpty ? d : d[0].toUpperCase() + d.substring(1);
        })
        .join(', ');
  }

  factory DishModel.fromMap(Map<String, dynamic> map) => DishModel(
    id: map['id'] as int?,
    name: map['name'] as String,
    description: map['description'] as String? ?? '',
    price: (map['price'] as num).toDouble(),
    category: map['category'] as String? ?? defaultCategory,
    imagePath: map['photo_path'] as String?,
    isAvailable: (map['is_available'] as int) == 1,
    allergens: allergensFromDb(map['allergens']),
    restaurantId: map['restaurant_id'] as int,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'price': price,
    'category': category,
    'photo_path': imagePath,
    'is_available': isAvailable ? 1 : 0,
    'allergens': allergensToDb(allergens),
    'restaurant_id': restaurantId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  DishModel copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imagePath,
    bool? isAvailable,
    String? allergens,
    int? restaurantId,
    DateTime? createdAt,
  }) => DishModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    category: category ?? this.category,
    imagePath: imagePath ?? this.imagePath,
    isAvailable: isAvailable ?? this.isAvailable,
    allergens: allergens ?? this.allergens,
    restaurantId: restaurantId ?? this.restaurantId,
    createdAt: createdAt ?? this.createdAt,
  );
}
