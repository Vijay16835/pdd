import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';

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
    try {
      final auth = context.read<AuthProvider>();
      
      // Start both the auth check and a minimum delay timer
      // We also add a timeout to ensure we never hang forever
      await Future.wait([
        auth.checkInitialAuth().catchError((e) {
          debugPrint("Auth check failed: $e");
        }),
        Future.delayed(const Duration(milliseconds: 2500)),
      ]).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      _navigate();
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _showError = true;
        _errorMsg = "Taking longer than usual. Please check your connection.";
      });
      
      // Even if there's an error, we try to navigate after a delay to avoid freezing
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
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: AppColors.goldGradient),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 5)],
                    ),
                    child: const Icon(Icons.shield_outlined, size: 58, color: AppColors.navy),
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


