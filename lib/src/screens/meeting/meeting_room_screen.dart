import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../data/meeting_workspace_controller.dart';
import '../../models/meeting_models.dart';
import '../../theme/app_theme.dart';

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({
    super.key,
    required this.controller,
    required this.meeting,
    required this.credentials,
  });

  final MeetingWorkspaceController controller;
  final MeetingSummary meeting;
  final LiveKitJoinCredentials credentials;

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  late MeetingSummary _meeting = widget.meeting;
  late final Room _room;
  late final EventsListener<RoomEvent> _listener;
  final TextEditingController _chatController = TextEditingController();
  final ValueNotifier<List<_MeetingChatMessage>> _messages =
      ValueNotifier<List<_MeetingChatMessage>>(<_MeetingChatMessage>[]);
  Timer? _syncTimer;
  bool _joined = false;
  bool _connecting = false;
  bool _micEnabled = true;
  bool _cameraEnabled = false;
  bool? _pendingMicEnabled;
  bool? _pendingCameraEnabled;
  bool _screenShareEnabled = false;
  bool _speakerEnabled = true;
  bool _isChatPanelOpen = false;
  bool _isClosingRoom = false;
  String? _selectedRecipientIdentity;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _listener = _room.createListener();
    _room.addListener(_handleRoomChanged);
    _setUpRoomListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _chatController.dispose();
    _messages.dispose();
    _room.removeListener(_handleRoomChanged);
    unawaited(_listener.dispose());
    unawaited(_room.dispose());
    unawaited(widget.controller.leaveMeeting(_meeting.id));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_joined) {
      return _PreJoinView(
        meeting: _meeting,
        micEnabled: _micEnabled,
        cameraEnabled: _cameraEnabled,
        connecting: _connecting,
        errorMessage: _errorMessage,
        onMicChanged: (value) => setState(() => _micEnabled = value),
        onCameraChanged: (value) => setState(() => _cameraEnabled = value),
        onJoin: _connect,
      );
    }

    final participants = _participants;
    final screenShareTrack = _screenShareTrack(participants);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_leaveRoom());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101010),
        body: SafeArea(
          child: Column(
            children: [
              _MeetingTopBar(
                title: _meeting.title,
                statusLabel: _room.connectionState.name,
                participantCount: participants.length,
                recordingEnabled:
                    _meeting.settings['record_by_default'] == true,
                onOpenParticipants: _openParticipantsPanel,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: screenShareTrack == null
                      ? _VideoGrid(participants: participants)
                      : _ScreenShareStage(
                          screenShareTrack: screenShareTrack,
                          participants: participants,
                        ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: _RoomNotice(message: _errorMessage!),
                ),
              _MeetingControlBar(
                micEnabled: _micEnabled,
                cameraEnabled: _cameraEnabled,
                screenShareEnabled: _screenShareEnabled,
                speakerEnabled: _speakerEnabled,
                canModerate: _meeting.canModerate,
                onToggleMic: _toggleMic,
                onToggleCamera: _toggleCamera,
                onToggleScreenShare: _toggleScreenShare,
                onToggleSpeaker: _toggleSpeaker,
                onOpenChat: _openChatPanel,
                onOpenMore: _openMorePanel,
                onLeave: _leaveRoom,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Participant> get _participants {
    final local = _room.localParticipant;
    return [if (local != null) local, ..._room.remoteParticipants.values];
  }

  void _setUpRoomListeners() {
    _listener
      ..on<RoomDisconnectedEvent>((event) {
        if (mounted && !_isClosingRoom) {
          Navigator.of(context).maybePop();
        }
      })
      ..on<RoomReconnectingEvent>((event) {
        if (mounted) {
          setState(
            () => _errorMessage = 'Koneksi meeting sedang dipulihkan...',
          );
        }
      })
      ..on<RoomReconnectedEvent>((event) {
        if (mounted) {
          setState(() => _errorMessage = null);
        }
      })
      ..on<ParticipantEvent>((event) {
        if (mounted) {
          setState(() {});
        }
      })
      ..on<DataReceivedEvent>(_handleDataReceived);
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _errorMessage = null;
    });

    try {
      await _room.connect(
        widget.credentials.url,
        widget.credentials.token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );
      await _room.localParticipant?.setMicrophoneEnabled(_micEnabled);
      if (_cameraEnabled) {
        await _room.localParticipant?.setCameraEnabled(true);
      }
      if (lkPlatformIs(PlatformType.android)) {
        await Hardware.instance.setSpeakerphoneOn(true);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _joined = true;
        _connecting = false;
      });
      _syncTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => unawaited(_syncMeetingState()),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _errorMessage = 'Tidak bisa tersambung ke LiveKit room.';
      });
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
      _screenShareEnabled =
          local?.isScreenShareEnabled() ?? _screenShareEnabled;
    });
  }

  void _handleDataReceived(DataReceivedEvent event) {
    if (event.topic == 'gesit.meeting.sync') {
      unawaited(_syncMeetingState());
      return;
    }
    if (event.topic != 'gesit.meeting.chat') {
      return;
    }

    try {
      final payload = jsonDecode(utf8.decode(event.data));
      if (payload is! Map) {
        return;
      }

      final message = _MeetingChatMessage(
        senderName: event.participant?.name.isNotEmpty == true
            ? event.participant!.name
            : event.participant?.identity ?? 'Participant',
        text: '${payload['text'] ?? ''}',
        isMine: false,
        sentAt: DateTime.now(),
        recipientLabel: payload['recipient_label'] == null
            ? null
            : '${payload['recipient_label']}',
        isPrivate: payload['private'] == true,
      );
      _appendChatMessage(message);
      if (!_isChatPanelOpen && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('${message.senderName}: ${message.text}'),
          ),
        );
      }
    } catch (_) {
      return;
    }
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

  Future<void> _toggleSpeaker() async {
    final next = !_speakerEnabled;
    setState(() => _speakerEnabled = next);
    if (lkPlatformIs(PlatformType.android) || lkPlatformIs(PlatformType.iOS)) {
      await Hardware.instance.setSpeakerphoneOn(next);
    }
  }

  Future<void> _toggleScreenShare() async {
    final next = !_screenShareEnabled;
    setState(() => _screenShareEnabled = next);

    try {
      if (next && lkPlatformIs(PlatformType.android)) {
        var hasPermissions = await FlutterBackground.hasPermissions;
        if (!hasPermissions) {
          const androidConfig = FlutterBackgroundAndroidConfig(
            notificationTitle: 'GESIT Meeting',
            notificationText: 'Screen sharing sedang aktif.',
            notificationImportance: AndroidNotificationImportance.normal,
            notificationIcon: AndroidResource(
              name: 'ic_launcher',
              defType: 'mipmap',
            ),
          );
          hasPermissions = await FlutterBackground.initialize(
            androidConfig: androidConfig,
          );
        }
        if (hasPermissions && !FlutterBackground.isBackgroundExecutionEnabled) {
          await FlutterBackground.enableBackgroundExecution();
        }
      }

      await _room.localParticipant?.setScreenShareEnabled(
        next,
        captureScreenAudio: true,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _screenShareEnabled = !next;
          _errorMessage =
              'Screen share belum bisa diaktifkan di perangkat ini.';
        });
      }
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _chatController.clear();
    final recipient = _recipientForIdentity(_selectedRecipientIdentity);
    final message = _MeetingChatMessage(
      senderName: 'Saya',
      text: text,
      isMine: true,
      sentAt: DateTime.now(),
      recipientLabel: recipient?.name,
      isPrivate: recipient != null,
    );
    _appendChatMessage(message);

    await _room.localParticipant?.publishData(
      utf8.encode(
        jsonEncode({
          'text': text,
          'private': recipient != null,
          if (recipient != null) 'recipient_label': recipient.name,
        }),
      ),
      reliable: true,
      destinationIdentities: recipient == null
          ? null
          : <String>['gesit-user-${recipient.id}'],
      topic: 'gesit.meeting.chat',
    );
  }

  Future<void> _leaveRoom() async {
    _isClosingRoom = true;
    await widget.controller.leaveMeeting(_meeting.id);
    await _room.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _endMeetingForAll() async {
    _isClosingRoom = true;
    await widget.controller.endMeeting(_meeting.id);
    await _room.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
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
      _isClosingRoom = true;
      await _room.disconnect();
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _appendChatMessage(_MeetingChatMessage message) {
    _messages.value = <_MeetingChatMessage>[..._messages.value, message];
  }

  MeetingMember? _recipientForIdentity(String? identity) {
    if (identity == null) {
      return null;
    }
    for (final member in _meeting.participants) {
      if ('gesit-user-${member.id}' == identity) {
        return member;
      }
    }
    return null;
  }

  VideoTrack? _screenShareTrack(List<Participant> participants) {
    for (final participant in participants) {
      final publication = participant.getTrackPublicationBySource(
        TrackSource.screenShareVideo,
      );
      final track = publication?.track;
      if (track is VideoTrack && publication?.muted == false) {
        return track;
      }
    }
    return null;
  }

  void _openChatPanel() {
    _isChatPanelOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MeetingChatSheet(
        messages: _messages,
        controller: _chatController,
        recipients: _meeting.participants
            .where((item) => !item.isCurrentUser)
            .toList(growable: false),
        selectedRecipientIdentity: _selectedRecipientIdentity,
        onRecipientChanged: (value) {
          setState(() => _selectedRecipientIdentity = value);
        },
        onSend: _sendChatMessage,
      ),
    ).whenComplete(() => _isChatPanelOpen = false);
  }

  void _openParticipantsPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ParticipantsSheet(meeting: _meeting, participants: _participants),
    );
  }

  void _openMorePanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MeetingMoreSheet(
        meeting: _meeting,
        controller: widget.controller,
        onPollUpdated: (poll) {
          final polls = List<MeetingPoll>.from(_meeting.polls);
          final index = polls.indexWhere((item) => item.id == poll.id);
          if (index == -1) {
            polls.insert(0, poll);
          } else {
            polls[index] = poll;
          }
          setState(() => _meeting = _meeting.copyWith(polls: polls));
          unawaited(_publishSyncSignal());
        },
        onMeetingUpdated: (meeting) {
          setState(() => _meeting = meeting);
          unawaited(_publishSyncSignal());
        },
        onEndMeeting: _meeting.canModerate ? _endMeetingForAll : null,
      ),
    );
  }

  Future<void> _publishSyncSignal() async {
    await _room.localParticipant?.publishData(
      utf8.encode(jsonEncode({'type': 'meeting_updated'})),
      reliable: true,
      topic: 'gesit.meeting.sync',
    );
  }
}

