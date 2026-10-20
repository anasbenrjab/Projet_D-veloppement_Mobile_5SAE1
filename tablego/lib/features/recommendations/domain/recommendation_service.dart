import '../../data/models/restaurant_recommendation_model.dart';
import '../../../favorites/data/models/restaurant_summary_model.dart';

/// Minimal dish info needed only for scoring — no DB model dependency.
class DishForScoring {
  const DishForScoring({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.price,
    this.photoPath,
    this.tags = const [],
  });

  final int    id;
  final int    restaurantId;
  final String name;
  final double price;
  final String? photoPath;
  final List<String> tags;
}

/// Pure scoring logic ported from `recommendations.controller.js`.
///
/// No database access — all inputs are pre-loaded by [RecommendationsRepository].
/// Static method only so it is trivially unit-testable.
///
/// ## Scoring weights (identical to backend)
/// - +3 per past order at this restaurant
/// - +5 if the restaurant is in the user's favorites
/// - +2 per dish whose tags include a user dietary preference
///
/// ## Empty data behaviour
/// If [restaurants] is empty, returns [].
/// If all scores are 0 (no history / no prefs / no favorites), returns all
/// restaurants sorted alphabetically — a sensible default rather than an
/// arbitrary order.
class RecommendationService {
  RecommendationService._();

  static List<RestaurantRecommendationModel> score({
    required List<RestaurantSummaryModel> restaurants,
    required List<DishForScoring>         allDishes,
    required List<String>                 userPreferences,
    required Map<int, int>                orderFrequency,   // restaurantId → count
    required Set<int>                     favoriteIds,
  }) {
    if (restaurants.isEmpty) return const [];

    // Group dishes by restaurant for O(1) lookup.
    final dishesByRestaurant = <int, List<DishForScoring>>{};
    for (final d in allDishes) {
      dishesByRestaurant.putIfAbsent(d.restaurantId, () => []).add(d);
    }

    final scored = restaurants.map((r) {
      var s = 0;
      s += (orderFrequency[r.id] ?? 0) * 3;
      if (favoriteIds.contains(r.id)) s += 5;

      final rDishes = dishesByRestaurant[r.id] ?? [];
      for (final dish in rDishes) {
        for (final pref in userPreferences) {
          if (dish.tags.contains(pref)) s += 2;
        }
      }

      final matching = rDishes
          .where((d) => d.tags.any(userPreferences.contains))
          .take(3)
          .toList();

      return RestaurantRecommendationModel(
        restaurant:    r,
        score:         s,
        matchingDishes: matching,
      );
    }).toList();

    // Primary sort: score descending.
    // Secondary sort: name ascending (stable default when all scores are 0).
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    return scored.take(10).toList();
  }
}
