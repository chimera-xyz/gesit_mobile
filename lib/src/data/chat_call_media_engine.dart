import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/call_runtime_config.dart';
import '../models/app_models.dart';

typedef ChatCallSignalSender =
    Future<void> Function(String type, {Map<String, dynamic> payload});

class ChatCallMediaState {
  const ChatCallMediaState({
    this.isPreparingLocalMedia = false,
    this.isNegotiating = false,
    this.hasLocalMedia = false,
    this.hasRemoteMedia = false,
    this.hasRemoteVideo = false,
    this.hasLocalVideo = false,
    this.isFrontCamera = true,
    this.speakerEnabled = true,
    this.micEnabled = true,
    this.cameraEnabled = false,
    this.connectionState,
    this.iceConnectionState,
    this.errorMessage,
  });

  static const ChatCallMediaState idle = ChatCallMediaState();

  final bool isPreparingLocalMedia;
  final bool isNegotiating;
  final bool hasLocalMedia;
  final bool hasRemoteMedia;
  final bool hasRemoteVideo;
  final bool hasLocalVideo;
  final bool isFrontCamera;
  final bool speakerEnabled;
  final bool micEnabled;
  final bool cameraEnabled;
  final RTCPeerConnectionState? connectionState;
  final RTCIceConnectionState? iceConnectionState;
  final String? errorMessage;

  bool get isConnected =>
      connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
      iceConnectionState ==
          RTCIceConnectionState.RTCIceConnectionStateConnected ||
      iceConnectionState ==
          RTCIceConnectionState.RTCIceConnectionStateCompleted;

  bool get isConnecting =>
      isPreparingLocalMedia ||
      isNegotiating ||
      connectionState == RTCPeerConnectionState.RTCPeerConnectionStateNew ||
      connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnecting ||
      iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateNew ||
      iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateChecking;

