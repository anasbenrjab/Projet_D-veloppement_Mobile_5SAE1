import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class RecommendationsRepository {
  RecommendationsRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getRecommendations() async {
    final res = await _dio.get(ApiEndpoints.recommendations);
    return (res.data['recommendations'] as List)
        .cast<Map<String, dynamic>>();
  }
}

final recommendationsRepositoryProvider =
    Provider<RecommendationsRepository>(
  (ref) => RecommendationsRepository(ref.watch(dioProvider)),
);
