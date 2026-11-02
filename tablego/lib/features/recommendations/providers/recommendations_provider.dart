import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user_data_changes.dart';
import '../data/repositories/recommendations_repository.dart';
import '../domain/recommendation_models.dart';

/// Restaurants and dishes recommended to the client [userId].
///
/// Recomputed automatically whenever [userDataChangesProvider] is bumped
/// (favorites, profile preferences, orders), so no restart is needed.
final recommendationsProvider =
    FutureProvider.family<RecommendationResult, int>((ref, userId) {
  ref.watch(userDataChangesProvider);
  return ref.watch(recommendationsRepositoryProvider).getRecommendations(userId);
});
