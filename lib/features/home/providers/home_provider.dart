import 'package:flutter/material.dart';
import 'package:lexguard_ai/models/document_model.dart';
import 'package:lexguard_ai/services/document_service.dart';

class HomeProvider extends ChangeNotifier {
  final DocumentService _service = DocumentService();
  List<DocumentModel> _recentDocuments = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Real Dynamic Stats calculated from actual documents
  int get totalDocuments => _recentDocuments.length;
  
  int get highRiskContracts => _recentDocuments
      .where((doc) => doc.riskLevel == RiskLevel.high)
      .length;
      
  int get pendingReviews => _recentDocuments
      .where((doc) => doc.status == DocumentStatus.pending || doc.status == DocumentStatus.analyzing)
      .length;
      
  double _aiAccuracy = 0.0;

  List<DocumentModel> get recentDocuments => _recentDocuments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get aiAccuracy => _aiAccuracy;

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

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getDocuments();
      if (result['success']) {
        final docsList = result['data']['documents'] as List<dynamic>? ?? [];
        _recentDocuments = docsList.map((json) => DocumentModel.fromJson(json)).toList();
        
        // Calculate AI Accuracy as success rate
        if (_recentDocuments.isEmpty) {
          _aiAccuracy = 0.0;
        } else {
          final completed = _recentDocuments.where((d) => d.status == DocumentStatus.completed).length;
          final failed = _recentDocuments.where((d) => d.status == DocumentStatus.failed).length;
          final totalProcessed = completed + failed;
          if (totalProcessed > 0) {
            _aiAccuracy = (completed / totalProcessed) * 100.0;
          } else {
            _aiAccuracy = 100.0;
          }
        }
      } else {
        _errorMessage = result['message'];
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load dashboard data. Please try again.';
      notifyListeners();
    }
  }

  void addDocument(DocumentModel document) {
    _recentDocuments.insert(0, document);
    notifyListeners();
  }

  void updateDocument(DocumentModel updatedDocument) {
    final index = _recentDocuments.indexWhere((doc) => doc.id == updatedDocument.id);
    if (index != -1) {
      _recentDocuments[index] = updatedDocument;
      notifyListeners();
    }
  }

  Future<bool> deleteDocument(String id) async {
    try {
      final result = await _service.deleteDocument(id);
      if (result['success']) {
        _recentDocuments.removeWhere((doc) => doc.id == id);
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to delete document: $e';
      notifyListeners();
      return false;
    }
  }
}
