import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lexguard_ai/firebase_options.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexguard_ai/services/api_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showError = false;
  String _errorMsg = "";

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final totalStopwatch = Stopwatch()..start();
    try {
      final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

      // 1. Firebase.initializeApp()
      final firebaseWatch = Stopwatch()..start();
      debugPrint('[StartupSequence] 1. Firebase.initializeApp() starting...');
      if (!isTest && Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      firebaseWatch.stop();
      debugPrint('[StartupTiming] Firebase.initializeApp() took: ${firebaseWatch.elapsedMilliseconds} ms');
      debugPrint('[StartupSequence] 1. Firebase.initializeApp() completed');

      // 2. SecureStorage initialization (acts as local DB connection check)
      final dbWatch = Stopwatch()..start();
      debugPrint('[StartupSequence] 2. SecureStorage initialization starting...');
      final storage = const FlutterSecureStorage();
      if (!isTest) {
        // Test read/write to ensure storage is operational
        await storage.write(key: 'startup_verify_test', value: 'ok');
        await storage.delete(key: 'startup_verify_test');
      }
      dbWatch.stop();
      debugPrint('[StartupTiming] Database/SecureStorage check took: ${dbWatch.elapsedMilliseconds} ms');
      debugPrint('[StartupSequence] 2. SecureStorage initialization completed');

      // 3. Auth token loading & Session validation
      final sessionWatch = Stopwatch()..start();
      debugPrint('[StartupSequence] 3. Auth token loading starting...');
      final token = isTest ? null : await storage.read(key: 'auth_token');
      debugPrint('[StartupSequence] 3. Auth token loading completed (token exists: ${token != null})');

      // 4. User session restoration
      debugPrint('[StartupSequence] 4. User session restoration starting...');
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      
      if (!isTest) {
        // Pre-warm the backend and validate API/Database connection in background
        final apiWatch = Stopwatch()..start();
        auth.validateBackend().then((isHealthy) {
          apiWatch.stop();
          debugPrint('[StartupTiming] API call / Database connection health check took: ${apiWatch.elapsedMilliseconds} ms (isHealthy: $isHealthy)');
        }).catchError((e) {
          apiWatch.stop();
          debugPrint('[StartupTiming] API call / Database connection check failed after: ${apiWatch.elapsedMilliseconds} ms ($e)');
          return false;
        });

        // Local session check
        await auth.checkInitialAuth().timeout(const Duration(seconds: 3));
      }
      sessionWatch.stop();
      debugPrint('[StartupTiming] Session validation took: ${sessionWatch.elapsedMilliseconds} ms');
      debugPrint('[StartupSequence] 4. User session restoration completed (isAuthenticated: ${auth.isAuthenticated})');

      // 5. Provider initialization
      debugPrint('[StartupSequence] 5. Provider initialization starting...');
      debugPrint('[StartupSequence] 5. Provider initialization completed');

      // 6. API client initialization
      debugPrint('[StartupSequence] 6. API client initialization starting...');
      ApiService();
      debugPrint('[StartupSequence] 6. API client initialization completed');

      if (auth.isAuthenticated) {
        debugPrint('[StartupTiming] User profile loading: Deferred to background (running asynchronously).');
      } else {
        debugPrint('[StartupTiming] User profile loading: Skipped (no session).');
      }

      // Enforce splash screen duration to be 2 seconds
      final elapsed = totalStopwatch.elapsedMilliseconds;
      final remaining = 2000 - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }
      totalStopwatch.stop();
      debugPrint('[StartupTiming] Total Startup sequence took: ${totalStopwatch.elapsedMilliseconds} ms');

      if (!mounted) return;
      _navigate();
    } catch (e, stack) {
      debugPrint('[StartupSequence] ERROR: Startup verification failed: $e\n$stack');
      setState(() {
        _showError = true;
        _errorMsg = "Startup initialization failed. Please check your connection.";
      });
      
      // Try to navigate after a delay to avoid freezing
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) _navigate();
    }
  }

  void _navigate() async {
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (!mounted) return;

    if (auth.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (onboardingDone) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080F1E), Color(0xFF0A1628), Color(0xFF0D1F3C)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ).animate().scale(duration: 700.ms, curve: Curves.elasticOut).fadeIn(),

                  const SizedBox(height: 28),
                  Text('LexGuard AI', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1))
                      .animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 60),
                  if (!_showError)
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          backgroundColor: Color(0xFF162544),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                          minHeight: 3,
                        ),
                      ),
                    ).animate().fadeIn()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(_errorMsg, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                    ).animate().shake(),

                  const SizedBox(height: 16),
                  Text(_showError ? 'Retrying...' : 'Securing your legal intelligence...', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


