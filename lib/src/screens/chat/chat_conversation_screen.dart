import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../data/chat_workspace_controller.dart';
import '../../data/gesit_api_client.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.controller,
    required this.conversationId,
    this.onOpenGroupDetail,
    this.onStartVoiceCall,
    this.onStartVideoCall,
  });

  final ChatWorkspaceController controller;
  final String conversationId;
  final VoidCallback? onOpenGroupDetail;
  final VoidCallback? onStartVoiceCall;
  final VoidCallback? onStartVideoCall;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final TextEditingController _composerController;
  late final ScrollController _scrollController;
  final ImagePicker _imagePicker = ImagePicker();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _scrollController = ScrollController();
    _lastMessageCount = widget.controller
        .messagesFor(widget.conversationId)
        .length;
    widget.controller.openConversation(widget.conversationId);
    widget.controller.addListener(_handleWorkspaceUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToBottom(jump: true);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleWorkspaceUpdate);
    widget.controller.closeConversation(widget.conversationId);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleWorkspaceUpdate() {
    if (!mounted) {
      return;
    }

    final nextCount = widget.controller
        .messagesFor(widget.conversationId)
        .length;
    if (nextCount != _lastMessageCount) {
      _lastMessageCount = nextCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollToBottom();
      });
    }
  }

  Future<void> _sendMessage() async {
    final value = _composerController.text.trim();
    if (value.isEmpty) {
      await _recordVoiceNote();
      return;
    }

    _composerController.clear();
    setState(() {});
    await widget.controller.sendTextMessage(widget.conversationId, value);
  }

  Future<void> _recordVoiceNote() async {
    final voiceNote = await showModalBottomSheet<_RecordedVoiceNote>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _VoiceNoteComposerSheet(),
    );

    if (voiceNote == null || voiceNote.duration.inMilliseconds <= 0) {
      return;
    }

    await widget.controller.sendVoiceNote(
      widget.conversationId,
      duration: voiceNote.duration,
      fileName: voiceNote.fileName,
      sizeLabel: _formatFileSize(voiceNote.sizeBytes),
      attachmentLocalPath: voiceNote.localPlaybackPath,
      filePayload: voiceNote.filePayload,
    );
  }

  Future<void> _showAttachmentSheet() async {
    final selection = await showModalBottomSheet<_AttachmentSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AttachmentSheet(),
    );

    if (!mounted || selection == null) {
      return;
    }

    switch (selection) {
      case _AttachmentSelection.document:
        await _pickDocument();
        break;
      case _AttachmentSelection.media:
        await _pickGalleryMedia();
        break;
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final rawBytes = file.bytes == null
          ? null
          : Uint8List.fromList(file.bytes!);
      if ((file.path == null || file.path!.trim().isEmpty) &&
          (rawBytes == null || rawBytes.isEmpty)) {
        _showFeedback('File dari perangkat tidak bisa dibaca.');
        return;
      }

      final mimeType =
          lookupMimeType(file.name, headerBytes: _headerBytes(rawBytes)) ??
          'application/octet-stream';
      Uint8List? previewBytes;
      if (_isImageMimeType(mimeType)) {
        previewBytes =
            rawBytes ??
            (file.path == null || file.path!.trim().isEmpty
                ? null
                : await XFile(file.path!).readAsBytes());
      }

      await widget.controller.sendAttachment(
        widget.conversationId,
        fileName: file.name,
        typeLabel: _typeLabelFor(file.name, mimeType),
        sizeLabel: _formatFileSize(file.size),
        attachmentMimeType: mimeType,
        attachmentPreviewBytes: previewBytes,
        filePayload: ApiMultipartFilePayload(
          fileName: file.name,
          path: kIsWeb ? null : file.path,
          bytes: rawBytes,
          contentType: mimeType,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showFeedback('Lampiran belum bisa dibuka dari perangkat ini.');
    }
  }

  Future<void> _pickGalleryMedia() async {
    try {
      final picked = await _imagePicker.pickMedia(
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (!mounted || picked == null) {
        return;
      }

      await _sendPickedFile(picked);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showFeedback('Media dari galeri belum bisa dipilih sekarang.');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
      );
      if (!mounted || photo == null) {
        return;
      }

      await _sendPickedFile(photo);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showFeedback('Kamera belum bisa digunakan di perangkat ini.');
    }
  }

  Future<void> _sendPickedFile(XFile pickedFile) async {
    final uploadBytes = kIsWeb ? await pickedFile.readAsBytes() : null;
    final mimeType =
        lookupMimeType(
          pickedFile.name,
          headerBytes: _headerBytes(uploadBytes),
        ) ??
        lookupMimeType(pickedFile.path) ??
        'application/octet-stream';
    final sizeBytes = uploadBytes?.lengthInBytes ?? await pickedFile.length();
    final previewBytes = _isImageMimeType(mimeType)
        ? (uploadBytes ?? await pickedFile.readAsBytes())
        : null;

    await widget.controller.sendAttachment(
      widget.conversationId,
      fileName: pickedFile.name,
      typeLabel: _typeLabelFor(pickedFile.name, mimeType),
      sizeLabel: _formatFileSize(sizeBytes),
      attachmentMimeType: mimeType,
      attachmentPreviewBytes: previewBytes,
      filePayload: ApiMultipartFilePayload(
        fileName: pickedFile.name,
        path: kIsWeb ? null : pickedFile.path,
        bytes: uploadBytes,
        contentType: mimeType,
      ),
    );
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottom({bool jump = false}) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final target = _scrollController.position.maxScrollExtent + 120;
    if (jump) {
      final clampedTarget = target.clamp(
        0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(clampedTarget.toDouble());
      return;
    }

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  String _typeLabelFor(String fileName, String mimeType) {
    if (_isImageMimeType(mimeType)) {
      return (mimeType.split('/').last).toUpperCase();
    }

    final extension = fileName.split('.').lastOrNull;
    if (extension != null &&
        extension.trim().isNotEmpty &&
        extension != fileName) {
      return extension.toUpperCase();
    }

    return mimeType.split('/').last.toUpperCase();
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 KB';
    }

    if (bytes < 1024 * 1024) {
      final value = bytes / 1024;
      return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} KB';
    }

    final value = bytes / (1024 * 1024);
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final conversation = widget.controller.conversationById(
          widget.conversationId,
        );
        if (conversation == null) {
          return const SizedBox.shrink();
        }

        final messages = widget.controller.messagesFor(widget.conversationId);
        final textTheme = Theme.of(context).textTheme;
        final canSend = _composerController.text.trim().isNotEmpty;
        final subtitle = conversation.isGroup
            ? conversation.subtitle
            : conversation.isOnline
            ? 'Aktif sekarang'
            : conversation.subtitle;

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
                              label: conversation.title,
                              accentColor: conversation.accentColor,
                              isGroup: conversation.isGroup,
                              showOnlineDot: conversation.isOnline,
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
                                    conversation.title,
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
                            onPressed: widget.onStartVideoCall,
                            icon: const Icon(Icons.videocam_rounded),
                          ),
                          IconButton(
                            onPressed: widget.onStartVoiceCall,
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
                        final message = messages[index];
                        return _MessageBubble(
                          message: message,
                          isGroup: conversation.isGroup,
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemCount: messages.length,
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
                                  onTap: _showAttachmentSheet,
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
                                  onTap: _capturePhoto,
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
      },
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
    final hasAttachmentCard = message.hasAttachment && !message.isVoiceNote;
    final showsTextSpacing = message.isVoiceNote || hasAttachmentCard;

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
              if (hasAttachmentCard)
                _AttachmentBubbleBody(
                  message: message,
                  textColor: textColor,
                  backgroundColor: message.isMine
                      ? Colors.white.withValues(alpha: 0.14)
                      : AppColors.surfaceAlt,
                ),
              if (message.isVoiceNote)
                _VoiceNoteBubbleBody(
                  sourceUrl:
                      message.attachmentUrl ?? message.attachmentLocalPath,
                  textColor: textColor,
                  backgroundColor: message.isMine
                      ? Colors.white.withValues(alpha: 0.14)
                      : AppColors.surfaceAlt,
                  durationLabel: message.voiceNoteDuration ?? '00:00',
                ),
              if (message.text.isNotEmpty) ...[
                if (showsTextSpacing) const SizedBox(height: 10),
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
      case MessageDelivery.read:
        return Icons.done_all_rounded;
      case MessageDelivery.failed:
        return Icons.error_outline_rounded;
    }
  }
}

