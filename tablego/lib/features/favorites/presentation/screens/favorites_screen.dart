import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_utils.dart';
import '../../../../shared/widgets/restaurant_card.dart';
import '../../../../shared/widgets/dish_card.dart';
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _RestaurantsTab(),
          _DishesTab(),
        ],
      ),
    );
  }
}

// ─── Restaurants tab ──────────────────────────────────────────────────────────
class _RestaurantsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteRestaurantsProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (restaurants) {
        if (restaurants.isEmpty) {
          return const _EmptyState(
            icon: Icons.favorite_border,
            message: 'Aucun restaurant favori\nAjoutez des restaurants que vous aimez',
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(favoriteRestaurantsProvider.notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: restaurants.length,
            itemBuilder: (_, i) {
              final r = restaurants[i];
              final id = r['id'] as int;
              final photos = parseStringList(r['photos']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RestaurantCard(
                  name: r['name'] ?? '',
                  cuisineType: r['cuisine_type'] ?? '',
                  address: r['address'] ?? '',
                  photoUrl: photos.isNotEmpty ? photos.first : null,
                  isFavorite: true,
                  onFavoriteTap: () => ref
                      .read(favoriteRestaurantsProvider.notifier)
                      .toggle(id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Dishes tab ───────────────────────────────────────────────────────────────
class _DishesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteDishesProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (dishes) {
        if (dishes.isEmpty) {
          return const _EmptyState(
            icon: Icons.fastfood_outlined,
            message: 'Aucun plat favori\nAjoutez des plats que vous aimez',
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(favoriteDishesProvider.notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dishes.length,
            itemBuilder: (_, i) {
              final d = dishes[i];
              final id = d['id'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DishCard(
                  name: d['name'] ?? '',
                  price: (d['price'] as num?)?.toDouble() ?? 0.0,
                  restaurantName: d['restaurant_name'] ?? '',
                  description: d['description'],
                  photoUrl: d['photo_url'],
                  isFavorite: true,
                  onFavoriteTap: () =>
                      ref.read(favoriteDishesProvider.notifier).toggle(id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

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
