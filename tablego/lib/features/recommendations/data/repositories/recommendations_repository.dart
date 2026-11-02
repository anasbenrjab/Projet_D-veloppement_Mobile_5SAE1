import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/recommendation_engine.dart';
import '../../domain/recommendation_models.dart';
import '../recommendation_data_source.dart';

/// Reads the data (through [RecommendationDataSource]) and runs the local
/// [RecommendationEngine].  No network, no API key: works offline on web
/// and mobile.
class RecommendationsRepository {
  RecommendationsRepository({
    DatabaseHelper? dbHelper,
    RecommendationDataSource? dataSource,
    this.engine = const RecommendationEngine(),
  }) : _source = dataSource ?? RecommendationDataSource(dbHelper: dbHelper);

  final RecommendationDataSource _source;
  final RecommendationEngine engine;

  /// Recommended restaurants and dishes for [userId].  [now] is the
  /// reference time for recency (defaults to the current time).
  Future<RecommendationResult> getRecommendations(
    int userId, {
    DateTime? now,
  }) async {
    final snapshot = await _source.load(userId);
    return engine.recommend(snapshot, now: now ?? DateTime.now().toUtc());
  }
}

final recommendationsRepositoryProvider =
    Provider<RecommendationsRepository>((_) => RecommendationsRepository());
