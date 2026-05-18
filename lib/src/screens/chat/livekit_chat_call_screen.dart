import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../data/chat_workspace_controller.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';

class LiveKitChatCallScreen extends StatefulWidget {
  const LiveKitChatCallScreen({
    super.key,
    required this.controller,
    required this.conversationId,
  });

  final ChatWorkspaceController controller;
  final String conversationId;

  @override
  State<LiveKitChatCallScreen> createState() => _LiveKitChatCallScreenState();
}

class _LiveKitChatCallScreenState extends State<LiveKitChatCallScreen> {
  late final Room _room;
  late final EventsListener<RoomEvent> _listener;
  late final AudioPlayer _ringbackPlayer;
  final _RingbackToneSource _ringbackToneSource = _RingbackToneSource();

  bool _connecting = false;
  bool _roomConnected = false;
  bool _isClosing = false;
  bool _micEnabled = true;
  bool _cameraEnabled = false;
  bool _speakerEnabled = true;
  bool? _pendingMicEnabled;
  bool? _pendingCameraEnabled;
  bool _ringbackReady = false;
  bool _ringbackStartInFlight = false;
  DateTime? _connectedAt;
  Timer? _durationTicker;
  Timer? _activityHeartbeatTimer;
  String? _errorMessage;

  ChatCallSession? get _session {
    final activeCall = widget.controller.activeCall;
    if (activeCall?.conversationId != widget.conversationId) {
      return null;
    }
    return activeCall;
  }

  bool get _hasRemoteParticipant => _room.remoteParticipants.isNotEmpty;
  bool get _isIncomingRinging =>
      _session?.isIncoming == true &&
      _session?.status == ChatCallStatus.ringing;

  @override
  void initState() {
    super.initState();
    _ringbackPlayer = AudioPlayer();
    _room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _listener = _room.createListener();
    _room.addListener(_handleRoomChanged);
    _listener
      ..on<RoomDisconnectedEvent>((event) {
        if (mounted && !_isClosing) {
          setState(() {
            _roomConnected = false;
            _connectedAt = null;
          });
        }
      })
      ..on<RoomReconnectingEvent>((event) {
        if (mounted) {
          setState(
            () => _errorMessage = 'Koneksi panggilan sedang dipulihkan...',
          );
        }
      })
      ..on<RoomReconnectedEvent>((event) {
        if (mounted) {
          setState(() => _errorMessage = null);
        }
      })
      ..on<ParticipantEvent>((event) => _handleRoomChanged());

    widget.controller.addListener(_handleControllerUpdate);
    _syncFromSession();
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    _stopActivityHeartbeat();
    widget.controller.removeListener(_handleControllerUpdate);
    _room.removeListener(_handleRoomChanged);
    unawaited(_stopRingbackTone());
    unawaited(_ringbackPlayer.dispose());
    unawaited(_listener.dispose());
    unawaited(_room.dispose());
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (!mounted) {
      return;
    }
    _syncFromSession();
  }

  void _syncFromSession() {
    final session = _session;
    _syncRingbackTone();

    if (session == null || _isTerminal(session.status)) {
      _isClosing = true;
      _stopActivityHeartbeat();
      unawaited(_room.disconnect());
      _schedulePop();
      return;
    }

    if (!_roomConnected) {
      _micEnabled = _pendingMicEnabled ?? session.micEnabled;
      _cameraEnabled = _pendingCameraEnabled ?? session.cameraEnabled;
      _speakerEnabled = session.speakerEnabled;
    }

    if (!_isIncomingRinging && !_roomConnected && !_connecting) {
      unawaited(_connectIfReady(session));
    }

    setState(() {});
  }

  bool _isTerminal(ChatCallStatus status) {
    return status == ChatCallStatus.ended ||
        status == ChatCallStatus.missed ||
        status == ChatCallStatus.declined;
  }

  void _schedulePop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  void _syncRingbackTone() {
    if (_shouldPlayRingbackTone) {
      unawaited(_startRingbackTone());
    } else {
      unawaited(_stopRingbackTone());
    }
  }

