
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/upload/providers/document_provider.dart';
import 'package:lexguard_ai/features/analysis/screens/analysis_result_screen.dart';
import 'package:lexguard_ai/features/profile/providers/profile_provider.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  PlatformFile? _selectedPlatformFile;
  String? _fileName;
  String? _fileSize;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      final file = result.files.single;
      final double sizeInMB = file.size / (1024 * 1024);
      setState(() {
        _selectedPlatformFile = file;
        _fileName = file.name;
        _fileSize = '${sizeInMB.toStringAsFixed(2)} MB';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedPlatformFile == null) return;

    final provider = context.read<DocumentProvider>();
    final docData = await provider.uploadDocument(_selectedPlatformFile!);

    if (!mounted) return;

    if (docData != null) {
      if (mounted) {
        context.read<AuthProvider>().refreshStats();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded! AI analysis started...'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(documentId: docData['id']),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Upload failed'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  IconData _getFileIcon(String? name) {
    if (name == null) return Icons.insert_drive_file;
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Upload Document',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Upload area
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedPlatformFile != null
                        ? AppColors.gold.withValues(alpha: 0.5)
                        : AppColors.border,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.goldGlow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedPlatformFile != null
                            ? _getFileIcon(_fileName)
                            : Icons.cloud_upload_outlined,
                        size: 48,
                        color: AppColors.gold,
                      ),
                    ).animate().scale(curve: Curves.elasticOut),
                    const SizedBox(height: 20),
                    Text(
                      _selectedPlatformFile != null
                          ? _fileName ?? 'File selected'
                          : 'Tap to select document',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedPlatformFile != null
                          ? _fileSize ?? ''
                          : 'PDF, DOCX, TXT, JPG, PNG (max 50MB)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // Supported formats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Supported Formats',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['PDF', 'DOCX', 'TXT', 'JPG', 'PNG']
                        .map((ext) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: AppColors.goldGlow,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(ext,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gold)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // AI Features info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Analysis Includes',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  ...[
                    ['Risk Detection', Icons.security, 'Identify legal risks'],
                    ['Clause Extraction', Icons.gavel, 'Extract key clauses'],
                    ['Smart Summary', Icons.auto_awesome, 'AI-generated summary'],
                    ['Chat with Doc', Icons.chat_bubble_outline, 'Ask questions'],
                  ]
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(item[1] as IconData,
                                    size: 20, color: AppColors.gold),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item[0] as String,
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary)),
                                    Text(item[2] as String,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 32),

            // Upload button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedPlatformFile == null || provider.isUploading
                    ? null
                    : _uploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.3),
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: provider.isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.navy)),
                          const SizedBox(width: 12),
                          Text('Uploading...',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      )
                    : Text('Upload & Analyze',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}
