import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/home/screens/home_screen.dart';
import 'package:lexguard_ai/features/history/screens/history_screen.dart';
import 'package:lexguard_ai/features/chat/screens/chat_screen.dart';
import 'package:lexguard_ai/features/profile/screens/profile_screen.dart';
import 'package:lexguard_ai/features/upload/screens/upload_screen.dart';
import 'package:provider/provider.dart';
import 'package:lexguard_ai/features/profile/providers/profile_provider.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';
import 'package:lexguard_ai/widgets/common/desktop_design_system.dart';
import 'package:lexguard_ai/widgets/common/theme_selection_modal.dart';
import 'package:lexguard_ai/features/profile/screens/notification_settings_modal.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;

  final _screens = const [
    HomeScreen(),
    HistoryScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  void _onNavTap(int index) {
    if (index == 1) {
      // Upload tap — navigate/push to full upload screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadScreen()),
      );
      return;
    }
    // Map sidebar/nav index back to screen index
    final screenIndex = index < 2 ? index : index - 1;
    setState(() => _currentIndex = screenIndex);
  }

  String _getSectionTitle(int screenIndex) {
    switch (screenIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Document History';
      case 2:
        return 'AI Assistant Chat';
      case 3:
        return 'Profile & Settings';
      default:
        return 'LexGuard AI';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    // Map screen index back to nav index for active indicator
    final navIndex = _currentIndex < 1 ? _currentIndex : _currentIndex + 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            AppSidebar(
              currentIndex: navIndex,
              onNavTap: _onNavTap,
              isCollapsed: _isSidebarCollapsed,
              onToggleCollapse: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              },
              userName: user?.firstName ?? 'User',
              userInitials: user?.initials ?? 'US',
              userPlan: user?.subscriptionPlan ?? 'Free',
            ),
            Expanded(
              child: Column(
                children: [
                  AppTopBar(
                    title: _getSectionTitle(_currentIndex),
                    actions: [
                      // Theme Selector Button
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const ThemeSelectionModal(),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: Icon(
                              profile.themeMode == ThemeMode.system
                                  ? Icons.brightness_auto_outlined
                                  : profile.themeMode == ThemeMode.dark
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      // Notification Bell
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const NotificationSettingsModal(),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(Icons.notifications_outlined,
                                    color: AppColors.textPrimary, size: 20),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // User Initials Avatar link to profile screen tab
                      GestureDetector(
                        onTap: () => setState(() => _currentIndex = 3),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: AppColors.goldGradient),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              user?.initials ?? 'US',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: IndexedStack(
                          index: _currentIndex,
                          children: _screens,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile fallback (standard bottom nav bar layout)
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: navIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBar,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', index: 0, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle_rounded, label: 'Upload', index: 1, currentIndex: currentIndex, onTap: onTap, isUpload: true),
              _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History', index: 2, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble_rounded, label: 'Chat', index: 3, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile', index: 4, currentIndex: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;
  final bool isUpload;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.isUpload = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;

    if (isUpload) {
      return GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.goldGradient),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)],
          ),
          child: const Icon(Icons.add, color: AppColors.navy, size: 28),
        ),
      );
    }

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.goldGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: isActive ? AppColors.gold : AppColors.textHint, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.gold : AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}
