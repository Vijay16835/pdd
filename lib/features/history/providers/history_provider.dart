import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexguard_ai/models/document_model.dart';
import 'package:lexguard_ai/services/document_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

enum DocumentSortOption { date, type, status }

class HistoryProvider extends ChangeNotifier {
  final DocumentService _service = DocumentService();
  List<DocumentModel> _allDocuments = [];
  List<DocumentModel> _filteredDocuments = [];
  String _searchQuery = '';
  RiskLevel? _riskFilter;
  DocumentSortOption _sortOption = DocumentSortOption.date;
  
  bool _isLoading = false;
  bool _isOpening = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _errorMessage;
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

  List<DocumentModel> get documents => _filteredDocuments;
  bool get isLoading => _isLoading;
  bool get isOpening => _isOpening;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get searchQuery => _searchQuery;
  RiskLevel? get riskFilter => _riskFilter;
  DocumentSortOption get sortOption => _sortOption;
  String? get errorMessage => _errorMessage;

  HistoryProvider();

  Future<void> loadHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final result = await _service.getDocuments();
      if (result['success']) {
        final docsList = result['data']['documents'] as List<dynamic>? ?? [];
        _allDocuments = docsList.map((json) => DocumentModel.fromJson(json)).toList();
        _applyFilters();
      } else {
        _errorMessage = result['message'];
      }
    } catch (e) {
      _errorMessage = 'Failed to load history data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void setRiskFilter(RiskLevel? risk) {
    _riskFilter = risk;
    _applyFilters();
  }

  void setSortOption(DocumentSortOption option) {
    _sortOption = option;
    _applyFilters();
  }

  Future<bool> deleteDocument(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _service.deleteDocument(id);
      if (result['success']) {
        _allDocuments.removeWhere((d) => d.id == id);
        _applyFilters();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to delete document: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> downloadReport(String id, {String format = 'pdf'}) async {
    _isDownloading = true;
    _downloadProgress = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = _service.getExportUrl(id, format);
      final extension = format == 'markdown' || format == 'md' ? 'md' : format;
      final fileName = 'LexGuard_Analysis_$id.$extension';
      final result = await _service.downloadFileToDownloads(
        url,
        fileName,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = (received / total).clamp(0, 1);
            notifyListeners();
          }
        },
        expectedFormat: format,
      );

      if (!result.success) {
        _errorMessage = result.error ?? 'Unable to download report.';
        return null;
      }

      if (kIsWeb) {
        return result.path;
      }

      final file = File(result.path!);
      if (!file.existsSync()) {
        _errorMessage = 'Downloaded file is missing after save.';
        return null;
      }

      return result.path;
    } catch (e) {
      _errorMessage = 'Download failed: $e';
      return null;
    } finally {
      _isDownloading = false;
      _downloadProgress = 0;
      notifyListeners();
    }
  }

  Future<bool> openDocument(String path, {String? fileName}) async {
    _isOpening = true;
    notifyListeners();
    try {
      String filePath = path;

      if (kIsWeb) {
        if (path.startsWith('http')) {
          await launchUrl(Uri.parse(path));
          return true;
        }
        return false;
      }

      if (path.startsWith('http')) {
        final uri = Uri.parse(path);
        final fileNameFromUrl = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
        final chosenName = fileName ?? fileNameFromUrl ?? 'document';
        final downloadedPath = await _service.downloadFile(path, chosenName);
        if (downloadedPath == null) {
          return false;
        }
        filePath = downloadedPath;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    } finally {
      _isOpening = false;
      notifyListeners();
    }
  }

  void _applyFilters() {
    _filteredDocuments = _allDocuments.where((doc) {
      final matchesSearch = _searchQuery.isEmpty || 
          doc.name.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesRisk = _riskFilter == null || doc.riskLevel == _riskFilter;
      
      return matchesSearch && matchesRisk;
    }).toList();
    
    // Apply Sorting
    switch (_sortOption) {
      case DocumentSortOption.date:
        _filteredDocuments.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        break;
      case DocumentSortOption.type:
        _filteredDocuments.sort((a, b) => a.type.index.compareTo(b.type.index));
        break;
      case DocumentSortOption.status:
        _filteredDocuments.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }

    notifyListeners();
  }
}
