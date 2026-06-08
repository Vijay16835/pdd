import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexguard_ai/core/constants/api_constants.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        // Render free-tier cold starts can take 30–50 s — timeouts must exceed that.
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ── Debug: log every outgoing request URL ──────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('[ApiService] --> ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '[ApiService] <-- ${response.statusCode} ${response.requestOptions.uri}',
          );
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          debugPrint(
            '[ApiService] ERR ${e.response?.statusCode ?? e.type} '
            '${e.requestOptions.uri}',
          );
          return handler.next(e);
        },
      ),
    );

    // ── JWT injection ──────────────────────────────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          const storage = FlutterSecureStorage();
          final token = await storage.read(key: 'auth_token');
          if (token != null) {
            debugPrint('[ApiService] JWT injected for: ${options.uri}');
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            debugPrint('[ApiService] No JWT for: ${options.uri}');
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            debugPrint('[ApiService] 401 Unauthorized: ${e.requestOptions.uri}');
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      } else {
        return "Server error: ${e.response?.statusCode}";
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return "Connection timed out. Please check your internet connection.";
    } else if (e.type == DioExceptionType.connectionError) {
      return "No internet connection or server unreachable.";
    } else if (e.type == DioExceptionType.unknown) {
      final message = e.message;
      if (message != null && message.isNotEmpty) {
        return message;
      }
      return "No internet connection or server unreachable.";
    }
    return "Something went wrong";
  }
}
