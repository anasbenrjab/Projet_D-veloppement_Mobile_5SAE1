import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/models/dish_summary_model.dart';
import '../data/models/restaurant_summary_model.dart';
import '../data/repositories/favorites_repository.dart';
import '../domain/favorites_exception.dart';

// ── Favorite restaurants ──────────────────────────────────────────────────────

class FavoriteRestaurantsState {
  const FavoriteRestaurantsState({
    this.restaurants = const [],
    this.isLoading = false,
    this.error,
  });

  final List<RestaurantSummaryModel> restaurants;
  final bool isLoading;

  /// Non-null when an operation failed. Displayed directly in the UI.
  final String? error;

  FavoriteRestaurantsState copyWith({
    List<RestaurantSummaryModel>? restaurants,
    bool?   isLoading,
    String? error,
    bool    clearError = false,
  }) =>
      FavoriteRestaurantsState(
        restaurants: restaurants ?? this.restaurants,
        isLoading:   isLoading   ?? this.isLoading,
        error:       clearError ? null : error ?? this.error,
      );
}

class FavoriteRestaurantsNotifier
    extends StateNotifier<FavoriteRestaurantsState> {
  FavoriteRestaurantsNotifier(this._repo, this._userId)
      : super(const FavoriteRestaurantsState()) {
    load();
  }

  final FavoritesRepository _repo;
  final int _userId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repo.getFavoriteRestaurants(_userId);
      state = state.copyWith(isLoading: false, restaurants: list);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: _parseError(e));
    }
  }

  /// Optimistic toggle: update the local list immediately, then write to DB.
  /// If the DB write fails, roll back to the previous state and surface the
  /// error.
  Future<void> toggle(int restaurantId) async {
    final previous  = state.restaurants;
    final isFav     = previous.any((r) => r.id == restaurantId);

    // Optimistic update — remove or add a placeholder entry.
    state = state.copyWith(
      restaurants: isFav
          ? previous.where((r) => r.id != restaurantId).toList()
          : previous, // adding: we'll reload on success to get full data
      clearError: true,
    );

    try {
      if (isFav) {
        await _repo.removeFavoriteRestaurant(_userId, restaurantId);
        // State is already correct for removal — no reload needed.
      } else {
        await _repo.addFavoriteRestaurant(_userId, restaurantId);
        // Reload to get the full RestaurantSummaryModel from the JOIN.
        await load();
      }
    } catch (e) {
      // Roll back to the previous list and surface the error.
      state = state.copyWith(
        restaurants: previous,
        error: _parseError(e),
      );
    }
  }

  bool isFavorite(int id) => state.restaurants.any((r) => r.id == id);

  void clearError() => state = state.copyWith(clearError: true);

  String _parseError(Object e) {
    if (e is FavoritesException) return e.message;
    if (e is DatabaseException)  return 'Une erreur interne est survenue.';
    return 'Une erreur inattendue est survenue.';
  }
}

// ── Favorite dishes ───────────────────────────────────────────────────────────

class FavoriteDishesState {
  const FavoriteDishesState({
    this.dishes = const [],
    this.isLoading = false,
    this.error,
  });

  final List<DishSummaryModel> dishes;
  final bool isLoading;

  /// Non-null when an operation failed. Displayed directly in the UI.
  final String? error;

  FavoriteDishesState copyWith({
    List<DishSummaryModel>? dishes,
    bool?   isLoading,
    String? error,
    bool    clearError = false,
  }) =>
      FavoriteDishesState(
        dishes:    dishes    ?? this.dishes,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : error ?? this.error,
      );
}

class FavoriteDishesNotifier extends StateNotifier<FavoriteDishesState> {
  FavoriteDishesNotifier(this._repo, this._userId)
      : super(const FavoriteDishesState()) {
    load();
  }

  final FavoritesRepository _repo;
  final int _userId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repo.getFavoriteDishes(_userId);
      state = state.copyWith(isLoading: false, dishes: list);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: _parseError(e));
    }
  }

  /// Optimistic toggle with rollback on DB failure.
  Future<void> toggle(int dishId) async {
    final previous = state.dishes;
    final isFav    = previous.any((d) => d.id == dishId);

    state = state.copyWith(
      dishes: isFav
          ? previous.where((d) => d.id != dishId).toList()
          : previous,
      clearError: true,
    );

    try {
      if (isFav) {
        await _repo.removeFavoriteDish(_userId, dishId);
      } else {
        await _repo.addFavoriteDish(_userId, dishId);
        await load();
      }
    } catch (e) {
      state = state.copyWith(dishes: previous, error: _parseError(e));
    }
  }

  bool isFavorite(int id) => state.dishes.any((d) => d.id == id);

  void clearError() => state = state.copyWith(clearError: true);

  String _parseError(Object e) {
    if (e is FavoritesException) return e.message;
    if (e is DatabaseException)  return 'Une erreur interne est survenue.';
    return 'Une erreur inattendue est survenue.';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// userId must be provided by callers that have an authenticated user.
/// The providers below take a [userId] parameter via family.
final favoriteRestaurantsProvider = StateNotifierProvider.family<
    FavoriteRestaurantsNotifier, FavoriteRestaurantsState, int>(
  (ref, userId) =>
      FavoriteRestaurantsNotifier(ref.watch(favoritesRepositoryProvider), userId),
);

final favoriteDishesProvider = StateNotifierProvider.family<
    FavoriteDishesNotifier, FavoriteDishesState, int>(
  (ref, userId) =>
      FavoriteDishesNotifier(ref.watch(favoritesRepositoryProvider), userId),
);
