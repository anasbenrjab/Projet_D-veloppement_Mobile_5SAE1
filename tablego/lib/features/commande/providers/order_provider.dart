import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/order_model.dart';
import '../data/repositories/order_repository.dart';
import '../data/models/cart_item_model.dart';

class OrderState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const OrderState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  OrderState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) =>
      OrderState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        successMessage:
            clearSuccess ? null : successMessage ?? this.successMessage,
      );
}

class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier(this._repo) : super(const OrderState()) {
    loadOrders();
  }

  final OrderRepository _repo;

  Future<void> loadOrders({int restaurantId = 1}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repo.getAllOrders(restaurantId: restaurantId);
      state = state.copyWith(isLoading: false, orders: orders);
    } catch (e) {
      state =
          state.copyWith(isLoading: false, error: 'Erreur de chargement: $e');
    }
  }

  Future<OrderModel?> placeOrder({
    required List<CartItemModel> cartItems,
    required String orderType,
    String note = '',
    String clientName = 'Client',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final order = await _repo.placeOrder(
        cartItems: cartItems,
        orderType: orderType,
        note: note,
        clientName: clientName,
      );
      await loadOrders();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Commande #${order.id} passée avec succès !',
      );
      return order;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Erreur lors de la commande: $e');
      return null;
    }
  }

  Future<void> advanceStatus(int orderId) async {
    try {
      await _repo.advanceStatus(orderId);
      await loadOrders();
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  Future<void> updateStatus(int orderId, String newStatus) async {
    try {
      await _repo.updateStatus(orderId, newStatus);
      // Update locally without a full reload for instant UI feedback
      state = state.copyWith(
        orders: state.orders
            .map((o) =>
                o.id == orderId ? o.copyWith(status: newStatus) : o)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  void clearMessages() =>
      state = state.copyWith(clearError: true, clearSuccess: true);
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>(
  (ref) => OrderNotifier(ref.watch(orderRepositoryProvider)),
);
