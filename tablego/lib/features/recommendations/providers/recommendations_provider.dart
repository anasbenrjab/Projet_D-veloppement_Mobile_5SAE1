import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/recommendations_repository.dart';

final recommendationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(recommendationsRepositoryProvider);
  return repo.getRecommendations();
});