class _PreJoinView extends StatelessWidget {
  const _PreJoinView({
    required this.meeting,
    required this.micEnabled,
    required this.cameraEnabled,
    required this.connecting,
    required this.onMicChanged,
    required this.onCameraChanged,
    required this.onJoin,
    this.errorMessage,
  });

  final MeetingSummary meeting;
  final bool micEnabled;
  final bool cameraEnabled;
  final bool connecting;
  final ValueChanged<bool> onMicChanged;
  final ValueChanged<bool> onCameraChanged;
  final VoidCallback onJoin;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1D1D),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Icon(
                    cameraEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                meeting.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '${meeting.participants.length} participant • ${meeting.viewerRole.label}',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                _RoomNotice(message: errorMessage!),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  _PreJoinToggle(
                    selected: micEnabled,
                    icon: micEnabled
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    label: micEnabled ? 'Mic on' : 'Mic off',
                    onTap: () => onMicChanged(!micEnabled),
                  ),
                  const SizedBox(width: 10),
                  _PreJoinToggle(
                    selected: cameraEnabled,
                    icon: cameraEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    label: cameraEnabled ? 'Camera on' : 'Camera off',
                    onTap: () => onCameraChanged(!cameraEnabled),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: connecting ? null : onJoin,
                  icon: connecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(connecting ? 'Connecting...' : 'Join meeting'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreJoinToggle extends StatelessWidget {
  const _PreJoinToggle({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.goldDeep : const Color(0xFF242424),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingTopBar extends StatelessWidget {
  const _MeetingTopBar({
    required this.title,
    required this.statusLabel,
    required this.participantCount,
    required this.recordingEnabled,
    required this.onOpenParticipants,
  });

  final String title;
  final String statusLabel;
  final int participantCount;
  final bool recordingEnabled;
  final VoidCallback onOpenParticipants;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (recordingEnabled)
            const _TopBadge(
              icon: Icons.fiber_manual_record_rounded,
              label: 'REC',
            ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF202020),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onOpenParticipants,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$participantCount',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.red, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({required this.participants});

  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final crossAxisCount = participants.length <= 2 ? 1 : 2;

    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: participants.length <= 2 ? 0.82 : 0.78,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) => _ParticipantTile(
        participant: participants[index],
        large: participants.length <= 2,
      ),
    );
  }
}

class _ScreenShareStage extends StatelessWidget {
  const _ScreenShareStage({
    required this.screenShareTrack,
    required this.participants,
  });

  final VideoTrack screenShareTrack;
  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: ColoredBox(
              color: Colors.black,
              child: VideoTrackRenderer(
                screenShareTrack,
                fit: VideoViewFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: participants.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => SizedBox(
              width: 128,
              child: _ParticipantTile(participant: participants[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, this.large = false});

  final Participant participant;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final track = _cameraTrack(participant);
    final name = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFF202020),
            child: track == null
                ? Center(
                    child: CircleAvatar(
                      radius: large ? 40 : 28,
                      backgroundColor: AppColors.goldDeep.withValues(
                        alpha: 0.18,
                      ),
                      child: Text(
                        _initials(name),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: large ? 24 : 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                : VideoTrackRenderer(track, fit: VideoViewFit.cover),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  participant.isMicrophoneEnabled()
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  VideoTrack? _cameraTrack(Participant participant) {
    final publication = participant.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    if (track is VideoTrack && publication?.muted == false) {
      return track;
    }
    return null;
  }
}

class _MeetingControlBar extends StatelessWidget {
  const _MeetingControlBar({
    required this.micEnabled,
    required this.cameraEnabled,
    required this.screenShareEnabled,
    required this.speakerEnabled,
    required this.canModerate,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onToggleSpeaker,
    required this.onOpenChat,
    required this.onOpenMore,
    required this.onLeave,
  });

  final bool micEnabled;
  final bool cameraEnabled;
  final bool screenShareEnabled;
  final bool speakerEnabled;
  final bool canModerate;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMore;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF303030)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ControlButton(
                  icon: micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                  active: micEnabled,
                  onTap: onToggleMic,
                ),
                _ControlButton(
                  icon: cameraEnabled
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  active: cameraEnabled,
                  onTap: onToggleCamera,
                ),
                _ControlButton(
                  icon: screenShareEnabled
                      ? Icons.stop_screen_share_rounded
                      : Icons.screen_share_rounded,
                  active: screenShareEnabled,
                  onTap: onToggleScreenShare,
                ),
                _ControlButton(
                  icon: speakerEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  active: speakerEnabled,
                  onTap: onToggleSpeaker,
                ),
                _ControlButton(
                  icon: Icons.chat_bubble_rounded,
                  onTap: onOpenChat,
                ),
                _ControlButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: onOpenMore,
                ),
                _ControlButton(
                  icon: Icons.call_end_rounded,
                  destructive: true,
                  onTap: onLeave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.red
        : active
        ? AppColors.goldDeep
        : const Color(0xFF2B2B2B);

    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _MeetingChatSheet extends StatefulWidget {
  const _MeetingChatSheet({
    required this.messages,
    required this.controller,
    required this.recipients,
    required this.selectedRecipientIdentity,
    required this.onRecipientChanged,
    required this.onSend,
  });

  final ValueListenable<List<_MeetingChatMessage>> messages;
  final TextEditingController controller;
  final List<MeetingMember> recipients;
  final String? selectedRecipientIdentity;
  final ValueChanged<String?> onRecipientChanged;
  final VoidCallback onSend;

  @override
  State<_MeetingChatSheet> createState() => _MeetingChatSheetState();
}

class _MeetingChatSheetState extends State<_MeetingChatSheet> {
  late String? _selectedRecipientIdentity = widget.selectedRecipientIdentity;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + bottomInset),
        child: _DarkSheet(
          title: 'Chat meeting',
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedRecipientIdentity,
                      dropdownColor: const Color(0xFF242424),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Kirim ke: Everyone'),
                        ),
                        for (final recipient in widget.recipients)
                          DropdownMenuItem<String?>(
                            value: 'gesit-user-${recipient.id}',
                            child: Text('Kirim ke: ${recipient.name}'),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedRecipientIdentity = value);
                        widget.onRecipientChanged(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder<List<_MeetingChatMessage>>(
                    valueListenable: widget.messages,
                    builder: (context, items, _) {
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'Belum ada pesan.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.58),
                                ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final message = items[index];
                          return Align(
                            alignment: message.isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.76,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: message.isMine
                                    ? AppColors.goldDeep
                                    : const Color(0xFF272727),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.isPrivate &&
                                            message.recipientLabel != null
                                        ? '${message.senderName} -> ${message.recipientLabel}'
                                        : message.senderName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message.text,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tulis pesan',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.46),
                          ),
                          fillColor: const Color(0xFF252525),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ControlButton(
                      icon: Icons.send_rounded,
                      active: true,
                      onTap: widget.onSend,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantsSheet extends StatelessWidget {
  const _ParticipantsSheet({required this.meeting, required this.participants});

  final MeetingSummary meeting;
  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    final namesByIdentity = {
      for (final participant in participants) participant.identity: participant,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: _DarkSheet(
          title: 'Participants',
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: meeting.participants.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Color(0xFF2D2D2D)),
              itemBuilder: (context, index) {
                final member = meeting.participants[index];
                final identity = 'gesit-user-${member.id}';
                final liveParticipant = namesByIdentity[identity];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: member.accentColor.withValues(alpha: 0.22),
                    child: Text(
                      _initials(member.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${member.meetingRole.label} • ${liveParticipant == null ? member.state : 'connected'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  trailing: Icon(
                    liveParticipant?.isMicrophoneEnabled() == true
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingMoreSheet extends StatelessWidget {
  const _MeetingMoreSheet({
    required this.meeting,
    required this.controller,
    required this.onPollUpdated,
    required this.onMeetingUpdated,
    this.onEndMeeting,
  });

  final MeetingSummary meeting;
  final MeetingWorkspaceController controller;
  final ValueChanged<MeetingPoll> onPollUpdated;
  final ValueChanged<MeetingSummary> onMeetingUpdated;
  final Future<void> Function()? onEndMeeting;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: _DarkSheet(
          title: 'Meeting tools',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolTile(
                icon: Icons.poll_rounded,
                title: 'Polling',
                subtitle: '${meeting.polls.length} polling',
                onTap: () => _openPollSheet(context),
              ),
              _ToolTile(
                icon: Icons.fiber_manual_record_rounded,
                title: 'Recording',
                subtitle: meeting.settings['record_by_default'] == true
                    ? 'Siap mengikuti konfigurasi server'
                    : 'Off',
                onTap: () {},
              ),
              _ToolTile(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Host controls',
                subtitle: meeting.canModerate ? 'Aktif' : 'View only',
                onTap: meeting.canModerate
                    ? () => _openHostControls(context)
                    : () {},
              ),
              if (onEndMeeting != null)
                _ToolTile(
                  icon: Icons.power_settings_new_rounded,
                  title: 'End for everyone',
                  subtitle: 'Mengakhiri room untuk semua participant',
                  danger: true,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await onEndMeeting!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPollSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PollSheet(
        meeting: meeting,
        controller: controller,
        onPollUpdated: onPollUpdated,
      ),
    );
  }

  void _openHostControls(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HostControlsSheet(
        meetingId: meeting.id,
        controller: controller,
        onMeetingUpdated: onMeetingUpdated,
      ),
    );
  }
}

class _HostControlsSheet extends StatelessWidget {
  const _HostControlsSheet({
    required this.meetingId,
    required this.controller,
    required this.onMeetingUpdated,
  });

  final String meetingId;
  final MeetingWorkspaceController controller;
  final ValueChanged<MeetingSummary> onMeetingUpdated;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: _DarkSheet(
          title: 'Host controls',
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final meeting = controller.meetingById(meetingId);
              final participants =
                  meeting?.participants ?? const <MeetingMember>[];
              final waiting = participants
                  .where((item) => item.state == 'waiting')
                  .toList(growable: false);
              final activeMembers = participants
                  .where((item) => !item.isCurrentUser)
                  .toList(growable: false);

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.68,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'Waiting room',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    if (waiting.isEmpty)
                      Text(
                        'Tidak ada peserta menunggu.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.56),
                        ),
                      )
                    else
                      for (final member in waiting)
                        _HostParticipantTile(
                          member: member,
                          primaryLabel: 'Admit',
                          onPrimary: () => _runAction(
                            controller.admitParticipant(
                              meetingId: meetingId,
                              participantId: member.participantId,
                            ),
                          ),
                          secondaryLabel: 'Reject',
                          onSecondary: () => _runAction(
                            controller.rejectParticipant(
                              meetingId: meetingId,
                              participantId: member.participantId,
                            ),
                          ),
                        ),
                    const Divider(color: Color(0xFF303030), height: 28),
                    Text(
                      'Participants',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    for (final member in activeMembers)
                      _HostParticipantTile(
                        member: member,
                        primaryLabel: member.meetingRole == MeetingRole.cohost
                            ? 'Demote'
                            : 'Make co-host',
                        onPrimary: () => _runAction(
                          member.meetingRole == MeetingRole.cohost
                              ? controller.demoteParticipant(
                                  meetingId: meetingId,
                                  participantId: member.participantId,
                                )
                              : controller.promoteParticipant(
                                  meetingId: meetingId,
                                  participantId: member.participantId,
                                ),
                        ),
                        secondaryLabel: 'Remove',
                        onSecondary: member.state == 'removed'
                            ? null
                            : () => _runAction(
                                controller.removeParticipant(
                                  meetingId: meetingId,
                                  participantId: member.participantId,
                                ),
                              ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(Future<MeetingSummary?> future) async {
    final meeting = await future;
    if (meeting != null) {
      onMeetingUpdated(meeting);
    }
  }
}

class _HostParticipantTile extends StatelessWidget {
  const _HostParticipantTile({
    required this.member,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final MeetingMember member;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${member.meetingRole.label} • ${member.state}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PollSheet extends StatefulWidget {
  const _PollSheet({
    required this.meeting,
    required this.controller,
    required this.onPollUpdated,
  });

  final MeetingSummary meeting;
  final MeetingWorkspaceController controller;
  final ValueChanged<MeetingPoll> onPollUpdated;

  @override
  State<_PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<_PollSheet> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _optionAController = TextEditingController(
    text: 'Setuju',
  );
  final TextEditingController _optionBController = TextEditingController(
    text: 'Tidak setuju',
  );

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + bottomInset),
        child: _DarkSheet(
          title: 'Polling',
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final meeting =
                  widget.controller.meetingById(widget.meeting.id) ??
                  widget.meeting;
              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: Column(
                  children: [
                    if (meeting.canModerate) ...[
                      TextField(
                        controller: _questionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Pertanyaan',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _optionAController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Opsi 1'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _optionBController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Opsi 2'),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _createPoll,
                          icon: const Icon(Icons.add_chart_rounded),
                          label: const Text('Buat polling'),
                        ),
                      ),
                      const Divider(color: Color(0xFF303030), height: 24),
                    ],
                    Expanded(
                      child: meeting.polls.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada polling.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.58),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: meeting.polls.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final poll = meeting.polls[index];
                                return _PollCard(
                                  poll: poll,
                                  onVote: (optionIndex) async {
                                    final updated = await widget.controller
                                        .votePoll(
                                          meetingId: meeting.id,
                                          pollId: poll.id,
                                          optionIndexes: [optionIndex],
                                        );
                                    if (updated != null) {
                                      widget.onPollUpdated(updated);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _createPoll() async {
    final question = _questionController.text.trim();
    final optionA = _optionAController.text.trim();
    final optionB = _optionBController.text.trim();
    if (question.isEmpty || optionA.isEmpty || optionB.isEmpty) {
      return;
    }

    final poll = await widget.controller.createPoll(
      meetingId: widget.meeting.id,
      question: question,
      options: [optionA, optionB],
    );
    if (poll != null) {
      widget.onPollUpdated(poll);
      _questionController.clear();
    }
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.onVote});

  final MeetingPoll poll;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.results.fold<int>(
      0,
      (sum, item) => sum + item.votes,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < poll.options.length; index++) ...[
            _PollOptionRow(
              label: poll.options[index],
              selected: poll.myVotes.contains(index),
              percent: _percentFor(poll, index, totalVotes),
              onTap: poll.isOpen ? () => onVote(index) : null,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  double _percentFor(MeetingPoll poll, int optionIndex, int totalVotes) {
    if (totalVotes == 0) {
      return 0;
    }
    final votes = poll.results
        .where((item) => item.optionIndex == optionIndex)
        .fold<int>(0, (sum, item) => sum + item.votes);
    return votes / totalVotes;
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.label,
    required this.selected,
    required this.percent,
    this.onTap,
  });

  final String label;
  final bool selected;
  final double percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.goldDeep.withValues(alpha: 0.28)
          : const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: percent.clamp(0, 1),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.goldDeep.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${(percent * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.red : AppColors.goldDeep;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.18),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
      onTap: onTap,
    );
  }
}

class _DarkSheet extends StatelessWidget {
  const _DarkSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF303030)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: SizedBox(
              width: 44,
              child: Divider(thickness: 4, color: Color(0xFF414141)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RoomNotice extends StatelessWidget {
  const _RoomNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: AppColors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingChatMessage {
  const _MeetingChatMessage({
    required this.senderName,
    required this.text,
    required this.isMine,
    required this.sentAt,
    this.recipientLabel,
    this.isPrivate = false,
  });

  final String senderName;
  final String text;
  final bool isMine;
  final DateTime sentAt;
  final String? recipientLabel;
  final bool isPrivate;
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0]).join().toUpperCase();
  return initials.isEmpty ? 'GM' : initials;
}
