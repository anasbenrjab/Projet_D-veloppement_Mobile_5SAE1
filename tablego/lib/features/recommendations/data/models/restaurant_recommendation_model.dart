import '../../domain/recommendation_service.dart';
import '../../../favorites/data/models/restaurant_summary_model.dart';

/// A restaurant enriched with a recommendation score and matching dishes.
///
/// Returned by [RecommendationService.score] and surfaced through
/// [RecommendationsRepository] → provider → UI.
class RestaurantRecommendationModel {
  const RestaurantRecommendationModel({
    required this.restaurant,
    required this.score,
    this.matchingDishes = const [],
  });

  final RestaurantSummaryModel restaurant;

  /// Composite relevance score (see [RecommendationService] for weights).
  final int score;

  /// Up to 3 dishes whose tags match the user's dietary preferences.
  final List<DishForScoring> matchingDishes;

  // Convenience forwarding accessors — avoid repeated .restaurant. in widgets.
  int    get id          => restaurant.id;
  String get name        => restaurant.name;
  String get address     => restaurant.address;
  String get cuisineType => restaurant.cuisineType;
  String get favoritedAt => restaurant.favoritedAt;
  String? get firstPhotoPath => restaurant.firstPhotoPath;
}
