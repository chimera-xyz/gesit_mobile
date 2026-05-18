import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../data/meeting_workspace_controller.dart';
import '../../models/meeting_models.dart';
import '../../theme/app_theme.dart';

class LiveKitChatCallScreen extends StatefulWidget {
  const LiveKitChatCallScreen({
    super.key,
    required this.controller,
    required this.meeting,
    required this.credentials,
  });

  final MeetingWorkspaceController controller;
  final MeetingSummary meeting;
  final LiveKitJoinCredentials credentials;

  @override
  State<LiveKitChatCallScreen> createState() => _LiveKitChatCallScreenState();
}

class _LiveKitChatCallScreenState extends State<LiveKitChatCallScreen> {
  late MeetingSummary _meeting = widget.meeting;
  late final Room _room;
  late final EventsListener<RoomEvent> _listener;
  Timer? _syncTimer;
  DateTime? _connectedAt;
  bool _connecting = true;
  bool _micEnabled = true;
  bool _cameraEnabled = false;
  bool _speakerEnabled = true;
  bool? _pendingMicEnabled;
  bool? _pendingCameraEnabled;
  bool _isClosingCall = false;
  String? _errorMessage;

  bool get _isVideoCall => _meeting.callMediaType == 'video';
  bool get _recipientReportedOnline =>
      _meeting.settings['call_recipient_online'] == true;
  bool get _hasRemoteParticipant => _room.remoteParticipants.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cameraEnabled = _isVideoCall;
    _room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _listener = _room.createListener();
    _room.addListener(_handleRoomChanged);
    _listener
      ..on<RoomDisconnectedEvent>((event) {
        if (mounted && !_isClosingCall) {
          Navigator.of(context).maybePop();
        }
      })
      ..on<RoomReconnectingEvent>((event) {
        if (mounted) {
          setState(() => _errorMessage = 'Koneksi panggilan dipulihkan...');
        }
      })
      ..on<RoomReconnectedEvent>((event) {
        if (mounted) {
          setState(() => _errorMessage = null);
        }
      })
      ..on<ParticipantEvent>((event) {
        if (mounted) {
          _handleRoomChanged();
        }
      });
    unawaited(_connect());
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _room.removeListener(_handleRoomChanged);
    unawaited(_listener.dispose());
    unawaited(_room.dispose());
    unawaited(widget.controller.leaveMeeting(_meeting.id));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remoteParticipants = _room.remoteParticipants.values.toList();
    final primaryRemote = remoteParticipants.isEmpty
        ? null
        : remoteParticipants.first;
    final localParticipant = _room.localParticipant;
    final remoteVideo = _cameraTrack(primaryRemote);
    final localVideo = _cameraTrack(localParticipant);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_leaveCall());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A1A), Color(0xFF090909)],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _leaveCall,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _callDurationLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                  child: Column(
                    children: [
                      Text(
                        _meeting.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _isVideoCall
                        ? _VideoCallStage(
                            remoteVideo: remoteVideo,
                            localVideo: localVideo,
                            localVideoEnabled: _cameraEnabled,
                          )
                        : _VoiceCallStage(
                            primaryName: primaryRemote?.name.isNotEmpty == true
                                ? primaryRemote!.name
                                : _remoteDisplayName,
                            isConnected: _hasRemoteParticipant,
                          ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CallButton(
                          icon: _micEnabled
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          label: _micEnabled ? 'Mic' : 'Muted',
                          onTap: _toggleMic,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CallButton(
                          icon: _speakerEnabled
                              ? Icons.volume_up_rounded
                              : Icons.hearing_disabled_rounded,
                          label: 'Speaker',
                          onTap: _toggleSpeaker,
                        ),
                      ),
                      if (_isVideoCall) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CallButton(
                            icon: _cameraEnabled
                                ? Icons.videocam_rounded
                                : Icons.videocam_off_rounded,
                            label: 'Camera',
                            onTap: _toggleCamera,
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CallButton(
                          icon: Icons.call_end_rounded,
                          label: 'End',
                          backgroundColor: AppColors.red,
                          onTap: _endCall,
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

  String get _remoteDisplayName {
    final member = _meeting.participants
        .where((item) => !item.isCurrentUser)
        .cast<MeetingMember?>()
        .firstWhere((item) => item != null, orElse: () => null);
    return member?.name ?? 'Panggilan GESIT';
  }

  String get _statusLabel {
    if (_connecting) {
      return 'Menghubungkan...';
    }
    if (!_hasRemoteParticipant) {
      if (_meeting.viewerRole == MeetingRole.host) {
        return _recipientReportedOnline ? 'Berdering...' : 'Memanggil...';
      }
      return 'Menghubungkan...';
    }
    return _isVideoCall ? 'Panggilan video aktif' : 'Panggilan suara aktif';
  }

  String get _callDurationLabel {
    if (_connectedAt == null) {
      return '00:00';
    }
    final elapsed = DateTime.now().difference(_connectedAt!);
    final minutes = (elapsed.inSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _connect() async {
    try {
      await _room.connect(
        widget.credentials.url,
        widget.credentials.token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );
      await _room.localParticipant?.setMicrophoneEnabled(true);
      if (_isVideoCall) {
        await _room.localParticipant?.setCameraEnabled(true);
      }
      if (lkPlatformIs(PlatformType.android) ||
          lkPlatformIs(PlatformType.iOS)) {
        await Hardware.instance.setSpeakerphoneOn(true);
      }
      _syncTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => unawaited(_syncMeetingState()),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _errorMessage = 'Tidak bisa tersambung ke panggilan LiveKit.';
        });
      }
    }
  }

  Future<void> _syncMeetingState() async {
    final refreshed = await widget.controller.refreshMeeting(_meeting.id);
    if (!mounted || refreshed == null) {
      return;
    }
    setState(() => _meeting = refreshed);
    if (_meeting.status == MeetingStatus.ended ||
        _meeting.status == MeetingStatus.cancelled) {
      _isClosingCall = true;
      await _room.disconnect();
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
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

  Future<void> _toggleMic() async {
    if (_pendingMicEnabled != null) {
      return;
    }

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

  Future<void> _leaveCall() async {
    _isClosingCall = true;
    await widget.controller.leaveMeeting(_meeting.id);
    await _room.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _endCall() async {
    _isClosingCall = true;
    await widget.controller.endMeeting(_meeting.id);
    await _room.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
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
  const _VoiceCallStage({required this.primaryName, required this.isConnected});

  final String primaryName;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 70,
          backgroundColor: AppColors.goldDeep.withValues(alpha: 0.18),
          child: Text(
            _initials(primaryName),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          primaryName,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          isConnected ? 'Audio tersambung' : 'Menyiapkan audio...',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
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
  });

  final VideoTrack? remoteVideo;
  final VideoTrack? localVideo;
  final bool localVideoEnabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: remoteVideo == null
                ? Container(
                    color: const Color(0xFF181818),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white54,
                      size: 72,
                    ),
                  )
                : VideoTrackRenderer(remoteVideo!),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 14,
          width: 112,
          height: 158,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: localVideoEnabled && localVideo != null
                ? VideoTrackRenderer(localVideo!)
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
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty);
  return words.take(2).map((item) => item[0].toUpperCase()).join();
}
