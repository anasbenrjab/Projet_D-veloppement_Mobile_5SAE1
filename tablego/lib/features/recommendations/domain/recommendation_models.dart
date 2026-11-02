import '../../favorites/data/models/restaurant_summary_model.dart';

// ── Input: what the engine reads ──────────────────────────────────────────────
// Built by RecommendationDataSource; plain Dart so the engine can be tested
// without a database.

/// The target client's dietary constraints, as canonical labels
/// (see `FoodLabels`).
class RecoClientProfile {
  const RecoClientProfile({
    required this.userId,
    this.diets = const {},
    this.allergens = const {},
  });

  final int userId;
  final Set<String> diets;
  final Set<String> allergens;
}

/// A dish as seen by the recommender.
class RecoDish {
  const RecoDish({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.price,
    this.description,
    this.photoPath,
    this.isAvailable = true,
    this.tags = const {},
    this.allergens,
  });

  final int id;
  final int restaurantId;
  final String name;
  final String? description;
  final double price;
  final String? photoPath;
  final bool isAvailable;

  /// Canonical diet tags (`halal`, `vegetarien`, …).
  final Set<String> tags;

  /// Canonical allergens, or null when the menu does not declare them.
  final Set<String>? allergens;
}

/// What a client did.  Orders carry a restaurant and usually a dish;
/// favorites carry one or the other.
enum InteractionKind { order, favoriteDish, favoriteRestaurant }

class RecoInteraction {
  const RecoInteraction({
    required this.userId,
    required this.kind,
    this.restaurantId,
    this.dishId,
    this.at,
  });

  final int userId;
  final InteractionKind kind;
  final int? restaurantId;
  final int? dishId;

  /// When it happened (order date, or when the favorite was added).
  final DateTime? at;
}

/// Everything the engine needs for one client, read in one go.
class RecommendationSnapshot {
  const RecommendationSnapshot({
    required this.profile,
    required this.restaurants,
    required this.dishes,
    required this.interactions,
  });

  /// The target client (empty constraints when the profile row is missing).
  final RecoClientProfile profile;

  /// Active restaurants.
  final List<RestaurantSummaryModel> restaurants;

  /// All dishes, available or not (unavailable ones still describe tastes).
  final List<RecoDish> dishes;

  /// Interactions of every active client, the target included.
  final List<RecoInteraction> interactions;
}

// ── Output ────────────────────────────────────────────────────────────────────

/// The three signals behind a score, each in [0, 1].
class ScoreBreakdown {
  const ScoreBreakdown({
    this.content = 0,
    this.collaborative = 0,
    this.popularity = 0,
  });

  /// Cosine similarity between the client's taste and the item.
  final double content;

  /// Item-based collaborative filtering ("clients who like X like Y").
  final double collaborative;

  /// Share of interactions from other clients, relative to the most popular.
  final double popularity;
}

class RestaurantRecommendation {
  const RestaurantRecommendation({
    required this.restaurant,
    required this.score,
    required this.breakdown,
    required this.reasons,
    required this.compatibleDishCount,
  });

  final RestaurantSummaryModel restaurant;
  final double score;
  final ScoreBreakdown breakdown;

  /// Short French explanations, most important first.
  final List<String> reasons;

  /// Dishes of this restaurant that pass the client's hard filters.
  final int compatibleDishCount;

  String get explanation => reasons.join(' · ');
}

class DishRecommendation {
  const DishRecommendation({
    required this.dish,
    required this.restaurantName,
    required this.score,
    required this.breakdown,
    required this.reasons,
  });

  final RecoDish dish;
  final String restaurantName;
  final double score;
  final ScoreBreakdown breakdown;

  /// Short French explanations, most important first.
  final List<String> reasons;

  String get explanation => reasons.join(' · ');
}

class RecommendationResult {
  const RecommendationResult({
    this.restaurants = const [],
    this.dishes = const [],
    this.coldStart = false,
  });

  final List<RestaurantRecommendation> restaurants;
  final List<DishRecommendation> dishes;

  /// True when the client had no order or favorite: popularity fallback.
  final bool coldStart;

  bool get isEmpty => restaurants.isEmpty && dishes.isEmpty;
}
