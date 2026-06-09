import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';

enum NotificationMode { silent, vibrate, ring }

class ProfileProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  // Notification Settings
  NotificationMode _notificationMode = NotificationMode.vibrate;
  bool _pushNotifications = true;
  bool _aiAnalysisAlerts = true;
  bool _highRiskAlerts = true;
  bool _uploadSuccessAlerts = true;
  
  String _aiModel = 'LexGuard AI Engine v2.0';
  String _analysisDepth = 'Comprehensive';
  
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.dark:
        return 'Dark Theme';
      case ThemeMode.light:
        return 'Light Theme';
    }
  }

  bool get notificationsEnabled => _notificationsEnabled;
  String get selectedLanguage => _selectedLanguage;
  String get aiModel => _aiModel;
  String get analysisDepth => _analysisDepth;
  
  NotificationMode get notificationMode => _notificationMode;
  bool get pushNotifications => _pushNotifications;
  bool get aiAnalysisAlerts => _aiAnalysisAlerts;
  bool get highRiskAlerts => _highRiskAlerts;
  bool get uploadSuccessAlerts => _uploadSuccessAlerts;
  bool get isLoading => _isLoading;

  ProfileProvider({String? initialThemeMode, bool? initialIsDarkMode}) {
    WidgetsBinding.instance.addObserver(this);
    if (initialThemeMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == initialThemeMode, 
        orElse: () => ThemeMode.system
      );
    } else if (initialIsDarkMode != null) {
      _themeMode = initialIsDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
    AppColors.setDarkMode(isDarkMode);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      AppColors.setDarkMode(isDarkMode);
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final modeString = prefs.getString('themeMode');
    if (modeString != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == modeString, 
        orElse: () => ThemeMode.system
      );
    } else {
      final oldIsDark = prefs.getBool('isDarkMode');
      if (oldIsDark != null) {
        _themeMode = oldIsDark ? ThemeMode.dark : ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
    }

    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _selectedLanguage = prefs.getString('selectedLanguage') ?? 'English';
    _aiModel = prefs.getString('aiModel') ?? 'LexGuard AI Engine v2.0';
    _analysisDepth = prefs.getString('analysisDepth') ?? 'Comprehensive';

    _pushNotifications = prefs.getBool('pushNotifications') ?? true;
    _aiAnalysisAlerts = prefs.getBool('aiAnalysisAlerts') ?? true;
    _highRiskAlerts = prefs.getBool('highRiskAlerts') ?? true;
    _uploadSuccessAlerts = prefs.getBool('uploadSuccessAlerts') ?? true;
    
    final modeStringNotif = prefs.getString('notificationMode');
    if (modeStringNotif != null) {
      _notificationMode = NotificationMode.values.firstWhere(
        (e) => e.toString() == modeStringNotif, 
        orElse: () => NotificationMode.vibrate
      );
    }
    // Sync the static AppColors flag so widgets built before first
    // notifyListeners() already get the correct colour palette.
    AppColors.setDarkMode(isDarkMode);
    notifyListeners();
  }

  Future<void> _saveSettingsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    await prefs.setString('themeMode', _themeMode.name);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setString('selectedLanguage', _selectedLanguage);
    await prefs.setString('aiModel', _aiModel);
    await prefs.setString('analysisDepth', _analysisDepth);

    await prefs.setBool('pushNotifications', _pushNotifications);
    await prefs.setBool('aiAnalysisAlerts', _aiAnalysisAlerts);
    await prefs.setBool('highRiskAlerts', _highRiskAlerts);
    await prefs.setBool('uploadSuccessAlerts', _uploadSuccessAlerts);
    await prefs.setString('notificationMode', _notificationMode.toString());
  }

  Future<void> syncSettingsToBackend() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Placeholder for FastAPI + PostgreSQL backend sync
      // await dio.post('/user/settings', data: toJson());
      await Future.delayed(const Duration(milliseconds: 800));
      await _saveSettingsLocal();
    } catch (e) {
      debugPrint('Failed to sync settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    AppColors.setDarkMode(isDarkMode); // sync colour palette immediately
    notifyListeners();
    await _saveSettingsLocal();
    // Do background sync without blocking UI
    try {
      // Placeholder for FastAPI + PostgreSQL backend sync
      // await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('Failed to sync settings: $e');
    }
  }

  void toggleDarkMode(bool value) {
    setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  void toggleNotifications(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
    syncSettingsToBackend();
  }

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
    syncSettingsToBackend();
  }

  void setAiModel(String model) {
    _aiModel = model;
    notifyListeners();
    syncSettingsToBackend();
  }

  void setAnalysisDepth(String depth) {
    _analysisDepth = depth;
    notifyListeners();
    syncSettingsToBackend();
  }

  Future<void> logout() async {
    // Placeholder for backend logout
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    // Placeholder for backend account deletion (PostgreSQL)
    // await dio.delete('/user/account');
    await Future.delayed(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  void updateNotificationMode(NotificationMode mode) {
    _notificationMode = mode;
    notifyListeners();
    syncSettingsToBackend();
  }

  void togglePushNotifications(bool value) {
    _pushNotifications = value;
    if (!value) {
      _aiAnalysisAlerts = false;
      _highRiskAlerts = false;
      _uploadSuccessAlerts = false;
    }
    notifyListeners();
    syncSettingsToBackend();
  }

  void toggleAiAnalysisAlerts(bool value) {
    _aiAnalysisAlerts = value;
    notifyListeners();
    syncSettingsToBackend();
  }

  void toggleHighRiskAlerts(bool value) {
    _highRiskAlerts = value;
    notifyListeners();
    syncSettingsToBackend();
  }

  void toggleUploadSuccessAlerts(bool value) {
    _uploadSuccessAlerts = value;
    notifyListeners();
    syncSettingsToBackend();
  }
}
