import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lexguard_ai/core/constants/api_constants.dart';
import 'package:lexguard_ai/core/utils/file_download_helper.dart';

class DownloadResult {
  final String? path;
  final String? error;

  const DownloadResult({this.path, this.error});

  bool get success => path != null;
}

class DocumentService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  DocumentService() {
    _dio = Dio(BaseOptions(
      // Increased to 45s to handle backend cold starts (Render free tier spin-up)
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 60),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  /// Get the base URL for constructing download URLs
  String getBaseUrl() => ApiConstants.baseUrl;

  /// Upload a document file
  Future<Map<String, dynamic>> uploadDocument(File file) async {
    try {
      String fileName = kIsWeb ? file.path.split('/').last : file.path.split(Platform.pathSeparator).last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post(
        ApiConstants.uploadDocument,
        data: formData,
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Upload failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Upload failed: $e'};
    }
  }

  /// Get all documents for current user
  Future<Map<String, dynamic>> getDocuments() async {
    try {
      final response = await _dio.get(ApiConstants.documentHistory);
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to fetch documents',
      };
    }
  }

  /// Get document details with analysis
  Future<Map<String, dynamic>> getDocumentDetail(String documentId) async {
    try {
      final response = await _dio.get(ApiConstants.documentDetail(documentId));
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to fetch document',
      };
    }
  }

  /// Poll document analysis status
  Future<Map<String, dynamic>> getDocumentStatus(String documentId) async {
    try {
      final response = await _dio.get(ApiConstants.documentStatus(documentId));
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Status check failed',
      };
    }
  }

  /// Delete a document
  Future<Map<String, dynamic>> deleteDocument(String documentId) async {
    try {
      final response = await _dio.delete(ApiConstants.documentDetail(documentId));
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Delete failed',
      };
    }
  }

  /// Chat with a document
  Future<Map<String, dynamic>> chatWithDocument(String documentId, String query) async {
    try {
      final response = await _dio.post(
        ApiConstants.aiChat,
        data: {'document_id': documentId, 'message': query},
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Chat failed',
      };
    }
  }

  /// Get chat history for a document
  Future<Map<String, dynamic>> getChatHistory(String documentId) async {
    try {
      final response = await _dio.get(ApiConstants.chatHistory(documentId));
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to fetch chat history',
      };
    }
  }

  /// Generate AI summary
  Future<Map<String, dynamic>> getSummary(String documentId) async {
    try {
      final response = await _dio.post(ApiConstants.documentSummary(documentId));
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Summary failed',
      };
    }
  }

  /// Get risk analysis
  Future<Map<String, dynamic>> getRiskAnalysis(String documentId) async {
    try {
      final response = await _dio.post(ApiConstants.riskAnalysis(documentId));
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Risk analysis failed',
      };
    }
  }

  Future<bool> _requestAndroidStoragePermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;

    if (await Permission.storage.isGranted) {
      return true;
    }

    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) {
      return true;
    }

    final manageResult = await Permission.manageExternalStorage.request();
    return manageResult.isGranted;
  }

  Future<Directory> _getDownloadDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Download directory not available on Web');
    }
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (externalDirs != null && externalDirs.isNotEmpty) {
        return externalDirs.first;
      }
    }

    return await getApplicationDocumentsDirectory();
  }

  /// Download a file at the provided URL into a temporary cache.
  Future<String?> downloadFile(String url, String fileName) async {
    try {
      if (kIsWeb) {
        return url;
      }
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final file = File(savePath);
      await file.create(recursive: true);
      await file.writeAsBytes(response.data as List<int>);
      return file.path;
    } on DioException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<DownloadResult> downloadFileToDownloads(
    String url,
    String fileName, {
    ProgressCallback? onReceiveProgress,
    String expectedFormat = 'pdf',
  }) async {
    try {
      if (kIsWeb) {
        final response = await _dio.get(
          url,
          options: Options(responseType: ResponseType.bytes, validateStatus: (status) => status != null && status < 400),
          onReceiveProgress: onReceiveProgress,
        );
        final bytes = response.data as List<int>?;
        if (bytes == null || bytes.isEmpty) {
          return const DownloadResult(error: 'Received empty file response from server.');
        }
        await saveAndLaunchFile(bytes, fileName);
        return const DownloadResult(path: 'Browser downloads folder');
      }

      if (!await _requestAndroidStoragePermission()) {
        return const DownloadResult(error: 'Permission denied to save files.');
      }

      final dir = await _getDownloadDirectory();
      final savePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes, validateStatus: (status) => status != null && status < 400),
        onReceiveProgress: onReceiveProgress,
      );

      final mimeType = response.headers.value('content-type');
      if (mimeType != null && mimeType.toLowerCase().contains('application/json')) {
        final errorMessage = response.data is String
            ? response.data
            : response.data is Map
                ? response.data['detail'] ?? response.data['message'] ?? response.statusMessage
                : response.statusMessage;
        return DownloadResult(error: 'Export failed: ${errorMessage ?? 'Unexpected JSON response'}');
      }

      if (!_isAllowedMimeType(mimeType, expectedFormat)) {
        if (mimeType != null) {
          return DownloadResult(error: 'Unexpected MIME type: $mimeType');
        }
      }

      final bytes = response.data as List<int>?;
      if (bytes == null || bytes.isEmpty) {
        return const DownloadResult(error: 'Received empty file response from server.');
      }

      final file = File(savePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return DownloadResult(path: file.path);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final serverMessage = e.response?.data is Map ? e.response?.data['detail'] ?? e.response?.data['message'] : e.response?.statusMessage;
      return DownloadResult(error: 'Network error${status != null ? ' ($status)' : ''}: ${serverMessage ?? e.message}');
    } catch (e) {
      return DownloadResult(error: 'Download failed: $e');
    }
  }

  bool _isAllowedMimeType(String? mimeType, String format) {
    if (mimeType == null) return false;
    final normalized = mimeType.toLowerCase();

    if (normalized.contains('application/octet-stream')) {
      return true;
    }

    switch (format.toLowerCase()) {
      case 'pdf':
        return normalized.contains('application/pdf');
      case 'docx':
      case 'doc':
        return normalized.contains('application/vnd.openxmlformats-officedocument.wordprocessingml.document') ||
            normalized.contains('application/msword');
      case 'txt':
        return normalized.contains('text/plain');
      case 'md':
      case 'markdown':
        return normalized.contains('text/markdown') || normalized.contains('text/plain');
      default:
        return true;
    }
  }

  /// Get export report URL
  String getExportUrl(String documentId, [String format = 'pdf']) {
    return ApiConstants.exportReport(documentId, format);
  }
}
