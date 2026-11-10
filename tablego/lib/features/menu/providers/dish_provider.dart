import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/dish_model.dart';
import '../../../core/data/user_data_changes.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/repositories/dish_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class DishState {
  final List<DishModel> dishes;
  final bool isLoading;
  final String? error;
  final String? selectedCategory;

  const DishState({
    this.dishes = const [],
    this.isLoading = true, // start loading by default
    this.error,
    this.selectedCategory,
  });

  List<DishModel> get filtered {
    if (selectedCategory == null) return dishes;
    return dishes.where((d) => d.category == selectedCategory).toList();
  }

  DishState copyWith({
    List<DishModel>? dishes,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    bool clearCategory = false,
    bool clearError = false,
  }) =>
      DishState(
        dishes: dishes ?? this.dishes,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        selectedCategory: clearCategory
            ? null
            : selectedCategory ?? this.selectedCategory,
      );
}

// ─── Restaurant notifier (all dishes) ─────────────────────────────────────────

class DishNotifier extends StateNotifier<DishState> {
  DishNotifier(this._repo, {required this._userId, this._onChanged})
      : super(const DishState(isLoading: true)) {
    loadAll();
  }

  final DishRepository _repo;

  /// Logged-in restaurant user (`users.id`, from authProvider).
  final int? _userId;

  /// Bumps userDataChangesProvider: the recommender reads dishes too.
  final void Function()? _onChanged;
  int? _restaurantId;

  /// `restaurant_profiles.id` of the logged-in restaurant.
  Future<int> _currentRestaurantId() async {
    final cached = _restaurantId;
    if (cached != null) return cached;
    final userId = _userId;
    final id = userId == null ? null : await _repo.restaurantIdForUser(userId);
    if (id == null) {
      throw StateError('Aucun profil restaurant pour ce compte.');
    }
    return _restaurantId = id;
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dishes =
          await _repo.getAllDishes(restaurantId: await _currentRestaurantId());
      debugPrint('[DishNotifier] loaded ${dishes.length} dishes');
      if (!mounted) return; // rebuilt for another user/restaurant
      state = state.copyWith(isLoading: false, dishes: dishes);
    } catch (e) {
      debugPrint('[DishNotifier] loadAll error: $e');
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  void setCategory(String? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(selectedCategory: category);
  }

  /// Returns true on success, false on failure.
  Future<bool> addDish(DishModel dish) async {
    try {
      await _repo.createDish(
          dish.copyWith(restaurantId: await _currentRestaurantId()));
      _onChanged?.call();
      await loadAll(); // re-read from DB to get accurate list + IDs
      return true;
    } catch (e) {
      debugPrint('[DishNotifier] addDish error: $e');
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: '$e');
      return false;
    }
  }

  Future<bool> updateDish(DishModel dish) async {
    try {
      await _repo.updateDish(dish);
      _onChanged?.call();
      await loadAll();
      return true;
    } catch (e) {
      debugPrint('[DishNotifier] updateDish error: $e');
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: '$e');
      return false;
    }
  }

  Future<void> toggleAvailability(int id, bool isAvailable) async {
    await _repo.toggleAvailability(id, isAvailable);
    _onChanged?.call();
    state = state.copyWith(
      dishes: state.dishes
          .map((d) => d.id == id ? d.copyWith(isAvailable: isAvailable) : d)
          .toList(),
    );
  }

  Future<void> deleteDish(int id) async {
    await _repo.deleteDish(id);
    _onChanged?.call();
    state = state.copyWith(
        dishes: state.dishes.where((d) => d.id != id).toList());
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final dishProvider = StateNotifierProvider<DishNotifier, DishState>(
  (ref) => DishNotifier(
    ref.watch(dishRepositoryProvider),
    userId: ref.watch(authProvider.select((s) => s.user?.id)),
    onChanged: () => ref.read(userDataChangesProvider.notifier).changed(),
  ),
);

// ─── Client notifier (available dishes only) ──────────────────────────────────

/// Restaurant whose menu the client is browsing (`restaurant_profiles.id`).
/// Set when the client opens a restaurant; [menuProvider] and the cart are
/// scoped to it.
final selectedRestaurantProvider = StateProvider<int?>((ref) => null);

class MenuNotifier extends StateNotifier<DishState> {
  MenuNotifier(this._repo, {required this._restaurantId})
      : super(const DishState(isLoading: true)) {
    loadMenu();
  }

  final DishRepository _repo;
  final int? _restaurantId;

  Future<void> loadMenu() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null) {
      state = state.copyWith(isLoading: false, dishes: const []);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dishes = await _repo.getAvailableDishes(restaurantId: restaurantId);
      debugPrint('[MenuNotifier] loaded ${dishes.length} available dishes');
      if (!mounted) return; // rebuilt for another user/restaurant
      state = state.copyWith(isLoading: false, dishes: dishes);
    } catch (e) {
      debugPrint('[MenuNotifier] loadMenu error: $e');
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  void setCategory(String? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(selectedCategory: category);
  }

  Future<List<DishModel>> search(String query) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null) return const [];
    return _repo.searchDishes(query, restaurantId: restaurantId);
  }
}

final menuProvider = StateNotifierProvider<MenuNotifier, DishState>(
  (ref) => MenuNotifier(
    ref.watch(dishRepositoryProvider),
    restaurantId: ref.watch(selectedRestaurantProvider),
  ),
);
