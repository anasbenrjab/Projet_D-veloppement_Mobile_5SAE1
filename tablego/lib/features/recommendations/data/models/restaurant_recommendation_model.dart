import '../../domain/recommendation_service.dart';

/// Wraps [ScoredRestaurant] with convenience accessors for the UI layer.
///
/// This is a thin re-export so widgets never need to import the domain layer
/// directly.
typedef RestaurantRecommendationModel = ScoredRestaurant;
