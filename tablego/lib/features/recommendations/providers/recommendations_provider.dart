import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/repositories/recommendations_repository.dart';
import '../domain/recommendation_service.dart';

final recommendationsProvider =
    FutureProvider<List<ScoredRestaurant>>((ref) async {
  final userId = ref.watch(authProvider).user?.id;
  if (userId == null) return const [];
  return ref.watch(recommendationsRepositoryProvider).getRecommendations(userId);
});
