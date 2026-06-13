import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';
import 'package:lexguard_ai/features/profile/providers/profile_provider.dart';
import 'package:lexguard_ai/features/profile/screens/privacy_policy_screen.dart';
import 'package:lexguard_ai/features/profile/screens/about_screen.dart';
import 'package:lexguard_ai/features/profile/screens/settings_screen.dart';
import 'package:lexguard_ai/features/profile/screens/edit_profile_screen.dart';
import 'package:lexguard_ai/widgets/common/desktop_design_system.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Immediate refresh on open
      context.read<AuthProvider>().refreshStats();
      // Auto-refresh every 30 seconds so storage stays in sync
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) context.read<AuthProvider>().refreshStats();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    context.watch<ProfileProvider>(); 
    final user = auth.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    // Statistics Row
    Widget statsRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(label: 'Documents', value: '${user?.documentsAnalyzed ?? 0}'),
        Container(width: 1, height: 36, color: AppColors.border),
        _StatItem(label: 'High Risk', value: '${user?.highRiskCount ?? 0}'),
        Container(width: 1, height: 36, color: AppColors.border),
        _StatItem(label: 'AI Chats', value: '${user?.aiChatCount ?? 0}'),
      ],
    );

    // Storage Usage Indicator
    Widget storageWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Storage Usage', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(
              '${user?.storageUsedMB.toStringAsFixed(1) ?? '0.0'} MB / ${user?.storageLimitMB.toStringAsFixed(0) ?? '20'} MB',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: user?.storagePercentage ?? 0.0,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            minHeight: 6,
          ),
        ),
        if (user != null && user.storageUsedMB >= user.storageLimitMB) ...[  
          const SizedBox(height: 8),
          Text(
            'Storage limit reached. Delete files to continue.',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );

    // Account Summary Details Card
    Widget accountCard = DashboardCard(
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.goldGradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.gold.withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 2)
              ],
              image: user?.avatarUrl != null
                  ? DecorationImage(image: NetworkImage(user!.avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: user?.avatarUrl == null
                ? Center(
                    child: Text(
                      user?.initials ?? 'U',
                      style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navy),
                    ),
                  )
                : null,
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'User',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (user?.createdAt != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textHint),
                const SizedBox(width: 6),
                Text(
                  'Joined ${_formatMemberSince(user!.createdAt)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.goldGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⭐ ${user?.subscriptionPlan ?? 'Pro'} Plan',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          statsRow,
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          storageWidget,
        ],
      ),
    );

    // List of configuration items
    Widget menuItems = Column(
      children: [
        _MenuItem(
          icon: Icons.person_outline,
          label: 'Edit Profile',
          subtitle: 'Update your account name and avatar info',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
        ),
        _MenuItem(
          icon: Icons.settings_outlined,
          label: 'System Settings',
          subtitle: 'Configure dark mode and sound alerts',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        _MenuItem(
          icon: Icons.security_outlined,
          label: 'Change Password',
          subtitle: 'Keep your login credentials secure',
          onTap: () => _showChangePasswordModal(context),
        ),
        _MenuItem(
          icon: Icons.credit_card_outlined,
          label: 'Billing & Plan',
          subtitle: 'Manage invoices and active subscriptions',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription coming soon!')));
          },
        ),
        _MenuItem(
          icon: Icons.help_outline_rounded,
          label: 'Help & Technical Support',
          subtitle: 'File issues or contact engineering',
          onTap: () => _launchSupportEmail(context),
        ),
        _MenuItem(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          subtitle: 'Review document retention policies',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
        ),
        _MenuItem(
          icon: Icons.info_outline_rounded,
          label: 'About LexGuard AI',
          subtitle: 'Release metadata & information',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            label: Text(
              'Sign Out of Session',
              style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );

    if (isDesktop) {
      // Desktop Premium Two-Column Layout
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Account Profile & Storage metrics
              Expanded(
                flex: 5,
                child: accountCard.animate().fadeIn(duration: 400.ms),
              ),
              const SizedBox(width: 28),
              // Right Column: Settings configuration buttons
              Expanded(
                flex: 7,
                child: menuItems.animate(delay: 150.ms).fadeIn(),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile Layout fallback
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header gradient for mobile
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E3A6E), Color(0xFF0A1628)]),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.goldGradient),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 3)],
                          image: user?.avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(user!.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user?.avatarUrl == null
                            ? Center(child: Text(user?.initials ?? 'U', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.navy)))
                            : null,
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 14),

                      Text(user?.name ?? 'User', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary))
                          .animate(delay: 100.ms).fadeIn(),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                          .animate(delay: 150.ms).fadeIn(),
                      const SizedBox(height: 6),
                      if (user?.createdAt != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textHint),
                            const SizedBox(width: 5),
                            Text(
                              'Member since ${_formatMemberSince(user!.createdAt)}',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
                            ),
                          ],
                        ).animate(delay: 175.ms).fadeIn(),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.goldGradient), borderRadius: BorderRadius.circular(20)),
                        child: Text('⭐ ${user?.subscriptionPlan ?? 'Pro'} Plan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy)),
                      ).animate(delay: 200.ms).fadeIn(),
                    ],
                  ),
                ),
              ),
            ),

            // Mobile stats bar overlay
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: statsRow,
                ),
              ),
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.3, end: 0),

            // Mobile storage meter
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: storageWidget,
              ),
            ).animate(delay: 150.ms).fadeIn(),

            // Mobile list items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: menuItems,
            ).animate(delay: 200.ms).fadeIn(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  static String _formatMemberSince(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  static Future<void> _launchSupportEmail(BuildContext context) async {
    const address = 'tvijay1098@gmail.com';
    const subject = 'LexGuard AI Support Request';
    const body = 'Name:\nIssue:\nSteps to reproduce:';

    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email app found. Please email tvijay1098@gmail.com')),
      );
    }
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.changePassword(
      _currentController.text,
      _newController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password changed successfully!', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = authProvider.errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err, style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AppColors.highRisk,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Change Password', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            
            Text('Current Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                hint: 'Enter current password',
                icon: Icons.lock_outline,
                isPassword: true,
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Current password required';
                if (val.length < 8) return 'Password must be at least 8 characters';
                if (utf8.encode(val).length > 72) return 'Password cannot exceed 72 bytes';
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text('New Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newController,
              obscureText: _obscureNew,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                hint: 'Enter new password',
                icon: Icons.lock_outline,
                isPassword: true,
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'New password required';
                if (val.length < 8) return 'Password must be at least 8 characters';
                if (utf8.encode(val).length > 72) return 'Password cannot exceed 72 bytes';
                return null;
              },
            ),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2))
                  : Text('Update Password', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, bool isPassword = false, bool obscure = true, VoidCallback? onToggle}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: isPassword 
          ? IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textHint, size: 20), onPressed: onToggle)
          : null,
      filled: true,
      fillColor: AppColors.cardDark,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.gold)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.navyAccent, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.gold, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ]),
        ),
      ),
    );
  }
}
