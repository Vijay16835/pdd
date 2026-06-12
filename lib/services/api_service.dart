import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexguard_ai/core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  late Dio _dio;

  factory ApiService() {
    return _instance;
  }

  Dio get dio => _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        // Increased to 45s to handle backend cold starts (Render free tier spin-up)
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
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

  Future<Response> _executeWithRetry(
    Future<Response> Function() request, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    required bool isIdempotent,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await request();
      } on DioException catch (e) {
        // Do not retry non-idempotent operations (POST, PUT, DELETE, etc.)
        if (!isIdempotent) {
          rethrow;
        }

        // Only retry on network timeout/error or 5xx server issues
        final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            (e.type == DioExceptionType.unknown && e.error is! FormatException);

        final isServerError = e.response != null &&
            e.response!.statusCode != null &&
            e.response!.statusCode! >= 500;

        if (attempts >= maxRetries || (!isNetworkError && !isServerError)) {
          rethrow;
        }

        final delay = initialDelay * (1 << (attempts - 1)); // Exponential delay: 1s, 2s, 4s...
        debugPrint('[ApiService] Request failed. Retrying in ${delay.inSeconds}s (Attempt $attempts of $maxRetries)...');
        await Future.delayed(delay);
      }
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options, ProgressCallback? onReceiveProgress}) async {
    try {
      return await _executeWithRetry(
        () => _dio.get(path, queryParameters: queryParameters, options: options, onReceiveProgress: onReceiveProgress),
        isIdempotent: true,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Options? options}) async {
    try {
      return await _executeWithRetry(
        () => _dio.post(path, data: data, options: options),
        isIdempotent: false,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _executeWithRetry(
        () => _dio.put(path, data: data),
        isIdempotent: false,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _executeWithRetry(
        () => _dio.delete(path),
        isIdempotent: false,
      );
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