class _AttachmentBubbleBody extends StatelessWidget {
  const _AttachmentBubbleBody({
    required this.message,
    required this.textColor,
    required this.backgroundColor,
  });

  final ChatMessage message;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isImage = _isImageMimeType(message.attachmentMimeType);

    return Container(
      width: isImage ? 230 : null,
      padding: isImage ? const EdgeInsets.all(8) : const EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: message.text.isEmpty ? 0 : 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: _AttachmentPreviewImage(message: message),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.attach_file_rounded, size: 18, color: textColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.attachmentLabel ?? 'Attachment',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (message.attachmentTypeLabel != null ||
                          message.attachmentSizeLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            message.attachmentTypeLabel,
                            message.attachmentSizeLabel,
                          ].whereType<String>().join(' • '),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: textColor.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _AttachmentPreviewImage extends StatelessWidget {
  const _AttachmentPreviewImage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.attachmentPreviewBytes case final previewBytes?
        when previewBytes.isNotEmpty) {
      return Image.memory(previewBytes, fit: BoxFit.cover);
    }

    if (message.attachmentUrl case final attachmentUrl?
        when attachmentUrl.trim().isNotEmpty) {
      return Image.network(
        attachmentUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AttachmentPreviewFallback(),
      );
    }

    return const _AttachmentPreviewFallback();
  }
}

