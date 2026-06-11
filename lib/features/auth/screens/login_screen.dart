import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';
import 'package:lexguard_ai/widgets/common/custom_text_field.dart';
import 'package:lexguard_ai/widgets/common/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    debugPrint('[LoginScreen] Attempting login for ${_emailCtrl.text.trim()}');

    final auth = context.read<AuthProvider>();
    
    try {
      final success = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;

      if (success) {
        debugPrint('[LoginScreen] Login successful, navigating to /home');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Login failed. Please check your credentials.',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed due to a network or server error.',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    Widget formWidget = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isDesktop) ...[
            const SizedBox(height: 48),
            // Mobile Logo
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'LexGuard AI',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms),
            const SizedBox(height: 48),
          ],

          Text(
            'Welcome Back',
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 36 : 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.3, end: 0),

          const SizedBox(height: 8),

          Text(
            'Sign in to your legal intelligence platform',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ).animate(delay: 150.ms).fadeIn(),

          const SizedBox(height: 36),

          // Error Message Display
          Selector<AuthProvider, String?>(
            selector: (_, auth) => auth.errorMessage,
            builder: (context, errorMessage, _) {
              if (errorMessage == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: GoogleFonts.inter(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Email Input
          CustomTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 18),

          // Password Input
          CustomTextField(
            controller: _passCtrl,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textHint,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'Password must be at least 8 characters';
              if (utf8.encode(v).length > 72) return 'Password cannot exceed 72 bytes';
              return null;
            },
          ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          // Remember Me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Selector<AuthProvider, bool>(
                selector: (_, auth) => auth.rememberMe,
                builder: (context, rememberMe, _) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: rememberMe,
                          onChanged: (v) =>
                              context.read<AuthProvider>().setRememberMe(v ?? false),
                          activeColor: AppColors.gold,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember me',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ).animate(delay: 300.ms).fadeIn(),

          const SizedBox(height: 28),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Sign In',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or continue with',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.border)),
            ],
          ).animate(delay: 400.ms).fadeIn(),

          const SizedBox(height: 20),

          // Google Sign In Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                try {
                  final success = await auth.googleSignIn();
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          auth.errorMessage ?? 'Google Sign-In failed. Please try again.',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Google login error: $e');
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 32, color: AppColors.gold),
              label: Text(
                'Continue with Google',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ).animate(delay: 450.ms).fadeIn(),

          const SizedBox(height: 32),

          // Navigate to Sign Up
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/signup'),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 500.ms).fadeIn(),

          const SizedBox(height: 32),
        ],
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Selector<AuthProvider, bool>(
      selector: (_, auth) => auth.authState == AuthState.loading,
      builder: (context, isLoading, child) {
        return LoadingOverlay(
          isLoading: isLoading,
          child: child!,
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF080F1E), Color(0xFF0A1628)]
                  : const [Color(0xFFF5F7FA), Color(0xFFE5EAF2)],
            ),
          ),
          child: SafeArea(
            child: isDesktop
                ? Row(
                    children: [
                      // Left Column: Branding Showcase Panel
                      Expanded(
                        flex: 12,
                        child: Container(
                          padding: const EdgeInsets.all(60),
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: AppColors.border, width: 1)),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? const [Color(0xFF0F1C2E), Color(0xFF080F1E)]
                                  : const [Color(0xFFE5EAF2), Color(0xFFD0D7E5)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: AppColors.goldGradient),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.shield_rounded, color: AppColors.navy, size: 26),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'LexGuard AI',
                                    style: GoogleFonts.outfit(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 60),
                              Text(
                                'Enterprise-Grade\nLegal AI Assistant',
                                style: GoogleFonts.inter(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.15,
                                  letterSpacing: -1.0,
                                ),
                              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                              const SizedBox(height: 18),
                              Text(
                                'Auditing contracts, checking liabilities, and extracting key clauses instantly with natural language AI responses.',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ).animate(delay: 200.ms).fadeIn(),
                              const SizedBox(height: 60),
                              _FeatureRow(
                                icon: Icons.gpp_good_rounded,
                                title: 'Automated Risk Detection',
                                description: 'Flag potential liabilities, warning clauses, and compliance flaws in seconds.',
                              ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.1, end: 0),
                              const SizedBox(height: 24),
                              _FeatureRow(
                                icon: Icons.forum_rounded,
                                title: 'Natural Language Chat Context',
                                description: 'Chat directly with your legal documents to query terms, ask questions, and translate clauses.',
                              ).animate(delay: 400.ms).fadeIn().slideX(begin: -0.1, end: 0),
                              const SizedBox(height: 24),
                              _FeatureRow(
                                icon: Icons.summarize_rounded,
                                title: 'Premium Summarization & Formats',
                                description: 'Download summary reports in PDF, DOCX or TXT files tailored for instant reviews.',
                              ).animate(delay: 500.ms).fadeIn().slideX(begin: -0.1, end: 0),
                            ],
                          ),
                        ),
                      ),
                      // Right Column: Form Container Card
                      Expanded(
                        flex: 11,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 460),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SingleChildScrollView(child: formWidget),
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: formWidget,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: AppColors.gold, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
