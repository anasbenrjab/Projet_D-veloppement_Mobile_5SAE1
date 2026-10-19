import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<({UserModel user, String token})> register({
    required String email,
    required String password,
    required String userType,
  }) async {
    final res = await _dio.post(ApiEndpoints.register, data: {
      'email': email,
      'password': password,
      'user_type': userType,
    });
    final token = res.data['token'] as String;
    final user = UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    await AuthStorage.saveToken(token);
    return (user: user, token: token);
  }

  Future<({UserModel user, String token})> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
    });
    final token = res.data['token'] as String;
    final user = UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    await AuthStorage.saveToken(token);
    return (user: user, token: token);
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post(ApiEndpoints.resetPassword, data: {
      'token': token,
      'new_password': newPassword,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.put(ApiEndpoints.changePassword, data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> deleteAccount() async {
    await _dio.delete(ApiEndpoints.deleteAccount);
    await AuthStorage.deleteToken();
  }

  Future<void> logout() => AuthStorage.deleteToken();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
