import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/chat_call_media_engine.dart';
import '../../data/chat_workspace_controller.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';

class ChatCallScreen extends StatefulWidget {
  const ChatCallScreen({
    super.key,
    required this.controller,
    required this.conversationId,
  });

  final ChatWorkspaceController controller;
  final String conversationId;

  @override
  State<ChatCallScreen> createState() => _ChatCallScreenState();
}

class _ChatCallScreenState extends State<ChatCallScreen> {
  late final AudioPlayer _ringbackPlayer;
  final _RingbackToneSource _ringbackToneSource = _RingbackToneSource();
  bool _ringbackSourceReady = false;
  bool _ringbackStartInFlight = false;
  bool _autoCloseScheduled = false;

  @override
  void initState() {
    super.initState();
    _ringbackPlayer = AudioPlayer();
    widget.controller.addListener(_handleControllerUpdate);
    _syncRingbackTone();
    unawaited(widget.controller.announceActiveCallReady());
  }

  @override
  void dispose() {
    unawaited(_stopRingbackTone());
    unawaited(_ringbackPlayer.dispose());
    widget.controller.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  void _handleControllerUpdate() {
    final activeCall = widget.controller.activeCall;
    if (!mounted) {
      return;
    }

    _syncRingbackTone();
    if (_canPopRouteFor(activeCall)) {
      setState(() {});
      _scheduleAutoClose();
    }
  }

  bool _canPopRouteFor(ChatCallSession? session) {
    return session == null ||
        session.conversationId != widget.conversationId ||
        _isTerminalStatus(session.status);
  }

  bool _isTerminalStatus(ChatCallStatus status) {
    return status == ChatCallStatus.ended ||
        status == ChatCallStatus.missed ||
        status == ChatCallStatus.declined;
  }

  void _scheduleAutoClose() {
    if (_autoCloseScheduled || !mounted) {
      return;
    }

    _autoCloseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCloseScheduled = false;
      if (!mounted) {
        return;
      }

      final session = widget.controller.activeCall;
      if (!_canPopRouteFor(session)) {
        return;
      }

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  void _syncRingbackTone() {
    if (!_shouldPlayRingbackTone) {
      unawaited(_stopRingbackTone());
      return;
    }

    unawaited(_startRingbackTone());
  }

  bool get _shouldPlayRingbackTone {
    final session = widget.controller.activeCall;
    return session != null &&
        session.conversationId == widget.conversationId &&
        !session.isIncoming &&
        session.status == ChatCallStatus.ringing;
  }

  Future<void> _startRingbackTone() async {
    if (_ringbackStartInFlight || _ringbackPlayer.playing) {
      return;
    }

    _ringbackStartInFlight = true;
    try {
      if (!_ringbackSourceReady) {
        await _ringbackPlayer.setLoopMode(LoopMode.one);
        await _ringbackPlayer.setVolume(0.86);
        await _ringbackPlayer.setAudioSource(_ringbackToneSource);
        _ringbackSourceReady = true;
      }

      if (!_shouldPlayRingbackTone) {
        return;
      }

      await _ringbackPlayer.seek(Duration.zero);
      await _ringbackPlayer.play();
    } catch (_) {
      // Ignore ringback playback failures so the call flow stays responsive.
    } finally {
      _ringbackStartInFlight = false;
    }
  }

  Future<void> _stopRingbackTone() async {
    try {
      await _ringbackPlayer.pause();
      if (_ringbackSourceReady) {
        await _ringbackPlayer.seek(Duration.zero);
      }
    } catch (_) {
      // Ignore ringback cleanup failures.
    }
  }

  Future<void> _handleCloseRequested() async {
    final session = widget.controller.activeCall;
    if (_canPopRouteFor(session)) {
      _scheduleAutoClose();
      return;
    }
    final activeSession = session!;

    final shouldEndCall = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isIncomingRinging =
            activeSession.isIncoming &&
            activeSession.status == ChatCallStatus.ringing;
        final title = isIncomingRinging
            ? 'Tolak panggilan ini?'
            : 'Akhiri panggilan ini?';
        final message = isIncomingRinging
            ? 'Jika ditutup sekarang, panggilan masuk ini akan langsung ditolak.'
            : 'Menutup layar call akan langsung mengakhiri panggilan yang sedang berjalan.';

        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(isIncomingRinging ? 'Tolak' : 'Akhiri'),
            ),
          ],
        );
      },
    );

    if (shouldEndCall != true) {
      return;
    }

    if (activeSession.isIncoming &&
        activeSession.status == ChatCallStatus.ringing) {
      await widget.controller.declineActiveCall();
      return;
    }

    await widget.controller.endActiveCall();
  }

  @override
  Widget build(BuildContext context) {
    final canPopRoute = _canPopRouteFor(widget.controller.activeCall);
    return PopScope(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || canPopRoute) {
          return;
        }
        unawaited(_handleCloseRequested());
      },
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final session = widget.controller.activeCall;
          if (session == null ||
              session.conversationId != widget.conversationId) {
            return const SizedBox.shrink();
          }

          final conversation = widget.controller.conversationById(
            widget.conversationId,
          );
          final accentColor = conversation?.accentColor ?? AppColors.goldDeep;
          final textTheme = Theme.of(context).textTheme;
          final mediaState = widget.controller.callMediaState;
          final localRenderer = widget.controller.callMediaEngine.localRenderer;
          final remoteRenderer =
              widget.controller.callMediaEngine.remoteRenderer;
          final remoteParticipants = session.participants
              .where((participant) => !participant.isCurrentUser)
              .toList(growable: false);
          final selfParticipant = session.participants.firstWhere(
            (participant) => participant.isCurrentUser,
            orElse: () => session.participants.first,
          );
          final statusLabel = _buildStatusLabel(
            session,
            conversation,
            mediaState,
          );
          final isIncomingRinging =
              session.isIncoming && session.status == ChatCallStatus.ringing;
          final actions = isIncomingRinging
              ? <Widget>[
                  Expanded(
                    child: _CallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'Tolak',
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.red,
                      onTap: () =>
                          unawaited(widget.controller.declineActiveCall()),
                    ),
                  ),
                  Expanded(
                    child: _CallActionButton(
                      icon: Icons.call_rounded,
                      label: 'Jawab',
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.blue,
                      onTap: () =>
                          unawaited(widget.controller.acceptActiveCall()),
                    ),
                  ),
                ]
              : <Widget>[
                  Expanded(
                    child: _CallActionButton(
                      icon: session.micEnabled
                          ? Icons.mic_rounded
                          : Icons.mic_off_rounded,
                      label: session.micEnabled ? 'Mic' : 'Muted',
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      onTap: widget.controller.toggleActiveCallMic,
                    ),
                  ),
                  Expanded(
                    child: _CallActionButton(
                      icon: session.speakerEnabled
                          ? Icons.volume_up_rounded
                          : Icons.hearing_disabled_rounded,
                      label: 'Speaker',
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      onTap: widget.controller.toggleActiveCallSpeaker,
                    ),
                  ),
                  if (session.type == ChatCallType.video)
                    Expanded(
                      child: _CallActionButton(
                        icon: session.cameraEnabled
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        label: 'Camera',
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        onTap: widget.controller.toggleActiveCallCamera,
                      ),
                    ),
                  Expanded(
                    child: _CallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.red,
                      onTap: () => unawaited(widget.controller.endActiveCall()),
                    ),
                  ),
                ];

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.92),
                    const Color(0xFF1E1711),
                    const Color(0xFF0F0B07),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => unawaited(_handleCloseRequested()),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.14,
                              ),
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          if (session.isGroup)
                            StatusChip(
                              label: '${session.participants.length} peserta',
                              color: Colors.white,
                              icon: Icons.groups_rounded,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 18, 28, 10),
                      child: Column(
                        children: [
                          Text(
                            session.title,
                            textAlign: TextAlign.center,
                            style: textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 34,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            statusLabel,
                            style: textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                        child: session.type == ChatCallType.video
                            ? _VideoCallStage(
                                accentColor: accentColor,
                                session: session,
                                mediaState: mediaState,
                                remoteRenderer: remoteRenderer,
                                localRenderer: localRenderer,
                                selfParticipant: selfParticipant,
                                showSelfPreview:
                                    mediaState.hasLocalVideo &&
                                    session.cameraEnabled,
                                isFrontCamera: mediaState.isFrontCamera,
                              )
                            : _VoiceCallStage(
                                accentColor: accentColor,
                                session: session,
                                remoteParticipants: remoteParticipants,
                                mediaState: mediaState,
                                remoteRenderer: remoteRenderer,
                              ),
                      ),
                    ),
                    if (mediaState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  mediaState.errorMessage!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < actions.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 10),
                            actions[index],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatActiveStatus(ChatCallSession session) {
    final elapsed = session.elapsed;
    final minutes = (elapsed.inSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    if (elapsed.inHours > 0) {
      final hours = elapsed.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _buildStatusLabel(
    ChatCallSession session,
    ConversationPreview? conversation,
    ChatCallMediaState mediaState,
  ) {
    if (mediaState.isPreparingLocalMedia) {
      return session.type == ChatCallType.video
          ? 'Menyiapkan kamera dan mikrofon...'
          : 'Menyiapkan mikrofon...';
    }

    if (session.status == ChatCallStatus.active) {
      if (mediaState.isConnecting && !mediaState.isConnected) {
        return 'Menghubungkan media...';
      }
      return _formatActiveStatus(session);
    }

    if (session.isIncoming) {
      return 'Panggilan masuk';
    }

    if (session.status == ChatCallStatus.ringing) {
      final remoteIsReachable = conversation?.isOnline == true;
      if (session.isGroup) {
        return remoteIsReachable
            ? 'Berdering ke grup...'
            : 'Menghubungi grup...';
      }
      return remoteIsReachable ? 'Berdering...' : 'Menghubungi...';
    }

    return session.status.label;
  }
}

class _RingbackToneSource extends StreamAudioSource {
  static final Uint8List _ringbackBytes = _buildRingbackBytes();

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final sourceLength = _ringbackBytes.length;
    final rangeStart = start?.clamp(0, sourceLength) ?? 0;
    final rangeEnd = end?.clamp(rangeStart, sourceLength) ?? sourceLength;
    final chunk = _ringbackBytes.sublist(rangeStart, rangeEnd);

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: chunk.length,
      offset: rangeStart,
      stream: Stream<List<int>>.value(chunk),
      contentType: 'audio/wav',
    );
  }

  static Uint8List _buildRingbackBytes() {
    const sampleRate = 16000;
    const channelCount = 1;
    const bytesPerSample = 2;
    const amplitude = 0.48;
    const segments = <({bool tone, int milliseconds})>[
      (tone: true, milliseconds: 380),
      (tone: false, milliseconds: 220),
      (tone: true, milliseconds: 380),
      (tone: false, milliseconds: 2020),
    ];

    final totalSamples = segments.fold<int>(
      0,
      (count, segment) => count + (sampleRate * segment.milliseconds ~/ 1000),
    );
    final pcmLength = totalSamples * bytesPerSample;
    final bytes = ByteData(44 + pcmLength);

    _writeWavHeader(
      bytes,
      sampleRate: sampleRate,
      channelCount: channelCount,
      bytesPerSample: bytesPerSample,
      pcmLength: pcmLength,
    );

    var sampleOffset = 44;
    for (final segment in segments) {
      final segmentSampleCount = sampleRate * segment.milliseconds ~/ 1000;
      for (
        var sampleIndex = 0;
        sampleIndex < segmentSampleCount;
        sampleIndex++
      ) {
        final sampleValue = segment.tone
            ? _ringbackSample(
                sampleIndex,
                segmentSampleCount,
                sampleRate,
                amplitude,
              )
            : 0.0;
        final pcmValue = (sampleValue * 32767).round().clamp(-32768, 32767);
        bytes.setInt16(sampleOffset, pcmValue, Endian.little);
        sampleOffset += bytesPerSample;
      }
    }

    return bytes.buffer.asUint8List();
  }

  static double _ringbackSample(
    int sampleIndex,
    int totalSamples,
    int sampleRate,
    double amplitude,
  ) {
    final time = sampleIndex / sampleRate;
    final fadeInSamples = math.max(1, (sampleRate * 0.018).round());
    final fadeOutSamples = math.max(1, (sampleRate * 0.05).round());
    final fadeIn = sampleIndex < fadeInSamples
        ? sampleIndex / fadeInSamples
        : 1.0;
    final fadeOut = sampleIndex >= totalSamples - fadeOutSamples
        ? (totalSamples - sampleIndex) / fadeOutSamples
        : 1.0;
    final envelope = math.min(fadeIn, fadeOut).clamp(0.0, 1.0);

    final fundamental = math.sin(2 * math.pi * 425 * time);
    final harmonicA = math.sin(2 * math.pi * 510 * time);
    final harmonicB = math.sin(2 * math.pi * 640 * time);
    final shaped =
        (fundamental * 0.72) + (harmonicA * 0.2) + (harmonicB * 0.08);

    return shaped * amplitude * envelope;
  }

  static void _writeWavHeader(
    ByteData bytes, {
    required int sampleRate,
    required int channelCount,
    required int bytesPerSample,
    required int pcmLength,
  }) {
    final byteRate = sampleRate * channelCount * bytesPerSample;
    final blockAlign = channelCount * bytesPerSample;

    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, 36 + pcmLength, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6D); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); // space
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channelCount, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, blockAlign, Endian.little);
    bytes.setUint16(34, bytesPerSample * 8, Endian.little);
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, pcmLength, Endian.little);
  }
}

