import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/json_utils.dart';
import '../../../../shared/widgets/restaurant_card.dart';
import '../../providers/recommendations_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';

class RecommendationCarousel extends ConsumerWidget {
  const RecommendationCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recommendationsProvider);

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
              final r = items[i];
              final id = r['id'] as int;
              final photos = parseStringList(r['photos']);
              final isFav = ref
                  .watch(favoriteRestaurantsProvider)
                  .valueOrNull
                  ?.any((fav) => fav['id'] == id) ??
                  false;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 200,
                  child: RestaurantCard(
                    name: r['name'] ?? '',
                    cuisineType: r['cuisine_type'] ?? '',
                    address: r['address'] ?? '',
                    photoUrl: photos.isNotEmpty ? photos.first : null,
                    isFavorite: isFav,
                    showAiBadge: true,
                    onFavoriteTap: () => ref
                        .read(favoriteRestaurantsProvider.notifier)
                        .toggle(id),
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
