import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = "";
  String _currentLocaleId = "en_US";

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  SttService();

  Future<void> _initStt() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'listening') {
            _isListening = true;
          } else {
            _isListening = false;
          }
          notifyListeners();
        },
        onError: (errorVal) {
          _isListening = false;
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (e) {
      debugPrint("STT Initialization Error: $e");
    }
  }

  Future<void> startListening({
    required Function(String) onResult,
    String? language,
  }) async {
    if (!_isAvailable) {
      await _initStt();
    }

    if (_isAvailable && !_isListening) {
      _lastWords = "";
      String locale = _mapLanguageToLocale(language ?? "English");
      _currentLocaleId = locale;

      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          onResult(_lastWords);
          notifyListeners();
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: _currentLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
        ),
      );
      _isListening = true;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  String _mapLanguageToLocale(String language) {
    switch (language.toLowerCase()) {
      case 'tamil': return 'ta_IN';
      case 'hindi': return 'hi_IN';
      case 'telugu': return 'te_IN';
      case 'malayalam': return 'ml_IN';
      case 'kannada': return 'kn_IN';
      case 'french': return 'fr_FR';
      case 'spanish': return 'es_ES';
      case 'german': return 'de_DE';
      case 'arabic': return 'ar_AE';
      case 'english':
      default:
        return 'en_US';
    }
  }
}