class _VoiceCallStage extends StatelessWidget {
  const _VoiceCallStage({
    required this.accentColor,
    required this.session,
    required this.remoteParticipants,
    required this.mediaState,
    this.remoteRenderer,
  });

  final Color accentColor;
  final ChatCallSession session;
  final List<ChatCallParticipant> remoteParticipants;
  final ChatCallMediaState mediaState;
  final RTCVideoRenderer? remoteRenderer;

  @override
  Widget build(BuildContext context) {
    final primary = remoteParticipants.isNotEmpty
        ? remoteParticipants.first
        : session.participants.first;

    return Stack(
      children: [
        if (remoteRenderer != null)
          Positioned(
            left: -4,
            top: -4,
            width: 1,
            height: 1,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: RTCVideoView(remoteRenderer!),
              ),
            ),
          ),
        Column(
          children: [
            const Spacer(),
            _PulseAvatar(accentColor: accentColor, participant: primary),
            const SizedBox(height: 26),
            Text(
              primary.name,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              primary.role,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            if (mediaState.hasRemoteMedia) ...[
              const SizedBox(height: 16),
              Text(
                mediaState.isConnected
                    ? 'Audio tersambung'
                    : 'Menunggu audio lawan bicara...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            if (session.isGroup)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: session.participants
                    .map(
                      (participant) => _VoiceParticipantChip(
                        participant: participant,
                        accentColor: accentColor,
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ],
    );
  }
}

class _VideoCallStage extends StatelessWidget {
  const _VideoCallStage({
    required this.accentColor,
    required this.session,
    required this.mediaState,
    required this.selfParticipant,
    this.localRenderer,
    this.remoteRenderer,
    this.showSelfPreview = false,
    this.isFrontCamera = true,
  });

  final Color accentColor;
  final ChatCallSession session;
  final ChatCallMediaState mediaState;
  final ChatCallParticipant selfParticipant;
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? remoteRenderer;
  final bool showSelfPreview;
  final bool isFrontCamera;

  @override
  Widget build(BuildContext context) {
    final remoteParticipants = session.participants
        .where((participant) => !participant.isCurrentUser)
        .toList(growable: false);
    final itemCount = remoteParticipants.isEmpty
        ? 1
        : remoteParticipants.length;
    final crossAxisCount = itemCount > 1 ? 2 : 1;

    final participant = remoteParticipants.isEmpty
        ? session.participants.first
        : remoteParticipants.first;
    final callTiles = itemCount == 1
        ? _VideoParticipantTile(
            accentColor: accentColor,
            participant: participant,
            renderer: remoteRenderer,
            showLiveVideo: mediaState.hasRemoteVideo,
          )
        : GridView.builder(
            physics: const ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final participant = remoteParticipants[index];
              return _VideoParticipantTile(
                accentColor: accentColor,
                participant: participant,
                renderer: index == 0 ? remoteRenderer : null,
                showLiveVideo:
                    index == 0 &&
                    mediaState.hasRemoteVideo &&
                    participant.isVideoEnabled,
              );
            },
          );

    return Stack(
      children: [
        Positioned.fill(child: callTiles),
        if (remoteRenderer != null && !mediaState.hasRemoteVideo)
          Positioned(
            left: -4,
            top: -4,
            width: 1,
            height: 1,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: RTCVideoView(remoteRenderer!),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: _SelfPreviewCard(
            participant: selfParticipant,
            accentColor: accentColor,
            renderer: localRenderer,
            showLivePreview: showSelfPreview,
            isFrontCamera: isFrontCamera,
          ),
        ),
      ],
    );
  }
}

class _PulseAvatar extends StatelessWidget {
  const _PulseAvatar({required this.accentColor, required this.participant});

  final Color accentColor;
  final ChatCallParticipant participant;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              accentColor.withValues(alpha: 0.92),
              accentColor.withValues(alpha: 0.32),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.36),
              blurRadius: 42,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            _initials(participant.name),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceParticipantChip extends StatelessWidget {
  const _VoiceParticipantChip({
    required this.participant,
    required this.accentColor,
  });

  final ChatCallParticipant participant;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: participant.isSpeaking
              ? Colors.white.withValues(alpha: 0.48)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(participant.name),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            participant.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (participant.isMuted) ...[
            const SizedBox(width: 8),
            const Icon(Icons.mic_off_rounded, color: Colors.white70, size: 18),
          ],
        ],
      ),
    );
  }
}

