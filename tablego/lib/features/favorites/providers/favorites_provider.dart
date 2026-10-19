import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/favorites_repository.dart';

// ─── Restaurants ──────────────────────────────────────────────────────────────
class FavoriteRestaurantsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  FavoriteRestaurantsNotifier(this._repo) : super(const AsyncLoading()) {
    load();
  }

  final FavoritesRepository _repo;

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getFavoriteRestaurants());
  }

  Future<void> toggle(int restaurantId) async {
    final current = state.valueOrNull ?? [];
    final isFav = current.any((r) => r['id'] == restaurantId);
    try {
      if (isFav) {
        await _repo.removeFavoriteRestaurant(restaurantId);
      } else {
        await _repo.addFavoriteRestaurant(restaurantId);
      }
      await load();
    } catch (_) {
      // Keep current state on error
    }
  }

  bool isFavorite(int id) =>
      (state.valueOrNull ?? []).any((r) => r['id'] == id);
}

final favoriteRestaurantsProvider = StateNotifierProvider<
    FavoriteRestaurantsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => FavoriteRestaurantsNotifier(ref.watch(favoritesRepositoryProvider)),
);

// ─── Dishes ───────────────────────────────────────────────────────────────────
class FavoriteDishesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  FavoriteDishesNotifier(this._repo) : super(const AsyncLoading()) {
    load();
  }

  final FavoritesRepository _repo;

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getFavoriteDishes());
  }

  Future<void> toggle(int dishId) async {
    final current = state.valueOrNull ?? [];
    final isFav = current.any((d) => d['id'] == dishId);
    try {
      if (isFav) {
        await _repo.removeFavoriteDish(dishId);
      } else {
        await _repo.addFavoriteDish(dishId);
      }
      await load();
    } catch (_) {}
  }

  bool isFavorite(int id) =>
      (state.valueOrNull ?? []).any((d) => d['id'] == id);
}

final favoriteDishesProvider = StateNotifierProvider<FavoriteDishesNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) =>
      FavoriteDishesNotifier(ref.watch(favoritesRepositoryProvider)),
);
