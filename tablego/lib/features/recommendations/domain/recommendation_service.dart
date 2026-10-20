import '../../favorites/data/models/restaurant_summary_model.dart';

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

/// Result of scoring one restaurant.
class ScoredRestaurant {
  const ScoredRestaurant({
    required this.restaurant,
    required this.score,
    this.matchingDishes = const [],
  });

  final RestaurantSummaryModel restaurant;
  final int score;
  final List<DishForScoring> matchingDishes;

  // Convenience forwarding getters so widgets never need to drill into .restaurant.
  int    get id           => restaurant.id;
  String get name         => restaurant.name;
  String get address      => restaurant.address;
  String get cuisineType  => restaurant.cuisineType;
  String? get firstPhotoPath => restaurant.firstPhotoPath;
}

/// Pure scoring logic — no DB access, fully unit-testable.
///
/// Ported verbatim from `tablego-backend/src/controllers/recommendations.controller.js`.
///
/// ## Weights
/// - +3 per past order at this restaurant
/// - +5 if the restaurant is in the user's favorites
/// - +2 per dish whose tags contain a user dietary preference
///
/// ## Default order
/// When all scores are 0 (no history, no prefs, no favorites), restaurants
/// are returned alphabetically by name rather than in an arbitrary order.
class RecommendationService {
  RecommendationService._();

  static List<ScoredRestaurant> score({
    required List<RestaurantSummaryModel> restaurants,
    required List<DishForScoring>         allDishes,
    required List<String>                 userPreferences,
    required Map<int, int>                orderFrequency,
    required Set<int>                     favoriteIds,
  }) {
    if (restaurants.isEmpty) return const [];

    // Group dishes by restaurant for O(1) lookup.
    final dishesByRestaurant = <int, List<DishForScoring>>{};
    for (final d in allDishes) {
      dishesByRestaurant.putIfAbsent(d.restaurantId, () => []).add(d);
    }

    final List<ScoredRestaurant> scored = restaurants.map((r) {
      var s = 0;
      s += (orderFrequency[r.id] ?? 0) * 3;
      if (favoriteIds.contains(r.id)) s += 5;

      final rDishes = dishesByRestaurant[r.id] ?? <DishForScoring>[];
      for (final dish in rDishes) {
        for (final pref in userPreferences) {
          if (dish.tags.contains(pref)) s += 2;
        }
      }

      final matching = rDishes
          .where((d) => d.tags.any(userPreferences.contains))
          .take(3)
          .toList();

      return ScoredRestaurant(
        restaurant:     r,
        score:          s,
        matchingDishes: matching,
      );
    }).toList();

    // Primary: score descending. Secondary: name ascending (stable default).
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    return scored.take(10).toList();
  }
}
