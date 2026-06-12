import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';
import 'package:lexguard_ai/widgets/common/custom_text_field.dart';
import 'package:lexguard_ai/widgets/common/loading_overlay.dart';
import 'package:lexguard_ai/features/auth/screens/otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEmailNotRegistered = false;

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    
    debugPrint('[FORGOT_PASSWORD] Button clicked');
    setState(() {
      _isLoading = true;
      _isEmailNotRegistered = false;
    });

    final email = _emailCtrl.text.trim();
    debugPrint('Request started');
    
    try {
      final auth = context.read<AuthProvider>();
      
      // Perform authentication check with 10s maximum timeout
      final success = await auth.sendResetOtp(email).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[FORGOT_PASSWORD] Timeout exceeded');
          throw TimeoutException('Connection timed out. The server is taking too long to respond.');
        },
      );
      
      debugPrint('Response received');

      if (success) {
        debugPrint('[FORGOT_PASSWORD] Success');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully to your registered email.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: email,
                isPasswordReset: true,
              ),
            ),
          );
        }
      } else {
        debugPrint('[FORGOT_PASSWORD] Failure');
        if (mounted) {
          final errorMsg = auth.errorMessage ?? '';
          if (errorMsg.toLowerCase().contains('not registered') || errorMsg.toLowerCase().contains('not found')) {
            setState(() {
              _isEmailNotRegistered = true;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(auth.errorMessage ?? 'Failed to send OTP. Please try again.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'RETRY',
                  textColor: Colors.white,
                  onPressed: _sendReset,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Exception thrown');
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.toLowerCase().contains('not registered') || errorMsg.toLowerCase().contains('not found')) {
          setState(() {
            _isEmailNotRegistered = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: _sendReset,
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Loading closed');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LoadingOverlay(
      isLoading: _isLoading,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(Icons.arrow_back_ios_new,
                            size: 18, color: AppColors.textPrimary),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.goldGlow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.lock_reset_outlined,
                          color: AppColors.gold, size: 38),
                    ).animate().scale(curve: Curves.elasticOut),

                    const SizedBox(height: 28),

                    Text(
                      'Forgot Password?',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.3, end: 0),

                    const SizedBox(height: 10),

                    Text(
                      "Enter your email and we'll send a 6-digit verification code to reset your password.",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ).animate(delay: 150.ms).fadeIn(),

                    const SizedBox(height: 40),

                    if (_isEmailNotRegistered) ...[
                      // Show: "Email not registered. Please create an account."
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Email not registered. Please create an account.',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'The email address "${_emailCtrl.text.trim()}" is not registered. Please create a new account or log in with a different email.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(),

                      const SizedBox(height: 32),

                      // Display two actions: Register Now and Back to Login
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context); // Go back to login screen
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Back to Login',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // Redirect to registration page and prefill email
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/signup',
                                  arguments: {'email': _emailCtrl.text.trim()},
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.navy,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Register Now',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(),

                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isEmailNotRegistered = false;
                            });
                          },
                          child: Text(
                            'Try another email',
                            style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(),
                    ] else ...[
                      CustomTextField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        hint: 'Enter your registered email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email is required';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ).animate(delay: 200.ms).fadeIn(),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _sendReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Send OTP',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ).animate(delay: 250.ms).fadeIn(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