  ChatCallMediaState copyWith({
    bool? isPreparingLocalMedia,
    bool? isNegotiating,
    bool? hasLocalMedia,
    bool? hasRemoteMedia,
    bool? hasRemoteVideo,
    bool? hasLocalVideo,
    bool? isFrontCamera,
    bool? speakerEnabled,
    bool? micEnabled,
    bool? cameraEnabled,
    RTCPeerConnectionState? connectionState,
    RTCIceConnectionState? iceConnectionState,
    Object? errorMessage = _unset,
  }) {
    return ChatCallMediaState(
      isPreparingLocalMedia:
          isPreparingLocalMedia ?? this.isPreparingLocalMedia,
      isNegotiating: isNegotiating ?? this.isNegotiating,
      hasLocalMedia: hasLocalMedia ?? this.hasLocalMedia,
      hasRemoteMedia: hasRemoteMedia ?? this.hasRemoteMedia,
      hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
      hasLocalVideo: hasLocalVideo ?? this.hasLocalVideo,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      micEnabled: micEnabled ?? this.micEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      connectionState: connectionState ?? this.connectionState,
      iceConnectionState: iceConnectionState ?? this.iceConnectionState,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

abstract class ChatCallMediaEngine extends ChangeNotifier {
  ChatCallMediaState get state;

  RTCVideoRenderer? get localRenderer;

  RTCVideoRenderer? get remoteRenderer;

  Future<void> syncSession(
    ChatCallSession? session, {
    required bool isRemote,
    required String currentUserId,
    required ChatCallSignalSender sendSignal,
  });

  Future<void> handleSignal(
    ChatCallSignalEvent signal, {
    required String currentUserId,
  });

  Future<void> setMicEnabled(bool enabled);

  Future<void> setSpeakerEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<void> switchCamera();

  Future<void> close();
}

class NoopChatCallMediaEngine extends ChatCallMediaEngine {
  @override
  ChatCallMediaState get state => ChatCallMediaState.idle;

  @override
  RTCVideoRenderer? get localRenderer => null;

  @override
  RTCVideoRenderer? get remoteRenderer => null;

  @override
  Future<void> close() async {}

  @override
  Future<void> handleSignal(
    ChatCallSignalEvent signal, {
    required String currentUserId,
  }) async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicEnabled(bool enabled) async {}

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}

  @override
  Future<void> switchCamera() async {}

  @override
  Future<void> syncSession(
    ChatCallSession? session, {
    required bool isRemote,
    required String currentUserId,
    required ChatCallSignalSender sendSignal,
  }) async {}
}

class WebRtcChatCallMediaEngine extends ChatCallMediaEngine {
  ChatCallMediaState _state = ChatCallMediaState.idle;
  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  Future<void> _operationQueue = Future<void>.value();
  final Map<String, List<ChatCallSignalEvent>> _bufferedSignalsByCallId = {};
  final Set<String> _processedSignalFingerprints = <String>{};
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];

  String? _callId;
  ChatCallSignalSender? _sendSignal;
  String _currentUserId = '';
  bool _isIncoming = false;
  bool _offerSent = false;
  bool _disposed = false;
  bool _remoteDescriptionApplied = false;
  bool _isFrontCamera = true;

  @override
  ChatCallMediaState get state => _state;

  @override
  RTCVideoRenderer? get localRenderer => _localRenderer;

  @override
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  @override
  Future<void> syncSession(
    ChatCallSession? session, {
    required bool isRemote,
    required String currentUserId,
    required ChatCallSignalSender sendSignal,
  }) {
    return _enqueue(() async {
      _currentUserId = currentUserId;
      _sendSignal = sendSignal;

      if (session == null ||
          !isRemote ||
          session.status == ChatCallStatus.ended ||
          session.status == ChatCallStatus.declined ||
          session.status == ChatCallStatus.missed) {
        await _closeCall();
        _updateState(ChatCallMediaState.idle);
        return;
      }

      if (session.isIncoming && session.status == ChatCallStatus.ringing) {
        if (_callId != null && _callId != session.id) {
          await _closeCall();
        }
        _callId = session.id;
        _isIncoming = true;
        _updateState(
          _state.copyWith(
            speakerEnabled: session.speakerEnabled,
            micEnabled: session.micEnabled,
            cameraEnabled: session.cameraEnabled,
            errorMessage: null,
          ),
        );
        return;
      }

      final shouldStart = _callId != session.id || _peerConnection == null;
      if (shouldStart) {
        await _startCall(session);
      } else {
        _isIncoming = session.isIncoming;
        await _applyLocalTrackState(session);
        await _applySpeakerRoute(session.speakerEnabled);
        _updateState(
          _state.copyWith(
            speakerEnabled: session.speakerEnabled,
            micEnabled: session.micEnabled,
            cameraEnabled: session.cameraEnabled,
            errorMessage: null,
          ),
        );
      }

      await _processMetadataSignals(session.metadata);
      await _drainBufferedSignals(session.id);

      if (!session.isIncoming && !_offerSent) {
        await _createAndSendOffer();
      }
    });
  }

  @override
  Future<void> handleSignal(
    ChatCallSignalEvent signal, {
    required String currentUserId,
  }) {
    return _enqueue(() async {
      _currentUserId = currentUserId;
      final fingerprint = _signalFingerprint(
        signal.signalType,
        signal.fromUserId,
        signal.payload,
      );
      if (_processedSignalFingerprints.contains(fingerprint)) {
        return;
      }

      if (_callId == null ||
          signal.callId != _callId ||
          _peerConnection == null ||
          _callId == null) {
        _bufferSignal(signal);
        return;
      }

      await _handleSignalPayload(
        signal.signalType,
        signal.fromUserId,
        signal.payload,
      );
    });
  }

  @override
  Future<void> setMicEnabled(bool enabled) {
    return _enqueue(() async {
      final audioTracks = _localStream?.getAudioTracks() ?? const [];
      for (final track in audioTracks) {
        track.enabled = enabled;
      }
      _updateState(_state.copyWith(micEnabled: enabled, errorMessage: null));
    });
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) {
    return _enqueue(() async {
      await _applySpeakerRoute(enabled);
      _updateState(
        _state.copyWith(speakerEnabled: enabled, errorMessage: null),
      );
    });
  }

  @override
  Future<void> setCameraEnabled(bool enabled) {
    return _enqueue(() async {
      final videoTracks = _localStream?.getVideoTracks() ?? const [];
      for (final track in videoTracks) {
        track.enabled = enabled;
      }
      _updateState(
        _state.copyWith(
          cameraEnabled: enabled,
          hasLocalVideo: videoTracks.isNotEmpty && enabled,
          errorMessage: null,
        ),
      );
    });
  }

  @override
  Future<void> switchCamera() {
    return _enqueue(() async {
      final videoTracks = _localStream?.getVideoTracks() ?? const [];
      if (videoTracks.isEmpty) {
        return;
      }

      await Helper.switchCamera(videoTracks.first);
      _isFrontCamera = !_isFrontCamera;
      _updateState(_state.copyWith(isFrontCamera: _isFrontCamera));
    });
  }

  @override
  Future<void> close() => _enqueue(_closeCall);

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }

