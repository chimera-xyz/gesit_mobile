import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class KnowledgeAssistantScreen extends StatefulWidget {
  const KnowledgeAssistantScreen({super.key});

  @override
  State<KnowledgeAssistantScreen> createState() =>
      _KnowledgeAssistantScreenState();
}

class _KnowledgeAssistantScreenState extends State<KnowledgeAssistantScreen> {
  static const List<_AssistantPrompt> _prompts = [
    _AssistantPrompt(
      title: 'Ringkas SOP approval pengadaan',
      prompt: 'Ringkas SOP approval pengadaan',
      icon: Icons.fact_check_rounded,
    ),
    _AssistantPrompt(
      title: 'Bagaimana proses akses S21+ user baru?',
      prompt: 'Bagaimana proses akses S21+ user baru?',
      icon: Icons.lock_open_rounded,
    ),
    _AssistantPrompt(
      title: 'Dokumen apa yang dibutuhkan vendor onboarding?',
      prompt: 'Dokumen apa yang dibutuhkan vendor onboarding?',
      icon: Icons.folder_copy_rounded,
    ),
    _AssistantPrompt(
      title: 'Buat checklist helpdesk kritikal',
      prompt: 'Buat checklist helpdesk kritikal',
      icon: Icons.support_agent_rounded,
    ),
  ];

  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [];

