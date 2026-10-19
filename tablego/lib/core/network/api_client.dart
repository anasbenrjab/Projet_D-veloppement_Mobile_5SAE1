import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Android emulator → 10.0.2.2, iOS sim / web → localhost
String get _baseUrl {
  if (kIsWeb) return 'http://localhost:3000/api';
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3000/api'
      : 'http://localhost:3000/api';
}

const _storage = FlutterSecureStorage();

Dio _buildDio() {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  // Attach JWT on every request
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('[API Error] ${error.requestOptions.path}: ${error.message}');
        handler.next(error);
      },
    ),
  );
  return dio;
}

final dioProvider = Provider<Dio>((ref) => _buildDio());

/// Convenience methods for token management
class AuthStorage {
  static Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt_token', value: token);

  static Future<String?> getToken() => _storage.read(key: 'jwt_token');

  static Future<void> deleteToken() => _storage.delete(key: 'jwt_token');

  static Future<bool> hasToken() async {
    final t = await _storage.read(key: 'jwt_token');
    return t != null && t.isNotEmpty;
  }
}
