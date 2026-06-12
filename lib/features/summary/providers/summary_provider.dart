import 'package:flutter/material.dart';
import 'package:lexguard_ai/models/document_model.dart';
import 'package:lexguard_ai/models/summary_model.dart';
import 'package:lexguard_ai/services/chat_service.dart';

enum SummaryState { idle, processing, success, error }

class SummaryProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  SummaryState _state = SummaryState.idle;
  SummaryModel? _summary;
  String? _errorMessage;
  String _selectedLanguage = "English";

  SummaryState get state => _state;
  SummaryModel? get summary => _summary;
  String? get errorMessage => _errorMessage;
  String get selectedLanguage => _selectedLanguage;

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

  void clearSummary() {
    _state = SummaryState.idle;
    _summary = null;
    _errorMessage = null;
    _selectedLanguage = "English";
    notifyListeners();
  }

  Future<void> translateSummary(String lang) async {
    if (_summary == null) return;
    _state = SummaryState.processing;
    _selectedLanguage = lang;
    _errorMessage = null;
    notifyListeners();

    try {
      final audioSummaryData = await _chatService.getAudioSummary(_summary!.documentId, language: lang);
      final translatedSummaryText = audioSummaryData['summary_text'] ?? _summary!.shortSummary;
      
      _summary = SummaryModel(
        id: _summary!.id,
        documentId: _summary!.documentId,
        shortSummary: translatedSummaryText,
        keyClauses: _summary!.keyClauses,
        importantDates: _summary!.importantDates,
        partiesInvolved: _summary!.partiesInvolved,
        obligations: _summary!.obligations,
        recommendations: _summary!.recommendations,
        generatedAt: _summary!.generatedAt,
      );
      _state = SummaryState.success;
      notifyListeners();
    } catch (e) {
      _state = SummaryState.error;
      _errorMessage = 'Failed to translate summary: $e';
      notifyListeners();
    }
  }

  Future<void> generateSummary(DocumentModel document) async {
    _state = SummaryState.processing;
    _errorMessage = null;
    _selectedLanguage = "English";
    notifyListeners();

    try {
      // Try to get summary from audioSummary API if document is uploaded,
      // fallback to dummy/simulated data if it fails or has no backend.
      try {
        final data = await _chatService.getAudioSummary(document.id, language: "English");
        final summaryText = data['summary_text'];
        if (summaryText != null && summaryText.isNotEmpty) {
          _summary = SummaryModel(
            id: 'sum_${DateTime.now().millisecondsSinceEpoch}',
            documentId: document.id,
            shortSummary: summaryText,
            keyClauses: [
              'Review and analyze specific clauses in Chat or Risk sections',
            ],
            importantDates: [],
            partiesInvolved: [],
            obligations: [],
            recommendations: [],
            generatedAt: DateTime.now(),
          );
          _state = SummaryState.success;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('SummaryProvider: Backend getAudioSummary failed, using simulated data: $e');
      }

      await Future.delayed(const Duration(seconds: 2)); // Simulating AI processing time

      // Dummy implementation acting as backend response
      _summary = SummaryModel(
        id: 'sum_${DateTime.now().millisecondsSinceEpoch}',
        documentId: document.id,
        shortSummary: 'This document is a Non-Disclosure Agreement (NDA) outlining confidentiality obligations between the involved parties regarding proprietary technology.',
        keyClauses: [
          'Confidentiality Period: 5 years',
          'Exceptions to Confidential Information',
          'Return of Materials upon termination'
        ],
        importantDates: [
          'Effective Date: Oct 1, 2024',
          'Expiration Date: Oct 1, 2029'
        ],
        partiesInvolved: [
          'TechNova Solutions Inc. (Disclosing Party)',
          'Alex Johnson (Receiving Party)'
        ],
        obligations: [
          'Maintain absolute secrecy of technical schematics',
          'Do not reverse engineer the provided prototypes'
        ],
        recommendations: [
          'Review the definition of "Confidential Information" to ensure it is not overly broad',
          'Clarify the governing law jurisdiction'
        ],
        generatedAt: DateTime.now(),
      );

      _state = SummaryState.success;
      notifyListeners();
    } catch (e) {
      _state = SummaryState.error;
      _errorMessage = 'Failed to generate summary: $e';
      notifyListeners();
    }
  }
}
