import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/home/providers/home_provider.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';
import 'package:lexguard_ai/features/profile/providers/profile_provider.dart';
import 'package:lexguard_ai/widgets/common/theme_selection_modal.dart';
import 'package:lexguard_ai/core/utils/date_time_utils.dart';

import 'package:lexguard_ai/widgets/cards/document_card.dart';
import 'package:lexguard_ai/widgets/cards/stat_card.dart';
import 'package:lexguard_ai/features/upload/screens/upload_screen.dart';
import 'package:lexguard_ai/features/analysis/screens/analysis_screen.dart';
import 'package:lexguard_ai/features/chat/screens/chat_screen.dart';
import 'package:lexguard_ai/features/summary/screens/summary_screen.dart';
import 'package:lexguard_ai/features/profile/screens/profile_screen.dart';
import 'package:lexguard_ai/features/profile/screens/notification_settings_modal.dart';
import 'package:lexguard_ai/widgets/common/desktop_design_system.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('[StartupSequence] 7. Home screen rendering starting...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadDashboard();
      debugPrint('[StartupSequence] 7. Home screen rendering completed (rendered successfully)');
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final user = auth.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    // Loading overlay or error state handling
    Widget errorWidget = Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(home.errorMessage ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<HomeProvider>().loadDashboard(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.15),
                foregroundColor: AppColors.error,
                elevation: 0,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );

    // Hero Widget
    Widget heroCard = const _HeroCard();

    // Stats Grid Widget
    Widget statsGrid = home.isLoading
        ? _StatsShimmer(isDesktop: isDesktop)
        : GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 1.9 : 1.7,
            children: [
              StatCard(
                label: 'Total Documents',
                value: '${home.totalDocuments}',
                icon: Icons.description_outlined,
                color: AppColors.gold,
              ),
              StatCard(
                label: 'High Risk',
                value: '${home.highRiskContracts}',
                icon: Icons.warning_amber_rounded,
                color: AppColors.highRisk,
              ),
              StatCard(
                label: 'Pending Reviews',
                value: '${home.pendingReviews}',
                icon: Icons.pending_actions_outlined,
                color: AppColors.info,
              ),
              StatCard(
                label: 'AI Accuracy',
                value: '${home.aiAccuracy}%',
                icon: Icons.psychology_outlined,
                color: AppColors.success,
              ),
            ],
          );

    // Quick Actions
    Widget quickActions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: isDesktop ? 3 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: [
            _QuickActionGridItem(
              icon: Icons.upload_file_outlined,
              label: 'Upload',
              color: AppColors.gold,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const UploadScreen(),
              ),
            ),
            _QuickActionGridItem(
              icon: Icons.psychology_outlined,
              label: 'AI Analyze',
              color: const Color(0xFF3498DB),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnalysisScreen())),
            ),
            _QuickActionGridItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'AI Chat',
              color: const Color(0xFF2ECC71),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChatScreen())),
            ),
            _QuickActionGridItem(
              icon: Icons.summarize_outlined,
              label: 'Summary',
              color: const Color(0xFF9B59B6),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SummaryScreen())),
            ),
            _QuickActionGridItem(
              icon: Icons.shield_outlined,
              label: 'Risk Check',
              color: AppColors.highRisk,
              onTap: () {},
            ),
            _QuickActionGridItem(
              icon: Icons.compare_outlined,
              label: 'Compare',
              color: const Color(0xFFF39C12),
              onTap: () {},
            ),
          ],
        ),
      ],
    );

    // Recent Documents list
    Widget recentDocumentsList;
    if (home.isLoading) {
      recentDocumentsList = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (_, __) => const _DocumentShimmer(),
      );
    } else if (home.recentDocuments.isEmpty) {
      recentDocumentsList = const EmptyStateWidget(
        icon: Icons.folder_open_outlined,
        title: 'No documents uploaded yet',
        description: 'Upload a PDF, TXT or legal document to get started with instant AI risk checks.',
      );
    } else {
      recentDocumentsList = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: home.recentDocuments.take(5).length,
        itemBuilder: (context, idx) {
          final doc = home.recentDocuments[idx];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DocumentCard(
              document: doc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalysisScreen()),
              ),
            ),
          );
        },
      );
    }

    if (isDesktop) {
      // Desktop Premium Layout
      return Scaffold(
        backgroundColor: AppColors.background,
        body: home.errorMessage != null
            ? Center(child: errorWidget)
            : RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.cardDark,
                onRefresh: () => context.read<HomeProvider>().loadDashboard(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Hero banner & Recent Documents
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heroCard.animate().fadeIn(duration: 400.ms),
                            const SizedBox(height: 32),
                            const SectionHeader(
                              title: 'Recent Documents',
                              subtitle: 'Latest contract analysis and liability scans',
                            ),
                            const SizedBox(height: 16),
                            recentDocumentsList,
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      // Right Column: Stats, Quick Actions, Risk Breakdown gauge
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            statsGrid.animate(delay: 100.ms).fadeIn(),
                            const SizedBox(height: 32),
                            quickActions.animate(delay: 200.ms).fadeIn(),
                            const SizedBox(height: 32),
                            // Risk Analysis breakdown card
                            DashboardCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Contract Risk Breakdown',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _RiskBar(
                                    label: 'High Risk',
                                    count: home.highRiskContracts,
                                    total: home.totalDocuments,
                                    color: AppColors.highRisk,
                                  ),
                                  const SizedBox(height: 12),
                                  _RiskBar(
                                    label: 'Medium Risk',
                                    count: home.totalDocuments - home.highRiskContracts - home.pendingReviews, // mock/derived value
                                    total: home.totalDocuments,
                                    color: AppColors.info,
                                  ),
                                  const SizedBox(height: 12),
                                  _RiskBar(
                                    label: 'Low Risk',
                                    count: home.totalDocuments > 0 ? (home.totalDocuments * 0.45).round() : 0, // mock/derived value
                                    total: home.totalDocuments,
                                    color: AppColors.success,
                                  ),
                                ],
                              ),
                            ).animate(delay: 300.ms).fadeIn(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    }

    // Mobile/Tablet Scroll Layout
    return Scaffold(
      backgroundColor: AppColors.background,
      body: home.errorMessage != null
          ? Center(child: errorWidget)
          : RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.cardDark,
              onRefresh: () => context.read<HomeProvider>().loadDashboard(),
              child: CustomScrollView(
                slivers: [
                  // Mobile Header
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: Theme.of(context).brightness == Brightness.dark
                              ? const [Color(0xFF0A1628), Color(0xFF080F1E)]
                              : const [Color(0xFFFFFFFF), Color(0xFFF5F7FA)],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateTimeUtils.getGreeting()},',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      user?.firstName ?? 'User',
                                      style: GoogleFonts.inter(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
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
                                  width: 44,
                                  height: 44,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark,
                                    borderRadius: BorderRadius.circular(12),
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
                                      size: 22,
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
                                  width: 44,
                                  height: 44,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Icon(Icons.notifications_outlined,
                                            color: AppColors.textPrimary, size: 22),
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
                              // Avatar
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                  );
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: AppColors.goldGradient),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      user?.initials ?? 'U',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Hero Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: heroCard,
                    ),
                  ),

                  // Stats Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: statsGrid,
                    ),
                  ),

                  // Quick Actions Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _QuickActionItem(
                                  icon: Icons.upload_file_outlined,
                                  label: 'Upload\nDocument',
                                  color: AppColors.gold,
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const UploadScreen(),
                                  ),
                                ),
                                _QuickActionItem(
                                  icon: Icons.psychology_outlined,
                                  label: 'AI\nAnalyze',
                                  color: const Color(0xFF3498DB),
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const AnalysisScreen())),
                                ),
                                _QuickActionItem(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  label: 'Chat with\nDocument',
                                  color: const Color(0xFF2ECC71),
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const ChatScreen())),
                                ),
                                _QuickActionItem(
                                  icon: Icons.summarize_outlined,
                                  label: 'Generate\nSummary',
                                  color: const Color(0xFF9B59B6),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryScreen())),
                                ),
                                _QuickActionItem(
                                  icon: Icons.shield_outlined,
                                  label: 'Risk\nDetection',
                                  color: AppColors.highRisk,
                                  onTap: () {},
                                ),
                                _QuickActionItem(
                                  icon: Icons.compare_outlined,
                                  label: 'Compare\nContracts',
                                  color: const Color(0xFFF39C12),
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recent Documents Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Documents',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'See All',
                              style: GoogleFonts.inter(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Mobile Document Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (home.isLoading) return const _DocumentShimmer();
                          if (home.recentDocuments.isEmpty) {
                            return const Center(child: Text('No documents uploaded.'));
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DocumentCard(
                              document: home.recentDocuments[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                              ),
                            ),
                          );
                        },
                        childCount: home.isLoading
                            ? 3
                            : home.recentDocuments.take(4).length,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }
}

// Stats Progress Bar for desktop risk breakdown
class _RiskBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _RiskBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            Text('$count files (${(percentage * 100).toStringAsFixed(0)}%)',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E3A6E), Color(0xFF0D1F3C)]
              : const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldGlow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '⚡ AI-POWERED',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Intelligent Legal\nDocument Review',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Upload your agreements, analyze liabilities, detect risk indicators, and summarize key paragraphs in real-time.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const UploadScreen(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Quick Analyze',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionGridItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  final bool isDesktop;
  const _StatsShimmer({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.9 : 1.7,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _DocumentShimmer extends StatelessWidget {
  const _DocumentShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
