import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/widgets/dish_card.dart';
import '../../../../shared/widgets/restaurant_card.dart';
import '../../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Surface any errors from either notifier as a SnackBar.
    final userId = ref.watch(authProvider).user?.id;

    if (userId != null) {
      ref.listen(favoriteRestaurantsProvider(userId), (_, next) {
        if (next.error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(next.error!)));
          ref
              .read(favoriteRestaurantsProvider(userId).notifier)
              .clearError();
        }
      });
      ref.listen(favoriteDishesProvider(userId), (_, next) {
        if (next.error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(next.error!)));
          ref.read(favoriteDishesProvider(userId).notifier).clearError();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoris'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey500,
          tabs: const [
            Tab(text: 'Restaurants'),
            Tab(text: 'Plats'),
          ],
        ),
      ),
      body: userId == null
          ? const Center(child: Text('Connectez-vous pour voir vos favoris'))
          : TabBarView(
              controller: _tabController,
              children: [
                _RestaurantsTab(userId: userId),
                _DishesTab(userId: userId),
              ],
            ),
    );
  }
}

// ── Restaurants tab ───────────────────────────────────────────────────────────

class _RestaurantsTab extends ConsumerWidget {
  const _RestaurantsTab({required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteRestaurantsProvider(userId));

    if (state.isLoading && state.restaurants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.restaurants.isEmpty) {
      return const _EmptyState(
        icon: Icons.favorite_border,
        message:
            'Aucun restaurant favori\nAjoutez des restaurants que vous aimez',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(favoriteRestaurantsProvider(userId).notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.restaurants.length,
        itemBuilder: (_, i) {
          final r = state.restaurants[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RestaurantCard(
              name:        r.name,
              cuisineType: r.cuisineType,
              address:     r.address,
              photoPath:   r.firstPhotoPath,
              isFavorite:  true,
              onFavoriteTap: () => ref
                  .read(favoriteRestaurantsProvider(userId).notifier)
                  .toggle(r.id),
            ),
          );
        },
      ),
    );
  }
}

// ── Dishes tab ────────────────────────────────────────────────────────────────

class _DishesTab extends ConsumerWidget {
  const _DishesTab({required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteDishesProvider(userId));

    if (state.isLoading && state.dishes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.dishes.isEmpty) {
      return const _EmptyState(
        icon: Icons.fastfood_outlined,
        message: 'Aucun plat favori\nAjoutez des plats que vous aimez',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(favoriteDishesProvider(userId).notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.dishes.length,
        itemBuilder: (_, i) {
          final d = state.dishes[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DishCard(
              name:           d.name,
              price:          d.price,
              restaurantName: d.restaurantName,
              description:    d.description,
              photoPath:      d.photoPath,
              isFavorite:     true,
              onFavoriteTap: () => ref
                  .read(favoriteDishesProvider(userId).notifier)
                  .toggle(d.id),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.grey500, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
