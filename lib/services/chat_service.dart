import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lexguard_ai/core/constants/api_constants.dart';
import 'package:lexguard_ai/models/chat_model.dart';
import 'package:lexguard_ai/services/api_service.dart';

class ChatService {
  late final Dio _dio;

  ChatService() {
    _dio = ApiService().dio;
  }

  /// Sends a message to the AI with document context.
  /// Calls the multilingual chat endpoint which handles RAG + language selection.
  Future<ChatMessage> sendMessage(
    String documentId,
    String content, {
    String language = 'English',
    bool isVoice = false,
  }) async {
    final url = isVoice ? ApiConstants.voiceChat : ApiConstants.multilingualChat;
    debugPrint(
      '[ChatService] sendMessage → $url\n'
      '  document_id: $documentId\n'
      '  language: $language\n'
      '  message: ${content.length > 80 ? content.substring(0, 80) + "..." : content}',
    );

    try {
      final response = await _dio.post(
        url,
        data: {
          'document_id': documentId,
          'message': content,
          'language': language,
        },
      );

      debugPrint('[ChatService] Response status: ${response.statusCode}');
      debugPrint('[ChatService] Response keys: ${response.data?.keys?.toList()}');

      final data = response.data as Map<String, dynamic>? ?? {};

      if (data['success'] == true) {
        final contentText = isVoice
            ? (data['voice_ready_answer'] ?? data['answer'] ?? '')
            : (data['answer'] ?? '');

        if (contentText.isEmpty) {
          debugPrint('[ChatService] ⚠️ Backend returned success but answer is empty.');
          throw Exception('AI returned an empty response. Please try again.');
        }

        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: contentText,
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        );
      } else {
        final detail = data['detail'] ?? data['message'] ?? 'Unknown error from server';
        debugPrint('[ChatService] Backend returned success=false: $detail');
        throw Exception(detail);
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      String errorMsg;

      debugPrint('[ChatService] DioException: type=${e.type}, status=$statusCode');
      debugPrint('[ChatService] Response data: $responseData');

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMsg = 'Request timed out. The AI service may be slow — please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMsg = 'Cannot connect to the server. Check your internet connection.';
      } else if (statusCode == 400) {
        final detail = _extractDetail(responseData);
        errorMsg = detail.isNotEmpty ? detail : 'Document is not ready for chat yet. Please wait for analysis to complete.';
      } else if (statusCode == 401) {
        errorMsg = 'Session expired. Please log in again.';
      } else if (statusCode == 403) {
        errorMsg = 'You do not have permission to chat with this document.';
      } else if (statusCode == 404) {
        final detail = _extractDetail(responseData);
        errorMsg = detail.isNotEmpty ? detail : 'Document not found on the server.';
      } else if (statusCode == 500) {
        final detail = _extractDetail(responseData);
        errorMsg = detail.isNotEmpty ? 'Server error: $detail' : 'Internal server error. Please try again later.';
      } else {
        errorMsg = _extractDetail(responseData);
        if (errorMsg.isEmpty) errorMsg = 'Network error (${statusCode ?? e.type.name})';
      }

      debugPrint('[ChatService] Throwing mapped error: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      debugPrint('[ChatService] Unexpected error: $e');
      rethrow;
    }
  }

  /// Extracts the `detail` or `message` field from a Dio response body map.
  String _extractDetail(dynamic responseData) {
    if (responseData == null) return '';
    if (responseData is Map) {
      return (responseData['detail'] ?? responseData['message'] ?? '').toString();
    }
    if (responseData is String) return responseData;
    return '';
  }

  /// Fetches summary formatted/translated for TTS speech reading.
  Future<Map<String, dynamic>> getAudioSummary(String documentId, {String language = 'English'}) async {
    debugPrint('[ChatService] getAudioSummary: document=$documentId, language=$language');
    try {
      final response = await _dio.get(
        ApiConstants.summaryAudio(documentId),
        queryParameters: {'language': language},
      );
      if (response.data['success'] == true) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get audio summary');
      }
    } on DioException catch (e) {
      debugPrint('[ChatService] Audio Summary DioError: ${e.response?.data}');
      throw Exception(_extractDetail(e.response?.data).isNotEmpty
          ? _extractDetail(e.response?.data)
          : 'Network error during audio summary retrieval');
    }
  }

  /// Fetches chat history for a specific document from the backend.
  Future<List<ChatMessage>> getChatHistory(String documentId) async {
    debugPrint('[ChatService] getChatHistory: document=$documentId');
    try {
      final response = await _dio.get(ApiConstants.chatHistory(documentId));

      if (response.data['success'] == true) {
        final List history = response.data['history'] ?? [];
        debugPrint('[ChatService] Loaded ${history.length} chat history entries.');
        final List<ChatMessage> messages = [];
        for (var h in history) {
          final createdAt = h['created_at'] != null
              ? DateTime.tryParse(h['created_at']) ?? DateTime.now()
              : DateTime.now();
          messages.add(ChatMessage(
            id: '${h['id']}_q',
            content: h['query'] ?? '',
            sender: MessageSender.user,
            timestamp: createdAt,
          ));
          messages.add(ChatMessage(
            id: '${h['id']}_a',
            content: h['response'] ?? '',
            sender: MessageSender.ai,
            timestamp: createdAt,
          ));
        }
        return messages;
      }
      return [];
    } on DioException catch (e) {
      debugPrint('[ChatService] getChatHistory DioError: ${e.response?.statusCode} ${e.response?.data}');
      // Return empty list — history is not critical
      return [];
    } catch (e) {
      debugPrint('[ChatService] getChatHistory unexpected error: $e');
      return [];
    }
  }

  /// Clears chat history for a specific document.
  Future<bool> clearHistory(String documentId) async {
    debugPrint('[ChatService] clearHistory: document=$documentId');
    try {
      final response = await _dio.delete(ApiConstants.chatHistory(documentId));
      return response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint('[ChatService] clearHistory error: ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('[ChatService] clearHistory unexpected error: $e');
      return false;
    }
  }
}
