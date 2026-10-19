import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get(ApiEndpoints.profile);
    return res.data as Map<String, dynamic>;
  }

  Future<void> updateClientProfile({
    String? fullName,
    String? phone,
    List<String>? dietaryPreferences,
    List<String>? allergies,
  }) async {
    await _dio.put(ApiEndpoints.clientProfile, data: {
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (dietaryPreferences != null)
        'dietary_preferences': dietaryPreferences,
      if (allergies != null) 'allergies': allergies,
    });
  }

  Future<void> updateRestaurantProfile({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? openingHours,
    String? cuisineType,
    String? description,
  }) async {
    await _dio.put(ApiEndpoints.restaurantProfile, data: {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (openingHours != null) 'opening_hours': openingHours,
      if (cuisineType != null) 'cuisine_type': cuisineType,
      if (description != null) 'description': description,
    });
  }

  Future<String> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath,
          filename: filePath.split('/').last),
    });
    final res = await _dio.post(
      ApiEndpoints.uploadPhoto,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data['photo_url'] as String;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);