class _AttachmentPreviewFallback extends StatelessWidget {
  const _AttachmentPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.inkMuted,
      ),
    );
  }
}

final _voiceNotePlaybackCoordinator = _VoiceNotePlaybackCoordinator();

class _VoiceNotePlaybackCoordinator {
  _VoiceNoteBubbleBodyState? _activeState;

  Future<void> activate(_VoiceNoteBubbleBodyState state) async {
    if (identical(_activeState, state)) {
      return;
    }

    final previousState = _activeState;
    _activeState = state;
    await previousState?._pauseFromCoordinator();
  }

  void release(_VoiceNoteBubbleBodyState state) {
    if (identical(_activeState, state)) {
      _activeState = null;
    }
  }
}

class _VoiceNoteBubbleBody extends StatefulWidget {
  const _VoiceNoteBubbleBody({
    required this.sourceUrl,
    required this.textColor,
    required this.backgroundColor,
    required this.durationLabel,
  });

  final String? sourceUrl;
  final Color textColor;
  final Color backgroundColor;
  final String durationLabel;

  @override
  State<_VoiceNoteBubbleBody> createState() => _VoiceNoteBubbleBodyState();
}

class _VoiceNoteBubbleBodyState extends State<_VoiceNoteBubbleBody> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  bool _loading = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _loadedSource;
  bool _failedToLoad = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }

      if (state.processingState == ProcessingState.completed) {
        unawaited(_resetPlaybackState());
        return;
      }

      final nextIsPlaying = state.playing;
      if (_isPlaying != nextIsPlaying) {
        setState(() => _isPlaying = nextIsPlaying);
      }

      if (!nextIsPlaying &&
          state.processingState != ProcessingState.loading &&
          state.processingState != ProcessingState.buffering) {
        _voiceNotePlaybackCoordinator.release(this);
      }
    });
    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() => _position = position);
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() => _duration = duration);
    });
  }

  @override
  void didUpdateWidget(covariant _VoiceNoteBubbleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceUrl != widget.sourceUrl) {
      _voiceNotePlaybackCoordinator.release(this);
      _loadedSource = null;
      _failedToLoad = false;
      _position = Duration.zero;
      _duration = null;
    }
  }

  @override
  void dispose() {
    _voiceNotePlaybackCoordinator.release(this);
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _pauseFromCoordinator() async {
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (_) {
      // Ignore coordinator pause errors so the next voice note can continue.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
      _loading = false;
    });
  }

  Future<void> _resetPlaybackState() async {
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (_) {
      // Ignore player reset failures after playback completes.
    }

    _voiceNotePlaybackCoordinator.release(this);
    if (!mounted) {
      return;
    }

    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
      _loading = false;
    });
  }

  Future<void> _togglePlayback() async {
    final sourceUrl = widget.sourceUrl?.trim();
    if (sourceUrl == null || sourceUrl.isEmpty || _loading) {
      return;
    }

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    try {
      await _voiceNotePlaybackCoordinator.activate(this);
      if (_loadedSource != sourceUrl) {
        setState(() {
          _loading = true;
          _failedToLoad = false;
        });
        if (_isLocalFileSource(sourceUrl)) {
          await _player.setFilePath(_normalizeFileSource(sourceUrl));
        } else {
          await _player.setUrl(sourceUrl);
        }
        _loadedSource = sourceUrl;
      }
      await _player.play();
    } catch (_) {
      _voiceNotePlaybackCoordinator.release(this);
      if (!mounted) {
        return;
      }
      setState(() => _failedToLoad = true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = ((_duration?.inMilliseconds ?? 0) > 0)
        ? _duration!
        : null;
    final progress =
        effectiveDuration == null || effectiveDuration.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / effectiveDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _loading
                  ? Icons.hourglass_top_rounded
                  : _isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: widget.textColor,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Row(
                children: List.generate(
                  8,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: 6 + (index.isEven ? 8 : 2).toDouble(),
                      decoration: BoxDecoration(
                        color: widget.textColor.withValues(
                          alpha: progress * 1.2 > index / 8 ? 0.95 : 0.42,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _failedToLoad ? 'Error' : widget.durationLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttachmentSelection { document, media }

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: BrandSurface(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          radius: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(
                  width: 44,
                  child: Divider(thickness: 4, color: AppColors.borderStrong),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Lampiran',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _AttachmentActionTile(
                icon: Icons.insert_drive_file_rounded,
                title: 'Dokumen',
                subtitle: 'PDF, spreadsheet, memo, atau file kerja lain.',
                onTap: () =>
                    Navigator.of(context).pop(_AttachmentSelection.document),
              ),
              const SizedBox(height: 12),
              _AttachmentActionTile(
                icon: Icons.photo_library_rounded,
                title: 'Foto & Media',
                subtitle: 'Kirim gambar, screenshot, atau media ringan.',
                onTap: () =>
                    Navigator.of(context).pop(_AttachmentSelection.media),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.goldDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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

class _RecordedVoiceNote {
  const _RecordedVoiceNote({
    required this.duration,
    required this.fileName,
    required this.sizeBytes,
    required this.localPlaybackPath,
    required this.filePayload,
  });

  final Duration duration;
  final String fileName;
  final int sizeBytes;
  final String localPlaybackPath;
  final ApiMultipartFilePayload filePayload;
}

class _VoiceNoteComposerSheet extends StatefulWidget {
  const _VoiceNoteComposerSheet();

  @override
  State<_VoiceNoteComposerSheet> createState() =>
      _VoiceNoteComposerSheetState();
}

class _VoiceNoteComposerSheetState extends State<_VoiceNoteComposerSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  bool _isPreparing = false;
  bool _isRecording = false;
  bool _isSending = false;
  Duration _elapsed = Duration.zero;
  String? _recordingPath;
  String? _errorMessage;
  double _level = 0.18;

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_amplitudeSubscription?.cancel());
    if (_isRecording) {
      unawaited(_recorder.cancel());
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isPreparing || _isSending) {
      return;
    }

    if (_isRecording) {
      await _stopRecording();
      return;
    }

    await _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = 'Izin mikrofon belum diberikan di perangkat ini.';
          _isPreparing = false;
        });
        return;
      }

      final path = await _buildRecordingPath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          noiseSuppress: true,
          echoCancel: true,
        ),
        path: path,
      );

      _stopwatch
        ..reset()
        ..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 180), (_) {
        if (!mounted) {
          return;
        }
        setState(() => _elapsed = _stopwatch.elapsed);
      });
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 180))
          .listen((amplitude) {
            if (!mounted) {
              return;
            }
            final normalized = ((amplitude.current + 45) / 45).clamp(0.12, 1.0);
            setState(() => _level = normalized.toDouble());
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _recordingPath = path;
        _elapsed = Duration.zero;
        _isRecording = true;
        _isPreparing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Rekaman suara belum bisa dimulai sekarang.';
        _isPreparing = false;
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    _stopwatch.stop();
    _ticker?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      final path = await _recorder.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _recordingPath = path ?? _recordingPath;
        _elapsed = _stopwatch.elapsed;
        _isRecording = false;
        _level = 0.18;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Rekaman suara gagal diselesaikan.';
        _isRecording = false;
      });
    }
  }

  Future<void> _discard() async {
    if (_isRecording) {
      try {
        await _recorder.cancel();
      } catch (_) {
        // Ignore recorder cleanup failures when closing the sheet.
      }
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _send() async {
    if (_isSending || _isPreparing) {
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    }

    final path = _recordingPath?.trim();
    if (path == null || path.isEmpty || _elapsed.inMilliseconds <= 0) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      final bytes = await XFile(path).readAsBytes();
      final fileName =
          'voice-note-${DateTime.now().millisecondsSinceEpoch}.wav';
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        _RecordedVoiceNote(
          duration: _elapsed,
          fileName: fileName,
          sizeBytes: bytes.lengthInBytes,
          localPlaybackPath: path,
          filePayload: ApiMultipartFilePayload(
            fileName: fileName,
            path: kIsWeb ? null : path,
            bytes: kIsWeb ? bytes : null,
            contentType: 'audio/wav',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Voice note gagal disiapkan untuk dikirim.';
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: BrandSurface(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          radius: 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                child: Divider(thickness: 4, color: AppColors.borderStrong),
              ),
              const SizedBox(height: 18),
              Text(
                'Voice Note',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_elapsed),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 34,
                  color: AppColors.goldDeep,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  12,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 5,
                    height: 10 + ((index.isEven ? 28 : 18) * _level),
                    decoration: BoxDecoration(
                      color: AppColors.goldDeep.withValues(
                        alpha: _isRecording ? 0.95 : 0.32,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: _isRecording ? AppColors.red : AppColors.goldDeep,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isRecording ? AppColors.red : AppColors.goldDeep)
                                .withValues(alpha: 0.32),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isPreparing
                    ? 'Menyiapkan mikrofon...'
                    : _isRecording
                    ? 'Tekan lagi untuk selesai.'
                    : 'Mulai rekam lalu kirim sebagai VN.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0C6BC)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSending ? null : _discard,
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _elapsed.inMilliseconds <= 0 ||
                              _isPreparing ||
                              _isSending
                          ? null
                          : _send,
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Kirim VN'),
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

  Future<String> _buildRecordingPath() async {
    if (kIsWeb) {
      return 'voice-note-${DateTime.now().millisecondsSinceEpoch}.wav';
    }

    final directory = await getTemporaryDirectory();
    return '${directory.path}/voice-note-${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

bool _isImageMimeType(String? mimeType) =>
    mimeType?.startsWith('image/') == true;

List<int>? _headerBytes(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  final end = bytes.length < 16 ? bytes.length : 16;
  return bytes.sublist(0, end);
}

bool _isLocalFileSource(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) {
    return true;
  }

  if (!uri.hasScheme) {
    return true;
  }

  return uri.scheme == 'file';
}

String _normalizeFileSource(String value) {
  if (value.startsWith('file://')) {
    return Uri.parse(value).toFilePath();
  }

  return value;
}
