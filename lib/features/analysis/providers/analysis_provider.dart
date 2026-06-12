import 'package:flutter/material.dart';
import 'package:lexguard_ai/models/analysis_model.dart';


class AnalysisProvider extends ChangeNotifier {
  AnalysisModel? _analysis;
  bool _isLoading = false;
  String? _errorMessage;

  AnalysisModel? get analysis => _analysis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<void> loadAnalysis(String documentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    _analysis = AnalysisModel.dummy;
    _isLoading = false;
    notifyListeners();
  }

  void clearAnalysis() {
    _analysis = null;
    notifyListeners();
  }
}
