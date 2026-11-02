import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/favorites/providers/favorites_provider.dart';
import '../../../../shared/widgets/dish_card.dart';
import '../../../../shared/widgets/restaurant_card.dart';
import '../../domain/recommendation_models.dart';
import '../../providers/recommendations_provider.dart';

/// Watches the current client's recommendations and renders [builder] with
/// them.  While a refresh runs (favorite toggled, profile saved, order
/// placed) the previous list stays on screen instead of a spinner.
class _RecommendationsBuilder extends ConsumerWidget {
  const _RecommendationsBuilder({required this.builder, this.loadingHeight});

  final Widget Function(
      BuildContext context, WidgetRef ref, int userId, RecommendationResult r)
      builder;
  final double? loadingHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).user?.id;
    if (userId == null) return const SizedBox.shrink();

    return ref.watch(recommendationsProvider(userId)).when(
          skipLoadingOnReload: true,
          loading: () => loadingHeight == null
              ? const SizedBox.shrink()
              : SizedBox(
                  height: loadingHeight,
                  child: const Center(child: CircularProgressIndicator()),
                ),
          error: (e, _) => const SizedBox.shrink(),
          data: (result) => builder(context, ref, userId, result),
        );
  }
}

/// "Recommandé pour vous": horizontally scrolling restaurant cards, each
/// with the reason it was recommended.
class RecommendationCarousel extends StatelessWidget {
  const RecommendationCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return _RecommendationsBuilder(
      loadingHeight: 270,
      builder: (context, ref, userId, result) {
        final items = result.restaurants;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Aucun restaurant compatible avec vos préférences pour le moment.',
              style: TextStyle(fontSize: 13),
            ),
          );
        }
        final favorites = ref.watch(favoriteRestaurantsProvider(userId));
        return SizedBox(
          height: 270,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final rec = items[i];
              final rest = rec.restaurant;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 220,
                  child: RestaurantCard(
                    name:        rest.name,
                    cuisineType: rest.cuisineType,
                    address:     rest.address,
                    photoPath:   rest.firstPhotoPath,
                    isFavorite:  favorites.restaurants.any((f) => f.id == rest.id),
                    showAiBadge: true,
                    reason:      rec.explanation,
                    onFavoriteTap: () => ref
                        .read(favoriteRestaurantsProvider(userId).notifier)
                        .toggle(rest.id),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// "Plats pour vous": section title and horizontally scrolling dish cards,
/// hidden when no dish is compatible.
class DishRecommendationsSection extends StatelessWidget {
  const DishRecommendationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _RecommendationsBuilder(
      builder: (context, ref, userId, result) {
        final items = result.dishes;
        if (items.isEmpty) return const SizedBox.shrink();
        final favorites = ref.watch(favoriteDishesProvider(userId));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text('Plats pour vous',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final rec = items[i];
                  final dish = rec.dish;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 300,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: DishCard(
                          name:           dish.name,
                          price:          dish.price,
                          restaurantName: rec.restaurantName,
                          description:    dish.description,
                          photoPath:      dish.photoPath,
                          isFavorite:
                              favorites.dishes.any((f) => f.id == dish.id),
                          reason:         rec.explanation,
                          onFavoriteTap: () => ref
                              .read(favoriteDishesProvider(userId).notifier)
                              .toggle(dish.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
