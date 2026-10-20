import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/favorites/providers/favorites_provider.dart';
import '../../../../shared/widgets/restaurant_card.dart';
import '../../providers/recommendations_provider.dart';

class RecommendationCarousel extends ConsumerWidget {
  const RecommendationCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).user?.id;
    final state  = ref.watch(recommendationsProvider);

    return state.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final r    = items[i];
              final rest = r.restaurant;
              final isFav = userId != null &&
                  ref
                      .watch(favoriteRestaurantsProvider(userId))
                      .restaurants
                      .any((f) => f.id == rest.id);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 200,
                  child: RestaurantCard(
                    name:        rest.name,
                    cuisineType: rest.cuisineType,
                    address:     rest.address,
                    photoPath:   rest.firstPhotoPath,
                    isFavorite:  isFav,
                    showAiBadge: true,
                    onFavoriteTap: userId == null
                        ? null
                        : () => ref
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
