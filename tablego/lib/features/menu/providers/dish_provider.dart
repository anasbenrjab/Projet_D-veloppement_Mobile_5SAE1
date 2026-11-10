import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/dish_model.dart';
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
  DishNotifier(this._repo) : super(const DishState(isLoading: true)) {
    loadAll();
  }

  final DishRepository _repo;

  Future<void> loadAll({int restaurantId = 1}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dishes = await _repo.getAllDishes(restaurantId: restaurantId);
      debugPrint('[DishNotifier] loaded ${dishes.length} dishes');
      state = state.copyWith(isLoading: false, dishes: dishes);
    } catch (e) {
      debugPrint('[DishNotifier] loadAll error: $e');
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
      await _repo.createDish(dish);
      await loadAll(); // re-read from DB to get accurate list + IDs
      return true;
    } catch (e) {
      debugPrint('[DishNotifier] addDish error: $e');
      state = state.copyWith(isLoading: false, error: '$e');
      return false;
    }
  }

  Future<bool> updateDish(DishModel dish) async {
    try {
      await _repo.updateDish(dish);
      await loadAll();
      return true;
    } catch (e) {
      debugPrint('[DishNotifier] updateDish error: $e');
      state = state.copyWith(isLoading: false, error: '$e');
      return false;
    }
  }

  Future<void> toggleAvailability(int id, bool isAvailable) async {
    await _repo.toggleAvailability(id, isAvailable);
    state = state.copyWith(
      dishes: state.dishes
          .map((d) => d.id == id ? d.copyWith(isAvailable: isAvailable) : d)
          .toList(),
    );
  }

  Future<void> deleteDish(int id) async {
    await _repo.deleteDish(id);
    state = state.copyWith(
        dishes: state.dishes.where((d) => d.id != id).toList());
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final dishProvider = StateNotifierProvider<DishNotifier, DishState>(
  (ref) => DishNotifier(ref.watch(dishRepositoryProvider)),
);

// ─── Client notifier (available dishes only) ──────────────────────────────────

class MenuNotifier extends StateNotifier<DishState> {
  MenuNotifier(this._repo) : super(const DishState(isLoading: true)) {
    loadMenu();
  }

  final DishRepository _repo;

  Future<void> loadMenu({int restaurantId = 1}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dishes = await _repo.getAvailableDishes(restaurantId: restaurantId);
      debugPrint('[MenuNotifier] loaded ${dishes.length} available dishes');
      state = state.copyWith(isLoading: false, dishes: dishes);
    } catch (e) {
      debugPrint('[MenuNotifier] loadMenu error: $e');
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  void setCategory(String? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(selectedCategory: category);
  }

  Future<List<DishModel>> search(String query) async {
    return _repo.searchDishes(query);
  }
}

final menuProvider = StateNotifierProvider<MenuNotifier, DishState>(
  (ref) => MenuNotifier(ref.watch(dishRepositoryProvider)),
);
