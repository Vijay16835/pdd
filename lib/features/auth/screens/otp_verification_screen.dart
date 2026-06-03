import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final bool isPasswordReset;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  int _timerSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    for (var node in _focusNodes) {
      node.addListener(() {
        setState(() {});
      });
    }
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        setState(() => timer.cancel());
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    String otp = _controllers.map((e) => e.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit code'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    bool success = false;
    
    debugPrint('Request started');
    try {
      if (widget.isPasswordReset) {
        success = await auth.verifyResetOtp(widget.email, otp);
      } else {
        success = await auth.verifyOtp(widget.email, otp);
      }
      debugPrint('Response received');
      
      if (!mounted) return;

      if (success) {
        if (widget.isPasswordReset) {
          // Navigate to Reset Password Screen (where they enter new password)
          Navigator.pushReplacementNamed(
            context, 
            '/reset-password', 
            arguments: {'email': widget.email, 'otp': otp}
          );
        } else {
          // Registration success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Auto-login and go to Dashboard
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Invalid or expired OTP'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Exception thrown');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred during verification.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      debugPrint('Loading closed');
    }
  }

  void _resendOtp() async {
    final auth = context.read<AuthProvider>();
    bool success = false;
    
    debugPrint('Request started');
    try {
      if (widget.isPasswordReset) {
        success = await auth.sendResetOtp(widget.email).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[OTP_VERIFICATION] Resend timeout exceeded');
            throw TimeoutException('Connection timed out. The server is taking too long to respond.');
          },
        );
      } else {
        success = await auth.sendOtp(widget.email).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[OTP_VERIFICATION] Resend timeout exceeded');
            throw TimeoutException('Connection timed out. The server is taking too long to respond.');
          },
        );
      }
      debugPrint('Response received');
      
      if (!mounted) return;

      if (success) {
        setState(() {
          _timerSeconds = 60;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code resent!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Failed to resend code'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Exception thrown');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      debugPrint('Loading closed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.goldGlow, shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.gold),
            ),
            const SizedBox(height: 24),
            Text('Verify your email', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Text('We sent a 6-digit code to ${widget.email}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _otpBox(index)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: context.watch<AuthProvider>().authState == AuthState.loading
                    ? const CircularProgressIndicator(color: AppColors.navy)
                    : Text('Verify Code', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Didn't receive code? ", style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                TextButton(
                  onPressed: _timerSeconds == 0 ? _resendOtp : null,
                  child: Text(
                    _timerSeconds == 0 ? 'Resend' : 'Resend in ${_timerSeconds}s',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _timerSeconds == 0 ? AppColors.gold : AppColors.textHint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    bool isFocused = _focusNodes[index].hasFocus;
    return Container(
      width: 48,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardDark, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: isFocused ? AppColors.gold : AppColors.border, width: isFocused ? 2 : 1)
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          decoration: const InputDecoration(
            counterText: "", 
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            if (index == 5 && value.isNotEmpty) {
              // Unfocus to dismiss keyboard before verifying
              _focusNodes[index].unfocus();
              _verifyOtp();
            }
          },
        ),
      ),
    );
  }
}
