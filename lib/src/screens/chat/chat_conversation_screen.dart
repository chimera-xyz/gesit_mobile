import 'package:flutter/material.dart';

import '../../data/demo_data.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversation,
    this.onOpenGroupDetail,
  });

  final ConversationPreview conversation;
  final VoidCallback? onOpenGroupDetail;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final TextEditingController _composerController;
  late final ScrollController _scrollController;
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _scrollController = ScrollController();
    _messages = DemoData.messagesFor(widget.conversation.id);
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final value = _composerController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Composer siap, backend pengiriman menyusul tahap berikutnya.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _messages = [
        ..._messages,
        ChatMessage(
          id: 'local-${_messages.length}',
          text: value,
          timeLabel: 'Now',
          delivery: MessageDelivery.read,
          isMine: true,
        ),
      ];
      _composerController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canSend = _composerController.text.trim().isNotEmpty;
    final subtitle = widget.conversation.isGroup
        ? widget.conversation.subtitle
        : widget.conversation.isOnline
        ? 'Aktif sekarang'
        : widget.conversation.subtitle;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: BrandSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceAlt,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: widget.onOpenGroupDetail,
                        child: ConversationAvatar(
                          label: widget.conversation.title,
                          accentColor: widget.conversation.accentColor,
                          isGroup: widget.conversation.isGroup,
                          showOnlineDot: widget.conversation.isOnline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onOpenGroupDetail,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.conversation.title,
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.videocam_rounded),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.call_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _MessageBubble(
                      message: message,
                      isGroup: widget.conversation.isGroup,
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _messages.length,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: BrandSurface(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        radius: 28,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _ChatComposerToolButton(
                              icon: Icons.add_rounded,
                              onTap: () {},
                            ),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                ),
                                child: TextField(
                                  controller: _composerController,
                                  minLines: 1,
                                  maxLines: 5,
                                  onChanged: (_) => setState(() {}),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: AppColors.ink,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Ketik pesan...',
                                    hintStyle: TextStyle(
                                      color: AppColors.inkMuted,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.only(
                                      left: 4,
                                      right: 4,
                                      top: 16,
                                      bottom: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _ChatComposerToolButton(
                              icon: Icons.camera_alt_rounded,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ChatComposerSendButton(
                      enabled: canSend,
                      onTap: _sendMessage,
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

class _ChatComposerToolButton extends StatelessWidget {
  const _ChatComposerToolButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.inkSoft,
        padding: const EdgeInsets.all(10),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

class _ChatComposerSendButton extends StatelessWidget {
  const _ChatComposerSendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: enabled ? AppColors.goldDeep : AppColors.surface,
          shape: BoxShape.circle,
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
          enabled ? Icons.send_rounded : Icons.mic_rounded,
          color: enabled ? Colors.white : AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isGroup});

  final ChatMessage message;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (message.isSystem) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final bubbleColor = message.isMine
        ? AppColors.goldDeep
        : AppColors.surface.withValues(alpha: 0.95);
    final textColor = message.isMine ? Colors.white : AppColors.ink;
    final metaColor = message.isMine ? Colors.white70 : AppColors.inkMuted;

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(message.isMine ? 22 : 8),
              bottomRight: Radius.circular(message.isMine ? 8 : 22),
            ),
            border: message.isMine ? null : Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F291C09),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!message.isMine && isGroup && message.senderName != null) ...[
                Text(
                  message.senderName!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (message.hasAttachment)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: EdgeInsets.only(
                    bottom: message.text.isEmpty ? 0 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isMine
                        ? Colors.white.withValues(alpha: 0.14)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 18,
                        color: textColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.attachmentLabel ?? 'Attachment',
                          style: textTheme.bodySmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.isVoiceNote)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isMine
                        ? Colors.white.withValues(alpha: 0.14)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: textColor),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 82,
                        child: Row(
                          children: List.generate(
                            8,
                            (index) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                height: 6 + (index.isEven ? 8 : 2).toDouble(),
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        message.voiceNoteDuration ?? '0:00',
                        style: textTheme.bodySmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.text.isNotEmpty) ...[
                if (message.isVoiceNote || message.hasAttachment)
                  const SizedBox(height: 10),
                Text(
                  message.text,
                  style: textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.timeLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: metaColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message.isMine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _deliveryIcon(message.delivery),
                      size: 15,
                      color: metaColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _deliveryIcon(MessageDelivery delivery) {
    switch (delivery) {
      case MessageDelivery.sending:
        return Icons.schedule_rounded;
      case MessageDelivery.delivered:
        return Icons.done_all_rounded;
      case MessageDelivery.read:
        return Icons.done_all_rounded;
    }
  }
}
