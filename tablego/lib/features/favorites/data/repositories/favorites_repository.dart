import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class FavoritesRepository {
  FavoritesRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getFavoriteRestaurants() async {
    final res = await _dio.get(ApiEndpoints.favoriteRestaurants);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> addFavoriteRestaurant(int id) =>
      _dio.post('${ApiEndpoints.favoriteRestaurants}/$id');

  Future<void> removeFavoriteRestaurant(int id) =>
      _dio.delete('${ApiEndpoints.favoriteRestaurants}/$id');

  Future<List<Map<String, dynamic>>> getFavoriteDishes() async {
    final res = await _dio.get(ApiEndpoints.favoriteDishes);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> addFavoriteDish(int id) =>
      _dio.post('${ApiEndpoints.favoriteDishes}/$id');

  Future<void> removeFavoriteDish(int id) =>
      _dio.delete('${ApiEndpoints.favoriteDishes}/$id');
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(dioProvider)),
);
