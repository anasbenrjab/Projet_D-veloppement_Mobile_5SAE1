class DishModel {
  final int? id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imagePath;
  final bool isAvailable;
  final String allergens;
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
    this.restaurantId = 1,
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

  factory DishModel.fromMap(Map<String, dynamic> map) => DishModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        price: (map['price'] as num).toDouble(),
        category: map['category'] as String,
        imagePath: map['image_path'] as String?,
        isAvailable: (map['is_available'] as int) == 1,
        allergens: map['allergens'] as String? ?? '',
        restaurantId: map['restaurant_id'] as int? ?? 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'image_path': imagePath,
        'is_available': isAvailable ? 1 : 0,
        'allergens': allergens,
        'restaurant_id': restaurantId,
        'created_at': createdAt.toIso8601String(),
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
  }) =>
      DishModel(
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
