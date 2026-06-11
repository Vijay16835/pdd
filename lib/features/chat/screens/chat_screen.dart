import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lexguard_ai/core/theme/app_colors.dart';
import 'package:lexguard_ai/features/chat/providers/chat_provider.dart';
import 'package:lexguard_ai/features/language/providers/language_provider.dart';
import 'package:lexguard_ai/models/chat_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:lexguard_ai/services/tts_service.dart';
import 'package:lexguard_ai/services/stt_service.dart';
import 'package:lexguard_ai/features/home/providers/home_provider.dart';
import 'package:lexguard_ai/features/upload/screens/upload_screen.dart';
import 'package:lexguard_ai/models/document_model.dart';
import 'package:lexguard_ai/features/profile/providers/profile_provider.dart';

class ChatScreen extends StatefulWidget {
  final String? documentId;
  final String? documentName;
  
  const ChatScreen({super.key, this.documentId, this.documentName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = context.read<ChatProvider>();
      if (widget.documentId != null) {
        if (chat.currentDocumentId != widget.documentId) {
          debugPrint('[ChatScreen] initState: setting document context: ${widget.documentId}');
          chat.setDocumentContext(widget.documentId!, documentName: widget.documentName);
        } else {
          debugPrint('[ChatScreen] initState: document context already set for ${widget.documentId}, loading history.');
          chat.loadHistory();
        }
      }
      // Load recent documents to populate the selector list
      context.read<HomeProvider>().loadDashboard();
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() => _showSuggestions = false);
    
    final chat = context.read<ChatProvider>();
    final tts = context.read<TtsService>();
    final langProvider = context.read<LanguageProvider>();

    chat.setSelectedLanguage(langProvider.selectedLanguage);

    chat.sendMessage(text, onAiResponse: (aiResponseText) {
      if (chat.isVoiceResponseEnabled) {
        tts.speak(aiResponseText, languageCode: langProvider.selectedLanguage);
      }
    });

    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _toggleListening(SttService stt, ChatProvider chat) async {
    if (stt.isListening) {
      await stt.stopListening();
    } else {
      await stt.startListening(
        language: chat.selectedLanguage,
        onResult: (words) {
          setState(() {
            _controller.text = words;
          });
        },
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final stt = context.watch<SttService>();
    final tts = context.watch<TtsService>();
    final langProvider = context.watch<LanguageProvider>();
    final home = context.watch<HomeProvider>();
    context.watch<ProfileProvider>();
    final messages = chat.messages;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (chat.selectedLanguage != langProvider.selectedLanguage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chat.setSelectedLanguage(langProvider.selectedLanguage);
      });
    }

    // Header Widget Actions
    List<Widget> headerActions = [
      IconButton(
        onPressed: () {
          chat.setVoiceResponseEnabled(!chat.isVoiceResponseEnabled);
          if (!chat.isVoiceResponseEnabled) {
            tts.stop();
          }
        },
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: chat.isVoiceResponseEnabled ? AppColors.gold.withValues(alpha: 0.15) : AppColors.cardDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: chat.isVoiceResponseEnabled ? AppColors.gold : AppColors.border),
          ),
          child: Icon(
            chat.isVoiceResponseEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: 18,
            color: chat.isVoiceResponseEnabled ? AppColors.gold : AppColors.textSecondary,
          ),
        ),
      ),
      IconButton(
        onPressed: () {
          tts.stop();
          context.read<ChatProvider>().clearChat();
        },
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(Icons.refresh_outlined, size: 18, color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(width: 8),
    ];

    // Right/Main Panel (Chat Interface)
    Widget chatInterface = Column(
      children: [
        // Context Banner
        if (chat.hasDocumentContext)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.goldGlow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Active Context: ${chat.currentDocumentName ?? 'Document'}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select a document from the left library to ask questions or start reviewing clauses.',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Error message banner
        if (chat.errorMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(chat.errorMessage!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error))),
                if (chat.hasDocumentContext)
                  GestureDetector(
                    onTap: () => chat.loadHistory(),
                    child: const Icon(Icons.refresh_rounded, color: AppColors.error, size: 16),
                  ),
              ],
            ),
          ).animate().shake(),

        // Messages Thread
        Expanded(
          child: chat.hasDocumentContext
              ? ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length + (chat.isTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length && chat.isTyping) {
                      return _TypingIndicator();
                    }
                    return _MessageBubble(
                      message: messages[i],
                      onCopy: () => _copyToClipboard(messages[i].content),
                    );
                  },
                )
              : _buildNoContextView(context, isDesktop),
        ),

        // Transcription banner
        if (stt.isListening)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.gold.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.mic, color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stt.lastWords.isEmpty ? 'Listening...' : stt.lastWords,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gold, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),

        // Prompt Suggestions
        if (_showSuggestions && messages.length <= 3) ...[
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ChatMessage.suggestedPrompts.length,
              itemBuilder: (context, i) => MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _sendMessage(ChatMessage.suggestedPrompts[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      ChatMessage.suggestedPrompts[i],
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Input Bar
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, isDesktop ? 20 : 24),
          decoration: BoxDecoration(
            color: AppColors.navBar,
            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              // Microphone Button
              GestureDetector(
                onTap: () => _toggleListening(stt, chat),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: stt.isListening ? Colors.red.withValues(alpha: 0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    stt.isListening ? Icons.mic : Icons.mic_none_outlined,
                    color: stt.isListening ? Colors.redAccent : AppColors.textHint,
                    size: 24,
                  ),
                ).animate(target: stt.isListening ? 1.0 : 0.0)
                 .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.2, 1.2), duration: 800.ms, curve: Curves.easeInOut)
                 .then()
                 .scale(begin: const Offset(1.2, 1.2), end: const Offset(1.0, 1.0), duration: 800.ms, curve: Curves.easeInOut),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Ask about this document...',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: _sendMessage,
                          maxLines: null,
                        ),
                      ),
                      _LanguagePickerButton(
                        selected: langProvider.selectedLanguage,
                        onChanged: (lang) {
                          langProvider.setLanguage(lang);
                          chat.setSelectedLanguage(lang);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (stt.isListening) stt.stopListening();
                  _sendMessage(_controller.text);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.goldGradient),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: AppColors.navy, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isDesktop) {
      // Desktop Premium Split Interface
      final docs = home.recentDocuments;

      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) tts.stop();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              // Left Document Selection Library Sidebar
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border, width: 1)),
                  color: AppColors.cardDark,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Documents Library',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.upload_file_outlined, color: AppColors.gold, size: 20),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const UploadScreen(),
                              ).then((_) {
                                home.loadDashboard();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: home.isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                          : docs.isEmpty
                              ? _buildEmptySidebar()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: docs.length,
                                  itemBuilder: (context, idx) {
                                    final doc = docs[idx];
                                    final isSelected = chat.currentDocumentId == doc.id;
                                    final isCompleted = doc.status == DocumentStatus.completed;

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          if (isCompleted) {
                                            chat.setDocumentContext(doc.id, documentName: doc.name);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('"${doc.name}" is analyzing...')),
                                            );
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: 150.ms,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.gold.withValues(alpha: 0.1)
                                                : AppColors.cardMid,
                                            border: Border.all(
                                              color: isSelected ? AppColors.gold : AppColors.border,
                                              width: isSelected ? 1.5 : 1.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf_outlined,
                                                color: isSelected ? AppColors.gold : AppColors.textHint,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      doc.name,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: isSelected ? AppColors.gold : AppColors.textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${doc.sizeInMB.toStringAsFixed(1)} MB',
                                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (!isCompleted)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.gold,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),

              // Right Chat Frame
              Expanded(
                child: Scaffold(
                  backgroundColor: AppColors.background,
                  appBar: AppBar(
                    backgroundColor: AppColors.background,
                    elevation: 0,
                    leadingWidth: 0,
                    leading: const SizedBox.shrink(),
                    title: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppColors.goldGradient),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.psychology_outlined, size: 22, color: AppColors.navy),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LexGuard AI Agent',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Interactive Legal Document Auditor',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: headerActions,
                  ),
                  body: chatInterface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile / Tablet View
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) tts.stop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            onPressed: () {
              tts.stop();
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textPrimary),
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: AppColors.goldGradient), shape: BoxShape.circle),
                child: const Icon(Icons.psychology_outlined, size: 20, color: AppColors.navy),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LexGuard AI', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('Online', style: GoogleFonts.inter(fontSize: 11, color: AppColors.success)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: headerActions,
        ),
        body: chatInterface,
      ),
    );
  }

  Widget _buildEmptySidebar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 36, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            'No documents in library',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoContextView(BuildContext context, bool isDesktop) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.2), width: 2),
                ),
                child: const Icon(Icons.psychology_outlined, size: 36, color: AppColors.gold),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1200.ms),
              const SizedBox(height: 20),
              Text(
                'Chat with Legal AI',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                isDesktop
                    ? 'Select an agreement from the sidebar library to analyze risks, verify clauses, or translate conditions.'
                    : 'Select a document or upload a new one to begin asking context-aware questions.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (!isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDocumentSelectionSheet(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.folder_open_rounded, size: 16, color: AppColors.gold),
                        label: Text('Select Doc', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final home = context.read<HomeProvider>();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const UploadScreen(),
                          ).then((_) {
                            home.loadDashboard();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.navy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.upload_file_outlined, size: 16),
                        label: Text('Upload New', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final home = context.watch<HomeProvider>();
        final docs = home.recentDocuments;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.vertical(top: const Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                'Select a Document',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a contract or document to analyze with AI',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (home.isLoading) ...[
                const SizedBox(height: 40),
                const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.gold))),
                const SizedBox(height: 40),
              ] else if (docs.isEmpty) ...[
                const SizedBox(height: 20),
                Icon(Icons.description_outlined, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text('No documents found', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text('Please upload a document first', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                const SizedBox(height: 24),
              ] else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final isCompleted = doc.status == DocumentStatus.completed;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cardMid,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          onTap: () {
                            if (isCompleted) {
                              context.read<ChatProvider>().setDocumentContext(doc.id, documentName: doc.name);
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${doc.name}" is still being analyzed. Please wait.'),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            }
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCompleted ? AppColors.goldGlow : AppColors.cardDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_outlined,
                              color: isCompleted ? AppColors.gold : AppColors.textHint,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            doc.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Uploaded ${DateFormat('MMM d, yyyy').format(doc.uploadedAt)} • ${doc.sizeInMB.toStringAsFixed(1)} MB',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : doc.status == DocumentStatus.analyzing
                                      ? AppColors.gold.withValues(alpha: 0.15)
                                      : AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCompleted
                                  ? 'Analyzed'
                                  : doc.status == DocumentStatus.analyzing
                                      ? 'Analyzing...'
                                      : doc.statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted
                                    ? AppColors.success
                                    : doc.status == DocumentStatus.analyzing
                                        ? AppColors.gold
                                        : AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCopy;
  const _MessageBubble({required this.message, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final tts = context.watch<TtsService>();
    final langProvider = context.watch<LanguageProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: AppColors.goldGradient), shape: BoxShape.circle),
              child: const Icon(Icons.psychology_outlined, size: 17, color: AppColors.navy),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.gold : AppColors.cardDark,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser ? null : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      message.content,
                      style: GoogleFonts.inter(fontSize: 14, color: isUser ? AppColors.navy : AppColors.textPrimary, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint),
                    ),
                    if (!isUser) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onCopy,
                        child: Icon(Icons.copy_rounded, size: 12, color: AppColors.textHint),
                      ),
                      const SizedBox(width: 8),
                      _TtsControls(
                        message: message,
                        tts: tts,
                        language: langProvider.selectedLanguage,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

class _TtsControls extends StatelessWidget {
  final ChatMessage message;
  final TtsService tts;
  final String language;

  const _TtsControls({
    required this.message,
    required this.tts,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = tts.lastText == message.content && !tts.isStopped;

    if (!isCurrent) {
      return GestureDetector(
        onTap: () => tts.speak(message.content, languageCode: language),
        child: Icon(
          Icons.volume_up_rounded,
          size: 14,
          color: AppColors.textHint,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tts.isPlaying)
          Container(
            margin: const EdgeInsets.only(right: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat())
            .fadeIn(duration: 400.ms)
            .fadeOut(duration: 400.ms)
        else
          Container(
            margin: const EdgeInsets.only(right: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              shape: BoxShape.circle,
            ),
          ),
        GestureDetector(
          onTap: tts.isPaused ? tts.resume : null,
          child: Icon(
            Icons.play_arrow_rounded,
            size: 15,
            color: tts.isPaused ? AppColors.gold : AppColors.textHint,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: tts.isPlaying ? tts.pause : null,
          child: Icon(
            Icons.pause_rounded,
            size: 15,
            color: tts.isPlaying ? AppColors.gold : AppColors.textHint,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: tts.stop,
          child: const Icon(
            Icons.stop_rounded,
            size: 15,
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: AppColors.goldGradient), shape: BoxShape.circle),
          child: const Icon(Icons.psychology_outlined, size: 17, color: AppColors.navy),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18)), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0),
            const SizedBox(width: 4),
            _Dot(delay: 200),
            const SizedBox(width: 4),
            _Dot(delay: 400),
          ]),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
    ).animate(onPlay: (c) => c.repeat(reverse: true), delay: Duration(milliseconds: delay)).scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 600.ms);
  }
}

class _LanguagePickerButton extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _LanguagePickerButton({required this.selected, required this.onChanged});

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            const SizedBox(height: 16),
            Text(
              'AI Response Language',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'AI answers and summaries will appear in the selected language.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...kSupportedLanguages.map((lang) {
              final isSelected = lang == selected;
              return GestureDetector(
                onTap: () {
                  onChanged(lang);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold.withValues(alpha: 0.12) : AppColors.cardMid,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(kLanguageFlags[lang] ?? '🌐', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Text(
                        lang,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.gold : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(kLanguageFlags[selected] ?? '🌐', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              selected,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, color: AppColors.gold, size: 16),
          ],
        ),
      ),
    );
  }
}
