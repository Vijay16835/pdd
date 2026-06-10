import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('About LexGuard AI', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.goldGradient),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: const Icon(Icons.psychology_outlined, size: 64, color: AppColors.navy),
            ),
            const SizedBox(height: 24),
            Text('LexGuard AI', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            Text('Intelligent Legal Explainer', style: GoogleFonts.inter(fontSize: 16, color: AppColors.gold, fontWeight: FontWeight.w600)),
            const SizedBox(height: 40),
            Text(
              'LexGuard AI is a state-of-the-art legal document analyzer designed to bridge the gap between complex legal jargon and everyday understanding. Our mission is to empower individuals and businesses with AI-driven insights into their legal obligations and risks.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 40),
            _buildInfoRow('Version', '1.0.0 (Build 1)'),
            _buildInfoRow('Engine', 'GPT-4o / Gemini 1.5 Pro'),
            _buildInfoRow('Developer', 'Vijay T'),
            _buildInfoRow(
              'Website',
              'www.lexguard.ai',
              onTap: () async {
                final Uri url = Uri.parse('https://www.lexguard.ai');
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          onTap != null
              ? InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.gold,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.gold,
                      ),
                    ),
                  ),
                )
              : Text(value, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