  Future<void> _startCall(ChatCallSession session) async {
    await _closeCall();
    _callId = session.id;
    _isIncoming = session.isIncoming;
    _offerSent = false;
    _remoteDescriptionApplied = false;
    _processedSignalFingerprints.clear();
    _pendingRemoteCandidates.clear();

    _updateState(
      ChatCallMediaState.idle.copyWith(
        isPreparingLocalMedia: true,
        speakerEnabled: session.speakerEnabled,
        micEnabled: session.micEnabled,
        cameraEnabled: session.cameraEnabled,
        errorMessage: null,
      ),
    );

    try {
      await _ensureRenderers();
      await _configureAudio();
      await _openLocalMedia(session);
      await _createPeerConnection();
      await _addLocalTracks();
      await _applyLocalTrackState(session);
      await _applySpeakerRoute(session.speakerEnabled);
      _updateState(
        _state.copyWith(
          isPreparingLocalMedia: false,
          hasLocalMedia: true,
          hasLocalVideo:
              (_localStream?.getVideoTracks().isNotEmpty ?? false) &&
              session.cameraEnabled,
          speakerEnabled: session.speakerEnabled,
          micEnabled: session.micEnabled,
          cameraEnabled: session.cameraEnabled,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _updateState(
        _state.copyWith(
          isPreparingLocalMedia: false,
          errorMessage: _friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _ensureRenderers() async {
    if (_localRenderer == null) {
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      _localRenderer!.muted = true;
    }
    if (_remoteRenderer == null) {
      _remoteRenderer = RTCVideoRenderer();
      await _remoteRenderer!.initialize();
      _remoteRenderer!.muted = false;
    }
  }

  Future<void> _configureAudio() async {
    if (WebRTC.platformIsAndroid) {
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.communication,
      );
    }
  }

  Future<void> _openLocalMedia(ChatCallSession session) async {
    final wantsVideo = session.type == ChatCallType.video;
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': wantsVideo
          ? <String, dynamic>{
              'facingMode': 'user',
              'width': 1280,
              'height': 720,
              'frameRate': 30,
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer?.srcObject = _localStream;
    _isFrontCamera = true;
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(<String, dynamic>{
      'iceServers': CallRuntimeConfig.iceServers,
      'sdpSemantics': 'unified-plan',
    });

    _peerConnection!.onIceCandidate = (candidate) {
      final rawCandidate = candidate.candidate;
      if (rawCandidate == null || rawCandidate.isEmpty) {
        return;
      }
      final sender = _sendSignal;
      if (sender == null) {
        return;
      }

      unawaited(
        sender(
          'ice_candidate',
          payload: Map<String, dynamic>.from(candidate.toMap() as Map),
        ),
      );
    };

    _peerConnection!.onConnectionState = (state) {
      _updateState(_state.copyWith(connectionState: state, errorMessage: null));
    };

    _peerConnection!.onIceConnectionState = (state) {
      _updateState(
        _state.copyWith(iceConnectionState: state, errorMessage: null),
      );
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isEmpty) {
        return;
      }
      _remoteStream = event.streams.first;
      _remoteRenderer?.srcObject = _remoteStream;
      _updateRemoteMediaState();
    };

    _peerConnection!.onAddStream = (stream) {
      _remoteStream = stream;
      _remoteRenderer?.srcObject = stream;
      _updateRemoteMediaState();
    };

    _peerConnection!.onRemoveStream = (_) {
      _remoteStream = null;
      _remoteRenderer?.srcObject = null;
      _updateState(
        _state.copyWith(hasRemoteMedia: false, hasRemoteVideo: false),
      );
    };
  }

  Future<void> _addLocalTracks() async {
    final peerConnection = _peerConnection;
    final localStream = _localStream;
    if (peerConnection == null || localStream == null) {
      return;
    }

    for (final track in localStream.getTracks()) {
      await peerConnection.addTrack(track, localStream);
    }
  }

  Future<void> _applyLocalTrackState(ChatCallSession session) async {
    final audioTracks = _localStream?.getAudioTracks() ?? const [];
    for (final track in audioTracks) {
      track.enabled = session.micEnabled;
    }

    final videoTracks = _localStream?.getVideoTracks() ?? const [];
    for (final track in videoTracks) {
      track.enabled = session.cameraEnabled;
    }

    _updateState(
      _state.copyWith(
        micEnabled: session.micEnabled,
        cameraEnabled: session.cameraEnabled,
        hasLocalVideo: videoTracks.isNotEmpty && session.cameraEnabled,
      ),
    );
  }

  Future<void> _applySpeakerRoute(bool enabled) async {
    if (!WebRTC.platformIsAndroid && !WebRTC.platformIsIOS) {
      _updateState(_state.copyWith(speakerEnabled: enabled));
      return;
    }

    if (enabled) {
      await Helper.setSpeakerphoneOnButPreferBluetooth();
    } else {
      await Helper.setSpeakerphoneOn(false);
    }
    _updateState(_state.copyWith(speakerEnabled: enabled));
  }

  Future<void> _createAndSendOffer() async {
    final peerConnection = _peerConnection;
    final sender = _sendSignal;
    if (peerConnection == null || sender == null || _offerSent) {
      return;
    }

    _updateState(_state.copyWith(isNegotiating: true, errorMessage: null));
    try {
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      final localDescription = await peerConnection.getLocalDescription();
      final payload = _descriptionPayload(localDescription ?? offer);
      await sender('offer', payload: payload);
      _offerSent = true;
    } finally {
      _updateState(_state.copyWith(isNegotiating: false));
    }
  }

  Future<void> _createAndSendAnswer() async {
    final peerConnection = _peerConnection;
    final sender = _sendSignal;
    if (peerConnection == null || sender == null) {
      return;
    }

    _updateState(_state.copyWith(isNegotiating: true, errorMessage: null));
    try {
      final answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      final localDescription = await peerConnection.getLocalDescription();
      await sender(
        'answer',
        payload: _descriptionPayload(localDescription ?? answer),
      );
    } finally {
      _updateState(_state.copyWith(isNegotiating: false));
    }
  }

  Future<void> _processMetadataSignals(Map<String, dynamic> metadata) async {
    final descriptions = metadata['descriptions'];
    if (descriptions is Map) {
      final offer = descriptions['offer'];
      if (offer is Map) {
        final payload = (offer['payload'] as Map?)?.cast<String, dynamic>();
        await _handleSignalPayload(
          'offer',
          '${offer['from_user_id'] ?? ''}',
          payload ?? const <String, dynamic>{},
        );
      }
      final answer = descriptions['answer'];
      if (answer is Map) {
        final payload = (answer['payload'] as Map?)?.cast<String, dynamic>();
        await _handleSignalPayload(
          'answer',
          '${answer['from_user_id'] ?? ''}',
          payload ?? const <String, dynamic>{},
        );
      }
    }

    final candidates = metadata['candidates'];
    if (candidates is List) {
      for (final item in candidates.whereType<Map>()) {
        final payload = (item['payload'] as Map?)?.cast<String, dynamic>();
        await _handleSignalPayload(
          'ice_candidate',
          '${item['from_user_id'] ?? ''}',
          payload ?? const <String, dynamic>{},
        );
      }
    }

    final hangup = metadata['hangup'];
    if (hangup is Map) {
      final payload = (hangup['payload'] as Map?)?.cast<String, dynamic>();
      await _handleSignalPayload(
        'hangup',
        '${hangup['from_user_id'] ?? ''}',
        payload ?? const <String, dynamic>{},
      );
    }
  }

  Future<void> _drainBufferedSignals(String callId) async {
    final bufferedSignals = _bufferedSignalsByCallId.remove(callId);
    if (bufferedSignals == null || bufferedSignals.isEmpty) {
      return;
    }

    for (final signal in bufferedSignals) {
      await _handleSignalPayload(
        signal.signalType,
        signal.fromUserId,
        signal.payload,
      );
    }
  }

  Future<void> _handleSignalPayload(
    String signalType,
    String fromUserId,
    Map<String, dynamic> payload,
  ) async {
    if (fromUserId.isEmpty || fromUserId == _currentUserId) {
      return;
    }

    final fingerprint = _signalFingerprint(signalType, fromUserId, payload);
    if (_processedSignalFingerprints.contains(fingerprint)) {
      return;
    }
    _processedSignalFingerprints.add(fingerprint);

    if (signalType == 'ready') {
      if (!_isIncoming && !_offerSent) {
        await _createAndSendOffer();
      }
      return;
    }

    if (signalType == 'hangup') {
      await _closeCall();
      _updateState(
        _state.copyWith(
          errorMessage: 'Panggilan diakhiri dari perangkat lawan bicara.',
        ),
      );
      return;
    }

    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      return;
    }

    if (signalType == 'offer') {
      final description = _sessionDescriptionFromPayload(payload);
      if (description == null) {
        return;
      }
      await peerConnection.setRemoteDescription(description);
      _remoteDescriptionApplied = true;
      await _flushPendingRemoteCandidates();
      await _createAndSendAnswer();
      return;
    }

    if (signalType == 'answer') {
      final description = _sessionDescriptionFromPayload(payload);
      if (description == null) {
        return;
      }
      await peerConnection.setRemoteDescription(description);
      _remoteDescriptionApplied = true;
      await _flushPendingRemoteCandidates();
      return;
    }

    if (signalType == 'ice_candidate') {
      final candidate = _candidateFromPayload(payload);
      if (candidate == null) {
        return;
      }

      if (!_remoteDescriptionApplied) {
        _pendingRemoteCandidates.add(candidate);
        return;
      }

      await peerConnection.addCandidate(candidate);
    }
  }

  Future<void> _flushPendingRemoteCandidates() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null || !_remoteDescriptionApplied) {
      return;
    }

    for (final candidate in List<RTCIceCandidate>.from(
      _pendingRemoteCandidates,
    )) {
      await peerConnection.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  RTCSessionDescription? _sessionDescriptionFromPayload(
    Map<String, dynamic> payload,
  ) {
    final sdp = '${payload['sdp'] ?? ''}'.trim();
    final type = '${payload['type'] ?? ''}'.trim();
    if (sdp.isEmpty || type.isEmpty) {
      return null;
    }
    return RTCSessionDescription(sdp, type);
  }

  RTCIceCandidate? _candidateFromPayload(Map<String, dynamic> payload) {
    final candidateValue = '${payload['candidate'] ?? ''}'.trim();
    final sdpMidValue = payload['sdpMid'];
    final sdpMLineIndexValue = payload['sdpMLineIndex'];
    final sdpMid = sdpMidValue == null ? null : '$sdpMidValue';
    final sdpMLineIndex = sdpMLineIndexValue is int
        ? sdpMLineIndexValue
        : int.tryParse('$sdpMLineIndexValue');
    if (candidateValue.isEmpty || sdpMLineIndex == null) {
      return null;
    }

    return RTCIceCandidate(candidateValue, sdpMid, sdpMLineIndex);
  }

  Map<String, dynamic> _descriptionPayload(RTCSessionDescription description) {
    return <String, dynamic>{'sdp': description.sdp, 'type': description.type};
  }

  void _bufferSignal(ChatCallSignalEvent signal) {
    final bucket = _bufferedSignalsByCallId.putIfAbsent(
      signal.callId,
      () => <ChatCallSignalEvent>[],
    );
    bucket.add(signal);
  }

  void _updateRemoteMediaState() {
    final remoteStream = _remoteStream;
    final hasRemoteMedia =
        remoteStream != null && remoteStream.getTracks().isNotEmpty;
    final hasRemoteVideo =
        remoteStream != null && remoteStream.getVideoTracks().isNotEmpty;
    _updateState(
      _state.copyWith(
        hasRemoteMedia: hasRemoteMedia,
        hasRemoteVideo: hasRemoteVideo,
        errorMessage: null,
      ),
    );
  }

  String _signalFingerprint(
    String signalType,
    String fromUserId,
    Map<String, dynamic> payload,
  ) {
    if (signalType == 'ice_candidate') {
      return '$signalType|$fromUserId|${payload['candidate'] ?? ''}|${payload['sdpMid'] ?? ''}|${payload['sdpMLineIndex'] ?? ''}';
    }
    if (signalType == 'offer' || signalType == 'answer') {
      return '$signalType|$fromUserId|${payload['sdp'] ?? ''}';
    }
    if (signalType == 'hangup') {
      return '$signalType|$fromUserId|${payload['reason'] ?? ''}';
    }
    return '$signalType|$fromUserId';
  }

  Future<void> _closeCall() async {
    _offerSent = false;
    _remoteDescriptionApplied = false;
    _pendingRemoteCandidates.clear();
    _processedSignalFingerprints.clear();

    final peerConnection = _peerConnection;
    _peerConnection = null;
    if (peerConnection != null) {
      try {
        await peerConnection.close();
      } catch (_) {
        // Ignore close failures during teardown.
      }
      try {
        await peerConnection.dispose();
      } catch (_) {
        // Ignore dispose failures during teardown.
      }
    }

    final localStream = _localStream;
    _localStream = null;
    if (localStream != null) {
      for (final track in localStream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {
          // Ignore track stop failures during teardown.
        }
      }
    }

    final remoteStream = _remoteStream;
    _remoteStream = null;
    if (remoteStream != null) {
      for (final track in remoteStream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {
          // Ignore track stop failures during teardown.
        }
      }
    }

    _localRenderer?.srcObject = null;
    _remoteRenderer?.srcObject = null;
    _callId = null;
    _isIncoming = false;

    if (WebRTC.platformIsAndroid) {
      try {
        await Helper.clearAndroidCommunicationDevice();
      } catch (_) {
        // Audio routing cleanup is best effort.
      }
    }
  }

  void _updateState(ChatCallMediaState nextState) {
    if (_disposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _operationQueue = _operationQueue.catchError((_) {}).then((_) async {
      try {
        await action();
      } catch (error) {
        _updateState(
          _state.copyWith(
            isPreparingLocalMedia: false,
            isNegotiating: false,
            errorMessage: _friendlyErrorMessage(error),
          ),
        );
      }
    });
    return _operationQueue;
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('NotAllowedError')) {
      return 'Izin kamera atau mikrofon ditolak.';
    }
    if (message.contains('NotFoundError')) {
      return 'Perangkat kamera atau mikrofon tidak ditemukan.';
    }
    if (message.contains('NotReadableError')) {
      return 'Kamera atau mikrofon sedang dipakai aplikasi lain.';
    }
    return 'Media call belum bisa diaktifkan.';
  }
}
