class OrderStatus {
  static const String received = 'reçue';
  static const String preparing = 'en préparation';
  static const String ready = 'prête';

  static const List<String> all = [received, preparing, ready];

  static String nextStatus(String current) {
    final idx = all.indexOf(current);
    if (idx == -1 || idx == all.length - 1) return current;
    return all[idx + 1];
  }
}

class OrderType {
  static const String dineIn = 'sur place';
  static const String takeaway = 'à emporter';
  static const List<String> all = [dineIn, takeaway];
}

// ─── OrderItemModel ────────────────────────────────────────────────────────

class OrderItemModel {
  final int? id;
  final int orderId;
  final int dishId;
  final String dishName;
  final double dishPrice;
  final int quantity;

  const OrderItemModel({
    this.id,
    required this.orderId,
    required this.dishId,
    required this.dishName,
    required this.dishPrice,
    required this.quantity,
  });

  double get subtotal => dishPrice * quantity;

  factory OrderItemModel.fromMap(Map<String, dynamic> map) => OrderItemModel(
        id: map['id'] as int?,
        orderId: map['order_id'] as int,
        // NULL once the dish was deleted; the name/price snapshot remains.
        dishId: map['dish_id'] as int? ?? 0,
        dishName: map['dish_name'] as String,
        dishPrice: (map['dish_price'] as num).toDouble(),
        quantity: map['quantity'] as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'dish_id': dishId,
        'dish_name': dishName,
        'dish_price': dishPrice,
        'quantity': quantity,
      };
}

// ─── OrderModel ────────────────────────────────────────────────────────────

class OrderModel {
  final int? id;
  final String orderType;
  final String status;
  final double totalPrice;
  final String note;
  final String clientName;
  final int restaurantId;

  /// Client who placed the order (`users.id`).
  final int userId;
  final DateTime createdAt;

  // Joined
  final List<OrderItemModel> items;

  const OrderModel({
    this.id,
    required this.orderType,
    this.status = OrderStatus.received,
    required this.totalPrice,
    this.note = '',
    this.clientName = 'Client',
    this.restaurantId = 0,
    this.userId = 0,
    required this.createdAt,
    this.items = const [],
  });

  factory OrderModel.fromMap(Map<String, dynamic> map,
      {List<OrderItemModel> items = const []}) =>
      OrderModel(
        id: map['id'] as int?,
        orderType: map['order_type'] as String,
        status: map['status'] as String,
        totalPrice: (map['total_price'] as num).toDouble(),
        note: map['note'] as String? ?? '',
        clientName: map['client_name'] as String? ?? 'Client',
        restaurantId: map['restaurant_id'] as int,
        userId: map['user_id'] as int,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        items: items,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_type': orderType,
        'status': status,
        'total_price': totalPrice,
        'note': note,
        'client_name': clientName,
        'restaurant_id': restaurantId,
        'user_id': userId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  OrderModel copyWith({
    int? id,
    String? orderType,
    String? status,
    double? totalPrice,
    String? note,
    String? clientName,
    int? restaurantId,
    int? userId,
    DateTime? createdAt,
    List<OrderItemModel>? items,
  }) =>
      OrderModel(
        id: id ?? this.id,
        orderType: orderType ?? this.orderType,
        status: status ?? this.status,
        totalPrice: totalPrice ?? this.totalPrice,
        note: note ?? this.note,
        clientName: clientName ?? this.clientName,
        restaurantId: restaurantId ?? this.restaurantId,
        userId: userId ?? this.userId,
        createdAt: createdAt ?? this.createdAt,
        items: items ?? this.items,
      );
}
