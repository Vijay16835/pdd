import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lexguard_ai/services/document_service.dart';

class DocumentProvider extends ChangeNotifier {
  final DocumentService _service = DocumentService();

  List<Map<String, dynamic>> _documents = [];
  bool _isDisposed = false;
  final List<Timer> _activeTimers = [];

  @override
  void dispose() {
    _isDisposed = true;
    for (final t in _activeTimers) {
      t.cancel();
    }
    _activeTimers.clear();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
  Map<String, dynamic>? _currentDocument;
  Map<String, dynamic>? _currentAnalysis;
  List<Map<String, dynamic>> _currentClauses = [];
  List<Map<String, dynamic>> _chatMessages = [];

  bool _isLoading = false;
  bool _isUploading = false;
  bool _isChatting = false;
  String? _errorMessage;
  String? _uploadingDocId;

  // Getters
  List<Map<String, dynamic>> get documents => _documents;
  Map<String, dynamic>? get currentDocument => _currentDocument;
  Map<String, dynamic>? get currentAnalysis => _currentAnalysis;
  List<Map<String, dynamic>> get currentClauses => _currentClauses;
  List<Map<String, dynamic>> get chatMessages => _chatMessages;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get isChatting => _isChatting;
  String? get errorMessage => _errorMessage;
  String? get uploadingDocId => _uploadingDocId;

  /// Upload a document and start polling for analysis status
  Future<Map<String, dynamic>?> uploadDocument(PlatformFile file) async {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.uploadDocument(file);
      if (result['success']) {
        final docData = result['data']['document'];
        _uploadingDocId = docData['id'];
        // Add to local list immediately
        _documents.insert(0, docData);
        notifyListeners();

        // Start polling for analysis status
        _pollAnalysisStatus(docData['id']);

        _isUploading = false;
        notifyListeners();
        return docData;
      } else {
        _errorMessage = result['message'];
        _isUploading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Upload failed: $e';
      _isUploading = false;
      notifyListeners();
      return null;
    }
  }

  /// Poll analysis status every 3 seconds
  void _pollAnalysisStatus(String docId) {
    late Timer timer;
    timer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (_isDisposed) {
        t.cancel();
        _activeTimers.remove(t);
        return;
      }
      final result = await _service.getDocumentStatus(docId);
      if (_isDisposed) {
        t.cancel();
        _activeTimers.remove(t);
        return;
      }
      if (result['success']) {
        final status = result['data']['status'];

        // Update document in list
        final index = _documents.indexWhere((d) => d['id'] == docId);
        if (index != -1) {
          _documents[index]['status'] = status;
          _documents[index]['risk_score'] = result['data']['risk_score'];
          _documents[index]['risk_level'] = result['data']['risk_level'];
          notifyListeners();
        }

        if (status == 'completed' || status == 'failed') {
          t.cancel();
          _activeTimers.remove(t);
          _uploadingDocId = null;
          // Refresh full document list
          await fetchDocuments();
        }
      } else {
        t.cancel();
        _activeTimers.remove(t);
      }
    });
    _activeTimers.add(timer);
  }

  /// Fetch all documents
  Future<void> fetchDocuments() async {
    _isLoading = true;
    notifyListeners();

    final result = await _service.getDocuments();
    if (result['success']) {
      _documents = List<Map<String, dynamic>>.from(
        result['data']['documents'] ?? [],
      );
    } else {
      _errorMessage = result['message'];
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Fetch document details with analysis
  Future<void> fetchDocumentDetail(String documentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _service.getDocumentDetail(documentId);
    if (result['success']) {
      _currentDocument = result['data']['document'];
      _currentAnalysis = result['data']['analysis'];
      _currentClauses = List<Map<String, dynamic>>.from(
        result['data']['clauses'] ?? [],
      );
    } else {
      _errorMessage = result['message'];
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Send a chat message about a document
  Future<String?> sendChatMessage(String documentId, String query) async {
    _isChatting = true;
    notifyListeners();

    // Add user message immediately
    _chatMessages.add({
      'role': 'user',
      'content': query,
      'timestamp': DateTime.now().toIso8601String(),
    });
    notifyListeners();

    final result = await _service.chatWithDocument(documentId, query);
    if (result['success']) {
      final answer = result['data']['answer'];
      _chatMessages.add({
        'role': 'assistant',
        'content': answer,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _isChatting = false;
      notifyListeners();
      return answer;
    } else {
      _chatMessages.add({
        'role': 'assistant',
        'content': 'Sorry, I encountered an error. Please try again.',
        'timestamp': DateTime.now().toIso8601String(),
      });
      _isChatting = false;
      notifyListeners();
      return null;
    }
  }

  /// Load chat history for a document
  Future<void> loadChatHistory(String documentId) async {
    final result = await _service.getChatHistory(documentId);
    if (result['success']) {
      _chatMessages = [];
      final history = result['data']['history'] ?? [];
      for (var chat in history) {
        // Backend returns {id, query, response, created_at}
        _chatMessages.add({
          'role': 'user',
          'content': chat['query'],
          'timestamp': chat['created_at'],
        });
        _chatMessages.add({
          'role': 'assistant',
          'content': chat['response'],
          'timestamp': chat['created_at'],
        });
      }
      notifyListeners();
    }
  }

  /// Clear chat messages
  void clearChat() {
    _chatMessages = [];
    notifyListeners();
  }

  /// Delete a document
  Future<bool> deleteDocument(String documentId) async {
    final result = await _service.deleteDocument(documentId);
    if (result['success']) {
      _documents.removeWhere((d) => d['id'] == documentId);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Get export report URL for a document
  String getExportUrl(String documentId) {
    return '${_service.getBaseUrl()}/documents/$documentId/export';
  }

  /// Clear current document
  void clearCurrentDocument() {
    _currentDocument = null;
    _currentAnalysis = null;
    _currentClauses = [];
    _chatMessages = [];
    notifyListeners();
  }
}
