import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cart_item_model.dart';
import '../data/repositories/cart_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../menu/providers/dish_provider.dart';

class CartState {
  final List<CartItemModel> items;
  final bool isLoading;
  final String? error;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  double get totalPrice =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  int get totalItems =>
      items.fold(0, (sum, item) => sum + item.quantity);

  bool containsDish(int dishId) =>
      items.any((ci) => ci.dishId == dishId);

  int quantityOf(int dishId) {
    final match = items.where((ci) => ci.dishId == dishId);
    return match.isEmpty ? 0 : match.first.quantity;
  }

  CartState copyWith({
    List<CartItemModel>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      CartState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this._repo, {required this._userId, required this._restaurantId})
      : super(const CartState()) {
    loadCart();
  }

  final CartRepository _repo;

  /// Logged-in client (`users.id`) and the restaurant being browsed: the
  /// cart shown is that client's cart for that restaurant.
  final int? _userId;
  final int? _restaurantId;
  bool get _ready => _userId != null && _restaurantId != null;

  Future<void> loadCart() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = _ready
          ? await _repo.getCartItems(
              userId: _userId!, restaurantId: _restaurantId!)
          : const <CartItemModel>[];
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> addToCart(int dishId) async {
    try {
      final userId = _userId;
      if (userId == null) return;
      await _repo.addToCart(userId: userId, dishId: dishId);
      await loadCart();
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    try {
      await _repo.updateQuantity(cartItemId, quantity);
      await loadCart();
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  Future<void> removeFromCart(int cartItemId) async {
    try {
      await _repo.removeFromCart(cartItemId);
      await loadCart();
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  Future<void> clearCart() async {
    try {
      if (_ready) {
        await _repo.clearCart(userId: _userId!, restaurantId: _restaurantId!);
      }
      state = state.copyWith(items: []);
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(
    ref.watch(cartRepositoryProvider),
    userId: ref.watch(authProvider.select((s) => s.user?.id)),
    restaurantId: ref.watch(selectedRestaurantProvider),
  ),
);
