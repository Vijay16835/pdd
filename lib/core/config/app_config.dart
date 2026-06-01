import 'package:flutter/foundation.dart';

enum AppFlavor { development, staging, production }

class AppConfig {
  // -----------------------------------------------------------------------
  // Render production backend — all environments point here.
  // To restore local dev: change _kRenderBaseUrl to 'http://10.0.2.2:8000/api/v1'
  // -----------------------------------------------------------------------
  static const String _kRenderBaseUrl = 'https://pdd-uw63.onrender.com/api/v1';

  static const String flavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'development');

  static AppFlavor get environment {
    switch (flavor.toLowerCase()) {
      case 'production':
        return AppFlavor.production;
      case 'staging':
        return AppFlavor.staging;
      default:
        return AppFlavor.development;
    }
  }

  static bool get isProduction => environment == AppFlavor.production;

  static String get apiBaseUrl {
    debugPrint('[AppConfig] apiBaseUrl -> $_kRenderBaseUrl');
    return _kRenderBaseUrl;
  }
}