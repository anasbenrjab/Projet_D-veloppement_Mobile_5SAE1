import '../../../menu/data/models/dish_model.dart';

class CartItemModel {
  final int? id;
  final int dishId;
  final int quantity;
  final DateTime addedAt;

  // Joined field (not stored in DB, populated via query)
  final DishModel? dish;

  const CartItemModel({
    this.id,
    required this.dishId,
    this.quantity = 1,
    required this.addedAt,
    this.dish,
  });

  double get subtotal => (dish?.price ?? 0) * quantity;

  factory CartItemModel.fromMap(Map<String, dynamic> map,
      {DishModel? dish}) =>
      CartItemModel(
        id: map['id'] as int?,
        dishId: map['dish_id'] as int,
        quantity: map['quantity'] as int,
        addedAt: DateTime.parse(map['added_at'] as String),
        dish: dish,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'dish_id': dishId,
        'quantity': quantity,
        'added_at': addedAt.toIso8601String(),
      };

  CartItemModel copyWith({
    int? id,
    int? dishId,
    int? quantity,
    DateTime? addedAt,
    DishModel? dish,
  }) =>
      CartItemModel(
        id: id ?? this.id,
        dishId: dishId ?? this.dishId,
        quantity: quantity ?? this.quantity,
        addedAt: addedAt ?? this.addedAt,
        dish: dish ?? this.dish,
      );
}
