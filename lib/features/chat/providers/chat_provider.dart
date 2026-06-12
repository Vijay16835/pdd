import 'package:flutter/material.dart';
import 'package:lexguard_ai/models/chat_model.dart';
import 'package:lexguard_ai/services/chat_service.dart';
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _errorMessage;
  String? _currentDocumentId;
  String? _currentDocumentName;
  final _uuid = const Uuid();

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  String? get errorMessage => _errorMessage;
  String? get currentDocumentId => _currentDocumentId;
  String? get currentDocumentName => _currentDocumentName;
  bool get hasDocumentContext => _currentDocumentId != null;

  String _selectedLanguage = "English";
  bool _isVoiceResponseEnabled = false;

  String get selectedLanguage => _selectedLanguage;
  bool get isVoiceResponseEnabled => _isVoiceResponseEnabled;

  void setSelectedLanguage(String lang) {
    _selectedLanguage = lang;
    notifyListeners();
  }

  void setVoiceResponseEnabled(bool val) {
    _isVoiceResponseEnabled = val;
    notifyListeners();
  }

  /// Sets the document context for chat. Preserves [documentName] if not explicitly provided.
  void setDocumentContext(String documentId, {String? documentName}) {
    debugPrint('[ChatProvider] setDocumentContext: id=$documentId, name=$documentName');
    _currentDocumentId = documentId;
    // Only overwrite documentName if a non-null value is explicitly passed
    if (documentName != null) {
      _currentDocumentName = documentName;
    }
    _errorMessage = null;
    loadHistory();
  }

  Future<void> loadHistory() async {
    if (_currentDocumentId == null) {
      debugPrint('[ChatProvider] loadHistory: no document context, skipping.');
      _errorMessage = null;
      notifyListeners();
      return;
    }

    debugPrint('[ChatProvider] loadHistory: loading for document=$_currentDocumentId');
    _isTyping = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final history = await _chatService.getChatHistory(_currentDocumentId!);
      _messages.clear();
      _messages.addAll(history);
      debugPrint('[ChatProvider] loadHistory: loaded ${history.length} messages.');
    } catch (e) {
      debugPrint('[ChatProvider] loadHistory failed (non-fatal): $e');
      // Don't set error — history is optional, don't block chat
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content, {Function(String)? onAiResponse}) async {
    if (content.trim().isEmpty) return;

    if (_currentDocumentId == null) {
      _errorMessage = 'Please select a document to chat with first';
      debugPrint('[ChatProvider] sendMessage: no document context set.');
      notifyListeners();
      return;
    }

    debugPrint('[ChatProvider] sendMessage: document=$_currentDocumentId, message="${content.length > 60 ? content.substring(0, 60) + "..." : content}"');

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      content: content,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    _isTyping = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final aiMsg = await _chatService.sendMessage(
        _currentDocumentId!,
        content,
        language: _selectedLanguage,
        isVoice: _isVoiceResponseEnabled,
      );
      _messages.add(aiMsg);
      _errorMessage = null;
      debugPrint('[ChatProvider] sendMessage: AI responded successfully.');
      if (onAiResponse != null) {
        onAiResponse(aiMsg.content);
      }
    } catch (e) {
      final errorText = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[ChatProvider] sendMessage error: $errorText');

      // Set the specific error message from the backend/network
      _errorMessage = errorText;

      // Add a user-visible error message bubble
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: _buildErrorBubbleText(errorText),
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Builds a user-friendly error message for the chat bubble.
  String _buildErrorBubbleText(String errorText) {
    // Specific known errors → friendly messages
    if (errorText.contains('not yet available') || errorText.contains('analysis to complete')) {
      return '⏳ This document is still being analyzed. Please wait a moment and try again.';
    }
    if (errorText.contains('not found')) {
      return '❌ Document not found. Please go back and reopen the document.';
    }
    if (errorText.contains('Session expired') || errorText.contains('401')) {
      return '🔒 Your session has expired. Please log out and log in again.';
    }
    if (errorText.contains('timed out') || errorText.contains('timeout')) {
      return '⏱️ The request timed out. The AI is processing — please try again in a moment.';
    }
    if (errorText.contains('Cannot connect') || errorText.contains('internet')) {
      return '📶 No internet connection. Please check your network and try again.';
    }
    if (errorText.contains('permission')) {
      return '🚫 You do not have permission to chat with this document.';
    }
    // Generic fallback
    return '⚠️ Something went wrong. Please try again.\n\nDetails: $errorText';
  }

  Future<void> clearChat() async {
    debugPrint('[ChatProvider] clearChat: document=$_currentDocumentId');
    if (_currentDocumentId != null) {
      try {
        await _chatService.clearHistory(_currentDocumentId!);
      } catch (e) {
        debugPrint('[ChatProvider] clearChat error (non-fatal): $e');
      }
    }
    _messages.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
