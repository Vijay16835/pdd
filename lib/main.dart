import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lexguard_ai/firebase_options.dart';
import 'package:lexguard_ai/core/theme/app_theme.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';
import 'package:lexguard_ai/features/home/providers/home_provider.dart';
import 'package:lexguard_ai/features/upload/providers/upload_provider.dart';
import 'package:lexguard_ai/features/upload/providers/document_provider.dart';
import 'package:lexguard_ai/features/analysis/providers/analysis_provider.dart';
import 'package:lexguard_ai/features/chat/providers/chat_provider.dart';
import 'package:lexguard_ai/features/history/providers/history_provider.dart';
import 'package:lexguard_ai/features/profile/providers/profile_provider.dart';
import 'package:lexguard_ai/features/summary/providers/summary_provider.dart';
import 'package:lexguard_ai/features/auth/screens/splash_screen.dart';
import 'package:lexguard_ai/features/auth/screens/onboarding_screen.dart';
import 'package:lexguard_ai/features/auth/screens/login_screen.dart';
import 'package:lexguard_ai/features/auth/screens/signup_screen.dart';
import 'package:lexguard_ai/features/auth/screens/forgot_password_screen.dart';
import 'package:lexguard_ai/features/home/screens/main_shell.dart';
import 'package:lexguard_ai/features/analysis/screens/analysis_screen.dart';
import 'package:lexguard_ai/features/chat/screens/chat_screen.dart';
import 'package:lexguard_ai/features/clauses/screens/clauses_screen.dart';
import 'package:lexguard_ai/features/profile/screens/settings_screen.dart';
import 'package:lexguard_ai/features/auth/screens/otp_verification_screen.dart';
import 'package:lexguard_ai/features/auth/screens/reset_password_screen.dart';
import 'package:lexguard_ai/services/tts_service.dart';
import 'package:lexguard_ai/services/stt_service.dart';
import 'package:lexguard_ai/features/language/providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    } else {
      debugPrint('Firebase already initialized');
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Pre-load SharedPreferences to avoid MaterialApp theme rebuild flickers
  String? initialThemeMode;
  bool? initialIsDarkMode;
  try {
    final prefs = await SharedPreferences.getInstance();
    initialThemeMode = prefs.getString('themeMode');
    if (initialThemeMode == null) {
      initialIsDarkMode = prefs.getBool('isDarkMode');
    }
  } catch (e) {
    debugPrint('SharedPreferences loading failed in main(): $e');
  }

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.navBar,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(LexGuardApp(
    initialThemeMode: initialThemeMode,
    initialIsDarkMode: initialIsDarkMode,
  ));
}

class LexGuardApp extends StatelessWidget {
  final String? initialThemeMode;
  final bool? initialIsDarkMode;

  const LexGuardApp({
    super.key,
    this.initialThemeMode,
    this.initialIsDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => UploadProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(
            initialThemeMode: initialThemeMode,
            initialIsDarkMode: initialIsDarkMode,
          ),
        ),
        ChangeNotifierProvider(create: (_) => SummaryProvider()),
        ChangeNotifierProvider(create: (_) => TtsService()),
        ChangeNotifierProvider(create: (_) => SttService()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Selector<ProfileProvider, bool>(
        selector: (_, profile) => profile.isDarkMode,
        builder: (context, isDarkMode, _) {
          AppColors.setDarkMode(isDarkMode);
          return MaterialApp(
            title: 'LexGuard AI',
            debugShowCheckedModeBanner: false,
            theme: isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/otp-verification': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                return OtpVerificationScreen(
                  email: args['email'],
                  isPasswordReset: args['purpose'] == 'password_reset',
                );
              },
              '/reset-password': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                return ResetPasswordScreen(
                  email: args['email'],
                  otp: args['otp'],
                );
              },
              '/home': (context) => const MainShell(child: SizedBox.shrink()),
              '/analysis': (context) => const AnalysisScreen(),
              '/chat': (context) => const ChatScreen(),
              '/clauses': (context) => const ClausesScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
            builder: (context, child) {
              return child ?? const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}