class _VideoParticipantTile extends StatelessWidget {
  const _VideoParticipantTile({
    required this.accentColor,
    required this.participant,
    this.renderer,
    this.showLiveVideo = false,
  });

  final Color accentColor;
  final ChatCallParticipant participant;
  final RTCVideoRenderer? renderer;
  final bool showLiveVideo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (renderer != null && showLiveVideo)
            RTCVideoView(
              renderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              placeholderBuilder: (_) => _VideoFallbackSurface(
                accentColor: accentColor,
                participant: participant,
              ),
            )
          else
            _VideoFallbackSurface(
              accentColor: accentColor,
              participant: participant,
            ),
          if (participant.isSpeaking)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                    width: 2.2,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.name,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        participant.role,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!participant.isVideoEnabled)
                  const Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                if (participant.isMuted) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.mic_off_rounded,
                    color: Colors.white70,
                    size: 18,
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

class _SelfPreviewCard extends StatelessWidget {
  const _SelfPreviewCard({
    required this.participant,
    required this.accentColor,
    this.renderer,
    this.showLivePreview = false,
    this.isFrontCamera = true,
  });

  final ChatCallParticipant participant;
  final Color accentColor;
  final RTCVideoRenderer? renderer;
  final bool showLivePreview;
  final bool isFrontCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (renderer != null && showLivePreview)
            RTCVideoView(
              renderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: isFrontCamera,
              placeholderBuilder: (_) => _SelfPreviewFallback(
                accentColor: accentColor,
                participant: participant,
              ),
            )
          else
            _SelfPreviewFallback(
              accentColor: accentColor,
              participant: participant,
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Text(
              'You',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoFallbackSurface extends StatelessWidget {
  const _VideoFallbackSurface({
    required this.accentColor,
    required this.participant,
  });

  final Color accentColor;
  final ChatCallParticipant participant;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.76),
            accentColor.withValues(alpha: 0.28),
            const Color(0xFF18110B),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initials(participant.name),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SelfPreviewFallback extends StatelessWidget {
  const _SelfPreviewFallback({
    required this.accentColor,
    required this.participant,
  });

  final Color accentColor;
  final ChatCallParticipant participant;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.42),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              _initials(participant.name),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foregroundColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);
  return parts.map((part) => part.characters.first.toUpperCase()).join();
}