  bool _isResponding = false;

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? seededPrompt]) async {
    final value = (seededPrompt ?? _composerController.text).trim();
    if (value.isEmpty || _isResponding) {
      return;
    }

    setState(() {
      _messages.add(_AssistantMessage.user(text: value));
      _composerController.clear();
      _isResponding = true;
    });

    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 480));
    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(_buildReply(value));
      _isResponding = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 180,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _isResponding = false;
      _composerController.clear();
    });
  }

  void _handleComposerAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label siap disambungkan ke workflow berikutnya.'),
      ),
    );
  }

  _AssistantMessage _buildReply(String prompt) {
    final normalized = prompt.toLowerCase();

    if (normalized.contains('approval') || normalized.contains('pengadaan')) {
      return const _AssistantMessage.assistant(
        text:
            'Alur umumnya: requester isi form pengadaan, head division review kebutuhan, finance validasi budget, lalu procurement proses vendor dan dokumen final. Untuk approval mobile, fokus utama biasanya ada di justifikasi bisnis, budget owner, dan attachment quotation.',
        sources: [
          _AssistantSource(
            title: 'SOP Approval Pengadaan',
            subtitle: 'Operations · SOP',
            accentColor: AppColors.goldDeep,
          ),
          _AssistantSource(
            title: 'Panduan Vendor Onboarding',
            subtitle: 'Procurement · Panduan',
            accentColor: AppColors.emerald,
          ),
        ],
      );
    }

    if (normalized.contains('s21') || normalized.contains('akses')) {
      return const _AssistantMessage.assistant(
        text:
            'Untuk akses user baru, biasanya butuh data user, role yang diminta, justifikasi akses, dan tanggal efektif. Setelah itu approval manager berjalan dulu, baru dilanjutkan validasi IT security dan IT operations sebelum akses diaktifkan.',
        sources: [
          _AssistantSource(
            title: 'Panduan Akses S21+',
            subtitle: 'IT Security · Panduan',
            accentColor: AppColors.blue,
          ),
        ],
      );
    }

    if (normalized.contains('vendor')) {
      return const _AssistantMessage.assistant(
        text:
            'Dokumen yang umum diminta untuk vendor onboarding adalah identitas perusahaan, NPWP, rekening pembayaran, PIC vendor, dan dokumen legal pendukung. Kalau prosesnya melibatkan pembayaran, finance biasanya ikut validasi data rekening dan kelengkapan dokumen.',
        sources: [
          _AssistantSource(
            title: 'Panduan Vendor Onboarding',
            subtitle: 'Procurement · Panduan',
            accentColor: AppColors.emerald,
          ),
          _AssistantSource(
            title: 'SOP Approval Pengadaan',
            subtitle: 'Operations · SOP',
            accentColor: AppColors.goldDeep,
          ),
        ],
      );
    }

    if (normalized.contains('helpdesk') || normalized.contains('kritikal')) {
      return const _AssistantMessage.assistant(
        text:
            'Checklist awal ticket helpdesk kritikal: identifikasi area terdampak, cek scope user/device, catat waktu mulai incident, assign PIC aktif, dan update status berkala sampai mitigasi selesai. Untuk issue jaringan atau trading floor, escalation sebaiknya diprioritaskan lebih awal.',
        sources: [
          _AssistantSource(
            title: 'FAQ Helpdesk Internal',
            subtitle: 'IT Support · FAQ',
            accentColor: AppColors.red,
          ),
        ],
      );
    }

    return const _AssistantMessage.assistant(
      text:
          'Saya bisa bantu ringkas SOP, jelaskan alur approval, bantu cari knowledge item, atau buat checklist proses internal. Coba spesifikkan topik seperti approval, akses sistem, vendor onboarding, atau helpdesk.',
      sources: [
        _AssistantSource(
          title: 'Knowledge Hub',
          subtitle: 'Internal Workspace',
          accentColor: AppColors.goldDeep,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canSend = _composerController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Assistant', style: textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            'Knowledge internal GESIT',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_messages.isNotEmpty)
                      TextButton(
                        onPressed: _startNewChat,
                        child: const Text('New'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _messages.isEmpty
                      ? _AssistantEmptyState(
                          key: const ValueKey('assistant-empty'),
                          prompts: _prompts,
                          onPromptTap: _sendMessage,
                        )
                      : ListView.separated(
                          key: const ValueKey('assistant-thread'),
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const _AssistantTypingCard();
                            }

                            return _AssistantThreadItem(
                              message: _messages[index],
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemCount: _messages.length + (_isResponding ? 1 : 0),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AssistantComposerIconButton(
                      icon: Icons.add_rounded,
                      onTap: () => _handleComposerAction('Attachment'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AssistantComposerField(
                        controller: _composerController,
                        focusNode: _composerFocusNode,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AssistantComposerSendButton(
                      enabled: canSend,
                      onTap: canSend
                          ? _sendMessage
                          : () => _handleComposerAction('Voice input'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    super.key,
    required this.prompts,
    required this.onPromptTap,
  });

  final List<_AssistantPrompt> prompts;
  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          const SizedBox(height: 72),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.goldSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.goldDeep,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Apa yang ingin Anda ketahui?',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Tanya SOP, panduan, atau proses internal perusahaan.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          for (var index = 0; index < prompts.length; index++) ...[
            RevealUp(
              index: index,
              child: _AssistantPromptCard(
                prompt: prompts[index],
                onTap: () => onPromptTap(prompts[index].prompt),
              ),
            ),
            if (index != prompts.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AssistantPromptCard extends StatelessWidget {
  const _AssistantPromptCard({required this.prompt, required this.onTap});

  final _AssistantPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(prompt.icon, color: AppColors.goldDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prompt.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.arrow_outward_rounded,
            size: 18,
            color: AppColors.inkMuted,
          ),
        ],
      ),
    );
  }
}

class _AssistantComposerField extends StatelessWidget {
  const _AssistantComposerField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final isFocused = focusNode.hasFocus;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isFocused ? AppColors.borderStrong : AppColors.border,
              width: isFocused ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isFocused
                    ? const Color(0x1A9B6B17)
                    : const Color(0x12291C09),
                blurRadius: isFocused ? 24 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    onChanged: onChanged,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tanyakan knowledge internal...',
                      hintMaxLines: 1,
                      hintStyle: textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssistantComposerIconButton extends StatelessWidget {
  const _AssistantComposerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E291C09),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.ink, size: 28),
        ),
      ),
    );
  }
}

class _AssistantComposerSendButton extends StatelessWidget {
  const _AssistantComposerSendButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: enabled ? AppColors.goldDeep : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: enabled ? null : Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12291C09),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            enabled ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
            color: enabled ? Colors.white : AppColors.ink,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _AssistantThreadItem extends StatelessWidget {
  const _AssistantThreadItem({required this.message});

  final _AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              message.text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
            ),
          ),
        ),
      );
    }

    return BrandSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asisten',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.goldDeep,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message.text,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.ink, height: 1.55),
          ),
          if (message.sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Sources',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < message.sources.length; index++) ...[
              _AssistantSourceCard(source: message.sources[index]),
              if (index != message.sources.length - 1)
                const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _AssistantSourceCard extends StatelessWidget {
  const _AssistantSourceCard({required this.source});

  final _AssistantSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: source.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_rounded,
              color: source.accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  source.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantTypingCard extends StatelessWidget {
  const _AssistantTypingCard();

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Asisten sedang mengetik...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _AssistantPrompt {
  const _AssistantPrompt({
    required this.title,
    required this.prompt,
    required this.icon,
  });

  final String title;
  final String prompt;
  final IconData icon;
}

class _AssistantSource {
  const _AssistantSource({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
}

class _AssistantMessage {
  const _AssistantMessage._({
    required this.text,
    required this.isUser,
    this.sources = const [],
  });

  const _AssistantMessage.user({required String text})
    : this._(text: text, isUser: true);

  const _AssistantMessage.assistant({
    required String text,
    List<_AssistantSource> sources = const [],
  }) : this._(text: text, isUser: false, sources: sources);

  final String text;
  final bool isUser;
  final List<_AssistantSource> sources;
}