  bool get _shouldPlayRingbackTone {
    final session = _session;
    return session != null &&
        !session.isIncoming &&
        session.status == ChatCallStatus.ringing;
  }

  Future<void> _startRingbackTone() async {
    if (_ringbackStartInFlight || _ringbackPlayer.playing) {
      return;
    }

    _ringbackStartInFlight = true;
    try {
      if (!_ringbackReady) {
        await _ringbackPlayer.setLoopMode(LoopMode.one);
        await _ringbackPlayer.setVolume(0.82);
        await _ringbackPlayer.setAudioSource(_ringbackToneSource);
        _ringbackReady = true;
      }
      if (!_shouldPlayRingbackTone) {
        return;
      }
      await _ringbackPlayer.seek(Duration.zero);
      await _ringbackPlayer.play();
    } catch (_) {
      // Ringback is UX polish; never block the call flow on audio failures.
    } finally {
      _ringbackStartInFlight = false;
    }
  }

  Future<void> _stopRingbackTone() async {
    try {
      await _ringbackPlayer.pause();
      if (_ringbackReady) {
        await _ringbackPlayer.seek(Duration.zero);
      }
    } catch (_) {}
  }

  Future<void> _connectIfReady(ChatCallSession session) async {
    final credentials = session.liveKit;
    if (credentials == null || !credentials.isComplete) {
      setState(() {
        _errorMessage =
            'Media panggilan belum siap. Periksa konfigurasi server.';
      });
      return;
    }

    _connecting = true;
    setState(() => _errorMessage = null);
    try {
      await _room.connect(
        credentials.url,
        credentials.token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );
      await _room.localParticipant?.setMicrophoneEnabled(session.micEnabled);
      if (session.type == ChatCallType.video) {
        await _room.localParticipant?.setCameraEnabled(session.cameraEnabled);
      }
      if (lkPlatformIs(PlatformType.android) ||
          lkPlatformIs(PlatformType.iOS)) {
        await Hardware.instance.setSpeakerphoneOn(session.speakerEnabled);
      }
      _durationTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _roomConnected = true;
        if (_hasRemoteParticipant && _connectedAt == null) {
          _connectedAt = DateTime.now();
        }
      });
      _startActivityHeartbeat();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _roomConnected = false;
        _errorMessage = 'Tidak bisa menyambungkan media panggilan.';
      });
    }
  }

  void _startActivityHeartbeat() {
    if (_activityHeartbeatTimer != null) {
      return;
    }

    unawaited(_sendActivityHeartbeat());
    _activityHeartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_sendActivityHeartbeat());
    });
  }

  void _stopActivityHeartbeat() {
    _activityHeartbeatTimer?.cancel();
    _activityHeartbeatTimer = null;
  }

  Future<void> _sendActivityHeartbeat() async {
    final session = _session;
    if (session == null ||
        session.status != ChatCallStatus.active ||
        !_roomConnected ||
        _isClosing) {
      return;
    }

    await widget.controller.sendActiveCallSignal(
      'media_state',
      payload: {
        'mic_enabled': _micEnabled,
        'camera_enabled': _cameraEnabled,
        'speaker_enabled': _speakerEnabled,
        'call_type': session.type.storageValue,
      },
    );
  }

  void _handleRoomChanged() {
    if (!mounted) {
      return;
    }

    final local = _room.localParticipant;
    final localMicEnabled = local?.isMicrophoneEnabled();
    final localCameraEnabled = local?.isCameraEnabled();
    setState(() {
      if (_hasRemoteParticipant && _connectedAt == null) {
        _connectedAt = DateTime.now();
      }
      if (_pendingMicEnabled != null && localMicEnabled == _pendingMicEnabled) {
        _pendingMicEnabled = null;
      }
      if (_pendingCameraEnabled != null &&
          localCameraEnabled == _pendingCameraEnabled) {
        _pendingCameraEnabled = null;
      }
      _micEnabled = _pendingMicEnabled ?? localMicEnabled ?? _micEnabled;
      _cameraEnabled =
          _pendingCameraEnabled ?? localCameraEnabled ?? _cameraEnabled;
    });
  }

  Future<void> _acceptCall() async {
    await widget.controller.acceptActiveCall();
    final session = _session;
    if (session != null && !_roomConnected) {
      await _connectIfReady(session);
    }
  }

  Future<void> _declineOrEndCall() async {
    _isClosing = true;
    final session = _session;
    if (session == null) {
      _schedulePop();
      return;
    }

    if (session.isIncoming && session.status == ChatCallStatus.ringing) {
      await widget.controller.declineActiveCall();
    } else {
      await widget.controller.endActiveCall();
    }
    await _room.disconnect();
    _schedulePop();
  }

  Future<void> _toggleMic() async {
    if (_pendingMicEnabled != null) {
      return;
    }

    widget.controller.toggleActiveCallMic();
    final next = !_micEnabled;
    setState(() {
      _pendingMicEnabled = next;
      _micEnabled = next;
    });
    try {
      await _room.localParticipant?.setMicrophoneEnabled(next);
      _handleRoomChanged();
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingMicEnabled = null;
          _micEnabled = !next;
        });
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    widget.controller.toggleActiveCallSpeaker();
    final next = !_speakerEnabled;
    setState(() => _speakerEnabled = next);
    if (lkPlatformIs(PlatformType.android) || lkPlatformIs(PlatformType.iOS)) {
      await Hardware.instance.setSpeakerphoneOn(next);
    }
  }

  Future<void> _toggleCamera() async {
    if (_pendingCameraEnabled != null) {
      return;
    }

    widget.controller.toggleActiveCallCamera();
    final next = !_cameraEnabled;
    setState(() {
      _pendingCameraEnabled = next;
      _cameraEnabled = next;
    });
    try {
      await _room.localParticipant?.setCameraEnabled(next);
      _handleRoomChanged();
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingCameraEnabled = null;
          _cameraEnabled = !next;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final remoteParticipants = _room.remoteParticipants.values.toList();
    final primaryRemote = remoteParticipants.isEmpty
        ? null
        : remoteParticipants.first;
    final remoteVideo = _cameraTrack(primaryRemote);
    final localVideo = _cameraTrack(_room.localParticipant);
    final remoteName = _remoteDisplayName(session, primaryRemote);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_declineOrEndCall());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _accentColor(session).withValues(alpha: 0.94),
                const Color(0xFF17110A),
                const Color(0xFF050505),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => unawaited(_declineOrEndCall()),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _durationLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Column(
                    children: [
                      Text(
                        session.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusLabel(session),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: session.type == ChatCallType.video
                        ? _VideoCallStage(
                            remoteVideo: remoteVideo,
                            localVideo: localVideo,
                            localVideoEnabled: _cameraEnabled,
                            accentColor: _accentColor(session),
                            placeholderName: remoteName,
                          )
                        : _VoiceCallStage(
                            primaryName: remoteName,
                            roleLabel: _remoteRoleLabel(session),
                            accentColor: _accentColor(session),
                            isConnected:
                                _roomConnected && _hasRemoteParticipant,
                          ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _CallNotice(message: _errorMessage!),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  child: _isIncomingRinging
                      ? Row(
                          children: [
                            Expanded(
                              child: _CallButton(
                                icon: Icons.call_end_rounded,
                                label: 'Tolak',
                                backgroundColor: AppColors.red,
                                onTap: () => unawaited(_declineOrEndCall()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CallButton(
                                icon: Icons.call_rounded,
                                label: 'Terima',
                                backgroundColor: AppColors.emerald,
                                onTap: () => unawaited(_acceptCall()),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _CallButton(
                                icon: _micEnabled
                                    ? Icons.mic_rounded
                                    : Icons.mic_off_rounded,
                                label: _micEnabled ? 'Mic' : 'Muted',
                                onTap: () => unawaited(_toggleMic()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CallButton(
                                icon: _speakerEnabled
                                    ? Icons.volume_up_rounded
                                    : Icons.hearing_disabled_rounded,
                                label: 'Speaker',
                                onTap: () => unawaited(_toggleSpeaker()),
                              ),
                            ),
                            if (session.type == ChatCallType.video) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: _CallButton(
                                  icon: _cameraEnabled
                                      ? Icons.videocam_rounded
                                      : Icons.videocam_off_rounded,
                                  label: 'Camera',
                                  onTap: () => unawaited(_toggleCamera()),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CallButton(
                                icon: Icons.call_end_rounded,
                                label: 'End',
                                backgroundColor: AppColors.red,
                                onTap: () => unawaited(_declineOrEndCall()),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _remoteDisplayName(ChatCallSession session, Participant? remote) {
    if (remote?.name.isNotEmpty == true) {
      return remote!.name;
    }
    final remoteParticipant = session.participants
        .where((participant) => !participant.isCurrentUser)
        .cast<ChatCallParticipant?>()
        .firstWhere((participant) => participant != null, orElse: () => null);
    return remoteParticipant?.name ?? session.title;
  }

  String _remoteRoleLabel(ChatCallSession session) {
    final remoteParticipant = session.participants
        .where((participant) => !participant.isCurrentUser)
        .cast<ChatCallParticipant?>()
        .firstWhere((participant) => participant != null, orElse: () => null);
    return remoteParticipant?.role ?? (session.isGroup ? 'Grup chat' : 'GESIT');
  }

  Color _accentColor(ChatCallSession session) {
    final remoteParticipant = session.participants
        .where((participant) => !participant.isCurrentUser)
        .cast<ChatCallParticipant?>()
        .firstWhere((participant) => participant != null, orElse: () => null);
    return remoteParticipant?.accentColor ?? AppColors.goldDeep;
  }

  String _statusLabel(ChatCallSession session) {
    if (session.isIncoming && session.status == ChatCallStatus.ringing) {
      return session.type == ChatCallType.video
          ? 'Video call masuk'
          : 'Panggilan suara masuk';
    }
    if (_connecting) {
      return session.type == ChatCallType.video
          ? 'Menyiapkan kamera dan mikrofon...'
          : 'Menyiapkan mikrofon...';
    }
    if (session.status == ChatCallStatus.ringing) {
      return session.isGroup ? 'Berdering ke grup...' : 'Berdering...';
    }
    if (session.status == ChatCallStatus.active) {
      if (!_hasRemoteParticipant) {
        return 'Menunggu lawan bicara tersambung...';
      }
      return session.type == ChatCallType.video
          ? 'Video call aktif'
          : 'Panggilan aktif';
    }
    return session.status.label;
  }

  String get _durationLabel {
    if (_connectedAt == null) {
      return '00:00';
    }
    final elapsed = DateTime.now().difference(_connectedAt!);
    final minutes = (elapsed.inSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  VideoTrack? _cameraTrack(Participant? participant) {
    final publication = participant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    if (track is VideoTrack && publication?.muted == false) {
      return track;
    }
    return null;
  }
}

class _VoiceCallStage extends StatelessWidget {
  const _VoiceCallStage({
    required this.primaryName,
    required this.roleLabel,
    required this.accentColor,
    required this.isConnected,
  });

  final String primaryName;
  final String roleLabel;
  final Color accentColor;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 156,
          height: 156,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.36),
                blurRadius: 42,
                spreadRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(primaryName),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          primaryName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          roleLabel,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          isConnected ? 'Audio tersambung' : 'Menunggu audio tersambung...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _VideoCallStage extends StatelessWidget {
  const _VideoCallStage({
    required this.remoteVideo,
    required this.localVideo,
    required this.localVideoEnabled,
    required this.accentColor,
    required this.placeholderName,
  });

  final VideoTrack? remoteVideo;
  final VideoTrack? localVideo;
  final bool localVideoEnabled;
  final Color accentColor;
  final String placeholderName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: remoteVideo == null
                ? Container(
                    color: Colors.white.withValues(alpha: 0.08),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: accentColor.withValues(alpha: 0.25),
                          child: Text(
                            _initials(placeholderName),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Menunggu video tersambung...',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  )
                : VideoTrackRenderer(remoteVideo!, fit: VideoViewFit.cover),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 14,
          width: 112,
          height: 158,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: localVideoEnabled && localVideo != null
                ? VideoTrackRenderer(localVideo!, fit: VideoViewFit.cover)
                : Container(
                    color: const Color(0xFF252525),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.white54,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallNotice extends StatelessWidget {
  const _CallNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
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
    const bytesPerSample = 2;
    const amplitude = 0.42;
    const segments = <({bool tone, int milliseconds})>[
      (tone: true, milliseconds: 420),
      (tone: false, milliseconds: 240),
      (tone: true, milliseconds: 420),
      (tone: false, milliseconds: 1960),
    ];

    final totalSamples = segments.fold<int>(
      0,
      (count, segment) => count + (sampleRate * segment.milliseconds ~/ 1000),
    );
    final pcmLength = totalSamples * bytesPerSample;
    final bytes = ByteData(44 + pcmLength);
    _writeWavHeader(bytes, sampleRate: sampleRate, pcmLength: pcmLength);

    var offset = 44;
    for (final segment in segments) {
      final sampleCount = sampleRate * segment.milliseconds ~/ 1000;
      for (var i = 0; i < sampleCount; i++) {
        final value = segment.tone
            ? _sample(i, sampleCount, sampleRate, amplitude)
            : 0.0;
        bytes.setInt16(
          offset,
          (value * 32767).round().clamp(-32768, 32767),
          Endian.little,
        );
        offset += bytesPerSample;
      }
    }

    return bytes.buffer.asUint8List();
  }

  static double _sample(
    int index,
    int total,
    int sampleRate,
    double amplitude,
  ) {
    final time = index / sampleRate;
    final fadeIn = math.min(1.0, index / math.max(1, sampleRate * 0.018));
    final fadeOut = math.min(
      1.0,
      (total - index) / math.max(1, sampleRate * 0.05),
    );
    final envelope = math.min(fadeIn, fadeOut);
    final tone =
        math.sin(2 * math.pi * 425 * time) * 0.74 +
        math.sin(2 * math.pi * 510 * time) * 0.18 +
        math.sin(2 * math.pi * 640 * time) * 0.08;
    return tone * amplitude * envelope;
  }

  static void _writeWavHeader(
    ByteData bytes, {
    required int sampleRate,
    required int pcmLength,
  }) {
    const channelCount = 1;
    const bytesPerSample = 2;
    final byteRate = sampleRate * channelCount * bytesPerSample;
    final blockAlign = channelCount * bytesPerSample;

    bytes.setUint8(0, 0x52);
    bytes.setUint8(1, 0x49);
    bytes.setUint8(2, 0x46);
    bytes.setUint8(3, 0x46);
    bytes.setUint32(4, 36 + pcmLength, Endian.little);
    bytes.setUint8(8, 0x57);
    bytes.setUint8(9, 0x41);
    bytes.setUint8(10, 0x56);
    bytes.setUint8(11, 0x45);
    bytes.setUint8(12, 0x66);
    bytes.setUint8(13, 0x6D);
    bytes.setUint8(14, 0x74);
    bytes.setUint8(15, 0x20);
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channelCount, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, blockAlign, Endian.little);
    bytes.setUint16(34, bytesPerSample * 8, Endian.little);
    bytes.setUint8(36, 0x64);
    bytes.setUint8(37, 0x61);
    bytes.setUint8(38, 0x74);
    bytes.setUint8(39, 0x61);
    bytes.setUint32(40, pcmLength, Endian.little);
  }
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty);
  return words.take(2).map((item) => item[0].toUpperCase()).join();
}
