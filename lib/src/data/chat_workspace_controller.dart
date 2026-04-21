import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../config/app_runtime_config.dart';
import '../config/call_runtime_config.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'app_session_controller.dart';
import 'chat_call_media_engine.dart';
import 'chat_store.dart';
import 'gesit_api_client.dart';
import 'notification_center_controller.dart';

class ChatWorkspaceController extends ChangeNotifier {
  ChatWorkspaceController({
    required this.sessionController,
    this.notificationController,
    ChatStore? store,
    GesitApiClient? apiClient,
    ChatCallMediaEngine? callMediaEngine,
  }) : _store = store ?? ChatStore(),
       _apiClient = apiClient ?? GesitApiClient(),
       _callMediaEngine = callMediaEngine ?? NoopChatCallMediaEngine() {
    _callMediaEngine.addListener(_handleCallMediaEngineChanged);
  }

  final AppSessionController sessionController;
  final NotificationCenterController? notificationController;
  final ChatStore _store;
  final GesitApiClient _apiClient;
  final ChatCallMediaEngine _callMediaEngine;

  final List<ConversationPreview> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, List<GroupMember>> _membersByConversation = {};
  final Map<String, List<ConversationAsset>> _assetsByConversation = {};
  final List<GroupMember> _directoryMembers = [];
  final List<Timer> _timers = [];
  final StreamController<ChatCallSignalEvent> _callSignalController =
      StreamController<ChatCallSignalEvent>.broadcast();
  final Set<String> _cancelledPreparedOutgoingCallIds = <String>{};

  Future<void>? _loadFuture;
  String? _activeConversationId;
  ChatCallSession? _activeCall;
  bool _activeCallIsRemote = false;
  bool _remoteChatAvailable = true;
  bool _syncLoopRunning = false;
  bool _chatRealtimeStreamUnavailable = false;
  bool _disposed = false;
  int _syncFailureCount = 0;
  int _lastEventId = 0;
  Timer? _callConnectTimer;
  Timer? _callTickTimer;
  Timer? _syncLoopDelayTimer;
  Completer<void>? _syncLoopDelayCompleter;
  bool _notifyScheduled = false;

  bool get isLoaded => _loadFuture != null;

  List<ConversationPreview> get conversations {
    final items = List<ConversationPreview>.from(_conversations);
    items.sort((left, right) {
      if (left.isPinned != right.isPinned) {
        return left.isPinned ? -1 : 1;
      }

      final leftUpdatedAt =
          left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightUpdatedAt =
          right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = rightUpdatedAt.compareTo(leftUpdatedAt);
      if (dateCompare != 0) {
        return dateCompare;
      }

      return left.title.compareTo(right.title);
    });
    return List.unmodifiable(items);
  }

  List<ConversationPreview> get groupConversations =>
      conversations.where((conversation) => conversation.isGroup).toList();

  List<GroupMember> get directoryMembers {
    if (_directoryMembers.isNotEmpty) {
      return List.unmodifiable(_directoryMembers);
    }

    final seen = <String>{};
    final members = <GroupMember>[];

    for (final entry in _membersByConversation.values) {
      for (final member in entry) {
        final key = member.id ?? member.name.toLowerCase();
        if (member.isCurrentUser || seen.contains(key)) {
          continue;
        }
        seen.add(key);
        members.add(member);
      }
    }

    return List.unmodifiable(_sortMembers(members));
  }

  int get unreadConversationCount =>
      _conversations.fold(0, (total, item) => total + item.unreadCount);

  ChatCallSession? get activeCall => _activeCall;

  Stream<ChatCallSignalEvent> get callSignalStream =>
      _callSignalController.stream;

  ChatCallMediaState get callMediaState => _callMediaEngine.state;

  ChatCallMediaEngine get callMediaEngine => _callMediaEngine;

  bool get hasIncomingCall =>
      _activeCall?.isIncoming == true &&
      _activeCall?.status == ChatCallStatus.ringing;

  Future<void> ensureLoaded() {
    return _loadFuture ??= _bootstrapWorkspace();
  }

  void startDemoFeed() {}

  ConversationPreview? conversationById(String id) {
    for (final conversation in _conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  List<ChatMessage> messagesFor(String conversationId) {
    return List.unmodifiable(
      _messagesByConversation[conversationId] ?? const [],
    );
  }

  List<GroupMember> membersFor(String conversationId) {
    return List.unmodifiable(
      _membersByConversation[conversationId] ?? const [],
    );
  }

  List<ConversationAsset> assetsFor(String conversationId) {
    final assets = List<ConversationAsset>.from(
      _assetsByConversation[conversationId] ?? const [],
    );
    assets.sort((left, right) => right.uploadedAt.compareTo(left.uploadedAt));
    return List.unmodifiable(assets);
  }

  void openConversation(String conversationId) {
    _activeConversationId = conversationId;
    _updateConversation(
      conversationId,
      (conversation) => conversation.copyWith(unreadCount: 0, isTyping: false),
      shouldNotify: false,
    );
    _persistSnapshot();
    _notifyListenersSafely();
    unawaited(_markConversationReadRemote(conversationId));
  }

  void closeConversation(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
  }

  Future<ConversationPreview> ensureDirectConversation(
    GroupMember member,
  ) async {
    final existing = _findDirectConversationForMember(member);
    if (existing != null) {
      return existing;
    }

    final session = sessionController.session;
    if (session != null &&
        _remoteChatAvailable &&
        member.id != null &&
        member.id!.trim().isNotEmpty) {
      try {
        final payload = await _apiClient.ensureDirectConversation(
          baseUrl: session.apiBaseUrl,
          cookies: session.cookies,
          participantUserId: member.id!,
        );
        await sessionController.syncCookies(payload.cookies);
        final snapshot = _workspaceFromPayload(payload.data);
        if (snapshot != null) {
          _applySnapshot(snapshot);
        }

        final remoteConversation = _findDirectConversationForMember(member);
        if (remoteConversation != null) {
          return remoteConversation;
        }
      } on TimeoutException {
        _remoteChatAvailable = false;
      } on GesitApiException catch (error) {
        if (error.statusCode == 401) {
          await _handleUnauthorized();
        } else if (error.statusCode == 404 || error.statusCode == 501) {
          _remoteChatAvailable = false;
        }
      } catch (_) {
        _remoteChatAvailable = false;
      }
    }

    throw const GesitApiException(
      'Kontak chat belum bisa dimuat dari server. Pastikan sesi login masih aktif.',
    );
  }

  Future<void> sendTextMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final pendingId = 'pending-text-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final pendingMessage = ChatMessage(
      id: pendingId,
      text: trimmed,
      timeLabel: _formatMessageTime(now),
      delivery: MessageDelivery.sending,
      isMine: true,
      sentAt: now,
    );

    _appendMessage(conversationId, pendingMessage);
    _promoteConversation(
      conversationId,
      preview: trimmed,
      updatedAt: now,
      resetUnread: true,
    );
    _notifyListenersSafely();
    _persistSnapshot();

    final session = sessionController.session;
    if (session == null || !_remoteChatAvailable) {
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
      return;
    }

    try {
      final payload = await _apiClient.sendChatMessage(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId,
        text: trimmed,
        clientToken: pendingId,
      );
      await sessionController.syncCookies(payload.cookies);
      final snapshot = _workspaceFromPayload(payload.data);
      if (snapshot != null) {
        _applySnapshot(snapshot);
        return;
      }
      _updateMessageDelivery(
        conversationId,
        pendingId,
        MessageDelivery.delivered,
      );
    } on TimeoutException {
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      }
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
    } catch (_) {
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
    }
  }

  Future<void> sendAttachment(
    String conversationId, {
    required String fileName,
    required String typeLabel,
    required String sizeLabel,
    String caption = '',
    String kind = 'attachment',
    String? voiceNoteDuration,
    String? attachmentMimeType,
    String? attachmentLocalPath,
    Uint8List? attachmentPreviewBytes,
    ApiMultipartFilePayload? filePayload,
  }) async {
    final isVoiceNote = kind == 'voice_note';
    final pendingId = 'pending-file-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final message = ChatMessage(
      id: pendingId,
      text: caption.trim(),
      timeLabel: _formatMessageTime(now),
      delivery: MessageDelivery.sending,
      isMine: true,
      hasAttachment: true,
      attachmentLabel: fileName,
      attachmentTypeLabel: typeLabel,
      attachmentSizeLabel: sizeLabel,
      attachmentUrl: attachmentLocalPath,
      attachmentMimeType: attachmentMimeType,
      attachmentLocalPath: attachmentLocalPath,
      attachmentPreviewBytes: attachmentPreviewBytes,
      isVoiceNote: isVoiceNote,
      voiceNoteDuration: voiceNoteDuration,
      sentAt: now,
    );

    _appendMessage(conversationId, message);
    if (!isVoiceNote) {
      _storeAsset(
        conversationId,
        ConversationAsset(
          id: 'asset-${now.microsecondsSinceEpoch}',
          label: fileName,
          typeLabel: typeLabel,
          uploadedBy: _currentUserName,
          uploadedAt: now,
          sizeLabel: sizeLabel,
          accentColor:
              conversationById(conversationId)?.accentColor ??
              AppColors.goldDeep,
        ),
      );
    }
    _promoteConversation(
      conversationId,
      preview: isVoiceNote
          ? 'Voice note'
          : _previewLabelForAttachment(
              fileName,
              attachmentMimeType: attachmentMimeType,
              caption: caption,
            ),
      updatedAt: now,
      resetUnread: true,
    );
    _notifyListenersSafely();
    _persistSnapshot();

    final session = sessionController.session;
    if (session == null ||
        !_remoteChatAvailable ||
        filePayload == null ||
        ((filePayload.path == null || filePayload.path!.trim().isEmpty) &&
            (filePayload.bytes == null || filePayload.bytes!.isEmpty))) {
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
      return;
    }

    try {
      final payload = await _apiClient.sendChatAttachment(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId,
        file: filePayload,
        caption: caption,
        clientToken: pendingId,
        kind: kind,
        voiceNoteDuration: voiceNoteDuration,
      );
      await sessionController.syncCookies(payload.cookies);
      final snapshot = _workspaceFromPayload(payload.data);
      if (snapshot != null) {
        _applySnapshot(snapshot);
        return;
      }
      _updateMessageDelivery(
        conversationId,
        pendingId,
        MessageDelivery.delivered,
      );
    } on TimeoutException {
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      }
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
    } catch (_) {
      _updateMessageDelivery(conversationId, pendingId, MessageDelivery.failed);
    }
  }

  Future<void> sendVoiceNote(
    String conversationId, {
    required Duration duration,
    required String fileName,
    required String sizeLabel,
    String? attachmentLocalPath,
    ApiMultipartFilePayload? filePayload,
  }) {
    final formattedDuration = _formatDuration(duration);
    return sendAttachment(
      conversationId,
      fileName: fileName,
      typeLabel: 'Voice note',
      sizeLabel: sizeLabel,
      kind: 'voice_note',
      voiceNoteDuration: formattedDuration,
      attachmentMimeType: 'audio/wav',
      attachmentLocalPath: attachmentLocalPath,
      filePayload: filePayload,
    );
  }

  void togglePinned(String conversationId) {
    _updateConversation(
      conversationId,
      (conversation) => conversation.copyWith(isPinned: !conversation.isPinned),
    );
    _persistSnapshot();
    unawaited(_pushConversationPreferences(conversationId));
  }

  void toggleMuted(String conversationId) {
    _updateConversation(
      conversationId,
      (conversation) => conversation.copyWith(isMuted: !conversation.isMuted),
    );
    _persistSnapshot();
    unawaited(_pushConversationPreferences(conversationId));
  }

  Future<void> sendActiveCallSignal(
    String type, {
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final session = _activeCall;
    final currentSession = sessionController.session;
    if (session == null || currentSession == null || !_activeCallIsRemote) {
      return;
    }

    try {
      final response = await _apiClient.sendChatCallSignal(
        baseUrl: currentSession.apiBaseUrl,
        cookies: currentSession.cookies,
        callId: session.id,
        type: type,
        payload: payload,
      );
      await sessionController.syncCookies(response.cookies);
      final snapshot = _workspaceFromPayload(response.data);
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } on TimeoutException {
      // Let sync reconcile temporary signaling delays.
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      }
    } catch (_) {
      // Ignore best-effort signaling failures from the UI layer.
    }
  }

  ChatCallSession? prepareOutgoingCall(
    String conversationId, {
    required ChatCallType type,
  }) {
    if (_activeCall != null) {
      return null;
    }

    final conversation = conversationById(conversationId);
    if (conversation == null) {
      return null;
    }

    final session = sessionController.session;
    if (session == null) {
      throw const GesitApiException(
        'Panggilan belum bisa dimulai karena chat server belum terhubung.',
      );
    }

    final now = DateTime.now();
    final preparedCall = ChatCallSession(
      id: 'prepared-call-${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      title: conversation.title,
      subtitle: conversation.subtitle,
      isGroup: conversation.isGroup,
      type: type,
      status: ChatCallStatus.ringing,
      isIncoming: false,
      createdAt: now,
      participants: _buildCallParticipants(
        conversationId,
        type: type,
        connected: false,
      ),
      cameraEnabled: type == ChatCallType.video,
      metadata: const <String, dynamic>{'is_staged_outgoing': true},
    );

    _setActiveCall(preparedCall, isRemote: false);
    _notifyListenersSafely();
    return preparedCall;
  }

  Future<ChatCallSession?> connectPreparedOutgoingCall(
    String provisionalCallId, {
    required String conversationId,
    required ChatCallType type,
  }) async {
    final preparedCall = _activeCall;
    if (preparedCall == null ||
        preparedCall.id != provisionalCallId ||
        _activeCallIsRemote) {
      return _activeCall;
    }

    final conversation = conversationById(conversationId);
    if (conversation == null) {
      _discardPreparedOutgoingCall(provisionalCallId);
      return null;
    }

    final session = sessionController.session;
    if (session == null) {
      _discardPreparedOutgoingCall(provisionalCallId);
      throw const GesitApiException(
        'Panggilan belum bisa dimulai karena chat server belum terhubung.',
      );
    }

    if (!_remoteChatAvailable) {
      await _refreshFromServer();
      if (_consumeCancelledPreparedOutgoingCall(provisionalCallId)) {
        return null;
      }
      if (_activeCall != null && _activeCall?.id != provisionalCallId) {
        return _activeCall?.conversationId == conversationId
            ? _activeCall
            : null;
      }
      if (!_remoteChatAvailable) {
        _discardPreparedOutgoingCall(provisionalCallId);
        throw const GesitApiException(
          'Panggilan belum bisa dimulai karena chat server belum terhubung.',
        );
      }
    }

    try {
      final payload = await _apiClient.startChatCall(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId,
        type: type,
      );
      await sessionController.syncCookies(payload.cookies);
      final snapshot = _workspaceFromPayload(payload.data);

      if (_consumeCancelledPreparedOutgoingCall(provisionalCallId)) {
        final remoteCall = snapshot?.activeCall;
        if (remoteCall != null) {
          await _endRemoteCallSilently(
            baseUrl: session.apiBaseUrl,
            cookies: payload.cookies,
            callId: remoteCall.id,
          );
          await _refreshFromServer();
        }
        return null;
      }

      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
      unawaited(_broadcastCurrentCallMediaState(signalType: 'ready'));
      return _activeCall;
    } on TimeoutException {
      final recoveredCall = await _recoverOutgoingCallStart(conversationId);
      if (_consumeCancelledPreparedOutgoingCall(provisionalCallId)) {
        if (recoveredCall != null) {
          await _endRemoteCallSilently(
            baseUrl: session.apiBaseUrl,
            cookies:
                sessionController.session?.cookies ?? const <String, String>{},
            callId: recoveredCall.id,
          );
          await _refreshFromServer();
        }
        return null;
      }
      if (recoveredCall != null || _activeCall != null) {
        return recoveredCall;
      }
      _discardPreparedOutgoingCall(provisionalCallId);
      throw const GesitApiException(
        'Panggilan belum bisa dimulai. Server terlalu lama merespons.',
      );
    } on GesitApiException catch (error) {
      if (error.statusCode == 409) {
        final recoveredCall = await _recoverOutgoingCallStart(conversationId);
        if (_consumeCancelledPreparedOutgoingCall(provisionalCallId)) {
          if (recoveredCall != null) {
            await _endRemoteCallSilently(
              baseUrl: session.apiBaseUrl,
              cookies:
                  sessionController.session?.cookies ??
                  const <String, String>{},
              callId: recoveredCall.id,
            );
            await _refreshFromServer();
          }
          return null;
        }
        if (recoveredCall != null || _activeCall != null) {
          return recoveredCall;
        }
      } else if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      } else {
        final recoveredCall = await _recoverOutgoingCallStart(conversationId);
        if (_consumeCancelledPreparedOutgoingCall(provisionalCallId)) {
          if (recoveredCall != null) {
            await _endRemoteCallSilently(
              baseUrl: session.apiBaseUrl,
              cookies:
                  sessionController.session?.cookies ??
                  const <String, String>{},
              callId: recoveredCall.id,
            );
            await _refreshFromServer();
          }
          return null;
        }
        if (recoveredCall != null || _activeCall != null) {
          return recoveredCall;
        }
      }
      _discardPreparedOutgoingCall(provisionalCallId);
      rethrow;
    } catch (_) {
      _discardPreparedOutgoingCall(provisionalCallId);
      rethrow;
    }
  }

  Future<ChatCallSession?> startOutgoingCall(
    String conversationId, {
    required ChatCallType type,
  }) async {
    if (_activeCall != null) {
      return null;
    }

    final conversation = conversationById(conversationId);
    if (conversation == null) {
      return null;
    }

    final session = sessionController.session;
    if (session == null) {
      throw const GesitApiException(
        'Panggilan belum bisa dimulai karena chat server belum terhubung.',
      );
    }

    if (!_remoteChatAvailable) {
      await _refreshFromServer();
      if (_activeCall != null) {
        return _activeCall?.conversationId == conversationId
            ? _activeCall
            : null;
      }
      if (!_remoteChatAvailable) {
        throw const GesitApiException(
          'Panggilan belum bisa dimulai karena chat server belum terhubung.',
        );
      }
    }

    try {
      final payload = await _apiClient.startChatCall(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId,
        type: type,
      );
      await sessionController.syncCookies(payload.cookies);
      final snapshot = _workspaceFromPayload(payload.data);
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
      unawaited(_broadcastCurrentCallMediaState(signalType: 'ready'));

      return _activeCall;
    } on TimeoutException {
      final recoveredCall = await _recoverOutgoingCallStart(conversationId);
      if (recoveredCall != null || _activeCall != null) {
        return recoveredCall;
      }
      throw const GesitApiException(
        'Panggilan belum bisa dimulai. Server terlalu lama merespons.',
      );
    } on GesitApiException catch (error) {
      if (error.statusCode == 409) {
        final recoveredCall = await _recoverOutgoingCallStart(conversationId);
        if (recoveredCall != null || _activeCall != null) {
          return recoveredCall;
        }
      } else if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      } else {
        final recoveredCall = await _recoverOutgoingCallStart(conversationId);
        if (recoveredCall != null || _activeCall != null) {
          return recoveredCall;
        }
      }
      rethrow;
    }
  }

  ChatCallSession? simulateIncomingCall(
    String conversationId, {
    required ChatCallType type,
    String? initiatorName,
  }) {
    if (_activeCall != null) {
      return null;
    }

    final conversation = conversationById(conversationId);
    if (conversation == null) {
      return null;
    }

    final now = DateTime.now();
    final session = ChatCallSession(
      id: 'call-${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      title: conversation.title,
      subtitle: conversation.subtitle,
      isGroup: conversation.isGroup,
      type: type,
      status: ChatCallStatus.ringing,
      isIncoming: true,
      createdAt: now,
      participants: _buildCallParticipants(
        conversationId,
        type: type,
        connected: true,
      ),
      cameraEnabled: type == ChatCallType.video,
    );

    _setActiveCall(session, isRemote: false);
    _sendTransientNotification(
      title: initiatorName == null
          ? conversation.title
          : '$initiatorName menelepon',
      message:
          '${type.label}${conversation.isGroup ? ' grup' : ''} masuk dari ${conversation.title}.',
      detail:
          'Aktivitas ini berasal dari menu chat dan tidak disimpan di pusat notifikasi.',
      type: AppNotificationType.call,
    );
    _timers.add(
      Timer(const Duration(seconds: 22), () {
        if (_activeCall?.id == session.id &&
            _activeCall?.status == ChatCallStatus.ringing) {
          _finishLocalCall(ChatCallStatus.missed);
        }
      }),
    );
    unawaited(_syncCallMediaEngine());
    _notifyListenersSafely();
    return session;
  }

  Future<void> acceptActiveCall() async {
    final session = _activeCall;
    if (session == null) {
      return;
    }

    if (_activeCallIsRemote) {
      final currentSession = sessionController.session;
      if (currentSession == null) {
        return;
      }

      try {
        final payload = await _apiClient.acceptChatCall(
          baseUrl: currentSession.apiBaseUrl,
          cookies: currentSession.cookies,
          callId: session.id,
        );
        await sessionController.syncCookies(payload.cookies);
        final snapshot = _workspaceFromPayload(payload.data);
        if (snapshot != null) {
          _applySnapshot(snapshot);
        }
        unawaited(_broadcastCurrentCallMediaState(signalType: 'ready'));
        return;
      } on TimeoutException {
        return;
      } on GesitApiException catch (error) {
        if (error.statusCode == 404 || error.statusCode == 501) {
          _remoteChatAvailable = false;
        }
        return;
      } catch (_) {
        return;
      }
    }

    final now = DateTime.now();
    final participants = session.participants
        .map(
          (participant) => participant.copyWith(
            isConnected: true,
            isVideoEnabled: session.type == ChatCallType.video,
          ),
        )
        .toList(growable: false);

    _setActiveCall(
      session.copyWith(
        status: ChatCallStatus.active,
        startedAt: session.startedAt ?? now,
        participants: participants,
      ),
      isRemote: false,
    );
    unawaited(_syncCallMediaEngine());
    _startCallTicker();
    _notifyListenersSafely();
  }

  Future<void> declineActiveCall() async {
    if (_activeCallIsRemote) {
      final session = _activeCall;
      final currentSession = sessionController.session;
      if (session == null || currentSession == null) {
        return;
      }

      unawaited(
        sendActiveCallSignal(
          'hangup',
          payload: const <String, dynamic>{'reason': 'declined'},
        ),
      );
      try {
        final payload = await _apiClient.declineChatCall(
          baseUrl: currentSession.apiBaseUrl,
          cookies: currentSession.cookies,
          callId: session.id,
        );
        await sessionController.syncCookies(payload.cookies);
        final snapshot = _workspaceFromPayload(payload.data);
        if (snapshot != null) {
          _applySnapshot(snapshot);
        }
      } on GesitApiException catch (error) {
        if (error.statusCode == 404 || error.statusCode == 501) {
          _remoteChatAvailable = false;
          _finishLocalCall(ChatCallStatus.declined);
        }
      } on TimeoutException {
        // Keep ringing state and wait for next sync.
      }
      return;
    }

    _finishLocalCall(ChatCallStatus.declined);
  }

  Future<void> endActiveCall() async {
    if (_activeCallIsRemote) {
      final session = _activeCall;
      final currentSession = sessionController.session;
      if (session == null || currentSession == null) {
        return;
      }

      unawaited(
        sendActiveCallSignal(
          'hangup',
          payload: const <String, dynamic>{'reason': 'ended'},
        ),
      );
      try {
        final payload = await _apiClient.endChatCall(
          baseUrl: currentSession.apiBaseUrl,
          cookies: currentSession.cookies,
          callId: session.id,
        );
        await sessionController.syncCookies(payload.cookies);
        final snapshot = _workspaceFromPayload(payload.data);
        if (snapshot != null) {
          _applySnapshot(snapshot);
        }
      } on GesitApiException catch (error) {
        if (error.statusCode == 404 || error.statusCode == 501) {
          _remoteChatAvailable = false;
          _finishLocalCall(ChatCallStatus.ended);
        }
      } on TimeoutException {
        // Keep call visible and let sync reconcile.
      }
      return;
    }

    final session = _activeCall;
    if (_isPreparedOutgoingCall(session)) {
      _cancelPreparedOutgoingCall(session!.id);
      return;
    }

    _finishLocalCall(ChatCallStatus.ended);
  }

  void toggleActiveCallMic() {
    final session = _activeCall;
    if (session == null) {
      return;
    }
    final micEnabled = !session.micEnabled;

    _setActiveCall(
      session.copyWith(micEnabled: micEnabled),
      isRemote: _activeCallIsRemote,
    );
    _syncCurrentUserParticipant();
    unawaited(_callMediaEngine.setMicEnabled(micEnabled));
    unawaited(_broadcastCurrentCallMediaState());
    _notifyListenersSafely();
  }

  void toggleActiveCallSpeaker() {
    final session = _activeCall;
    if (session == null) {
      return;
    }
    final speakerEnabled = !session.speakerEnabled;

    _setActiveCall(
      session.copyWith(speakerEnabled: speakerEnabled),
      isRemote: _activeCallIsRemote,
    );
    unawaited(_callMediaEngine.setSpeakerEnabled(speakerEnabled));
    _notifyListenersSafely();
  }

  void toggleActiveCallCamera() {
    final session = _activeCall;
    if (session == null) {
      return;
    }

    final cameraEnabled = !session.cameraEnabled;
    _setActiveCall(
      session.copyWith(cameraEnabled: cameraEnabled),
      isRemote: _activeCallIsRemote,
    );
    _syncCurrentUserParticipant(videoEnabled: cameraEnabled);
    unawaited(_callMediaEngine.setCameraEnabled(cameraEnabled));
    unawaited(_broadcastCurrentCallMediaState());
    _notifyListenersSafely();
  }

  Future<void> switchActiveCallCamera() {
    return _callMediaEngine.switchCamera();
  }

  Future<void> _bootstrapWorkspace() async {
    final user = sessionController.session?.user;
    if (user == null) {
      return;
    }

    final localSnapshot = await _store.readWorkspace(user.id);
    if (localSnapshot != null && _hasSnapshotData(localSnapshot)) {
      _applySnapshot(localSnapshot, notify: false, persist: false);
    } else {
      _clearWorkspace();
    }

    _notifyListenersSafely();

    await _refreshFromServer();

    if (_remoteChatAvailable) {
      _ensureSyncLoop();
    }
  }

  Future<bool> _refreshFromServer() async {
    final session = sessionController.session;
    if (session == null) {
      return false;
    }

    try {
      final payload = await _apiClient.fetchChatWorkspace(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      await sessionController.syncCookies(payload.cookies);
      final snapshot = _workspaceFromPayload(payload.data);
      if (snapshot == null) {
        return false;
      }

      _remoteChatAvailable = true;
      _syncFailureCount = 0;
      _applySnapshot(snapshot);
      return true;
    } on TimeoutException {
      _remoteChatAvailable = false;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      }
    } catch (_) {
      _remoteChatAvailable = false;
    }

    return false;
  }

  void _ensureSyncLoop() {
    if (_syncLoopRunning || !_remoteChatAvailable || _disposed) {
      return;
    }

    _syncLoopRunning = true;
    unawaited(_runSyncLoop());
  }

  Future<void> _runSyncLoop() async {
    while (!_disposed &&
        _remoteChatAvailable &&
        sessionController.session != null) {
      if (_shouldUseRealtimeChatStream) {
        await _runRealtimeStreamSync();
        if (!_shouldUseRealtimeChatStream) {
          continue;
        }
        if (!_disposed &&
            _remoteChatAvailable &&
            sessionController.session != null) {
          await _waitBeforeNextSync(
            CallRuntimeConfig.chatRealtimeStreamRetryDelay +
                _syncBackoffFor(_syncFailureCount),
          );
        }
        continue;
      }

      await _runPollingSyncOnce();
      await _waitBeforeNextSync(_syncBackoffFor(_syncFailureCount));
    }

    _syncLoopRunning = false;
  }

  bool get _shouldUseRealtimeChatStream {
    return CallRuntimeConfig.chatRealtimeStreamEnabled &&
        !kIsWeb &&
        !_chatRealtimeStreamUnavailable;
  }

  Future<void> _runRealtimeStreamSync() async {
    try {
      final session = sessionController.session;
      if (session == null) {
        return;
      }

      await for (final payload in _apiClient.streamChatWorkspace(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        afterEventId: _lastEventId,
      )) {
        if (_disposed || sessionController.session == null) {
          break;
        }

        await sessionController.syncCookies(payload.cookies);
        _remoteChatAvailable = true;
        _syncFailureCount = 0;
        _applySyncPayload(payload.data);
      }
    } on TimeoutException {
      _syncFailureCount += 1;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }
      if (error.statusCode == 404 || error.statusCode == 501) {
        _chatRealtimeStreamUnavailable = true;
        _syncFailureCount = 0;
        return;
      }
      _syncFailureCount += 1;
    } catch (_) {
      _syncFailureCount += 1;
    }
  }

  Future<void> _runPollingSyncOnce() async {
    try {
      final session = sessionController.session;
      if (session == null) {
        return;
      }

      final payload = await _apiClient.syncChatWorkspace(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        afterEventId: _lastEventId,
        waitSeconds: _syncWaitSeconds,
      );
      await sessionController.syncCookies(payload.cookies);
      _syncFailureCount = 0;
      _applySyncPayload(payload.data);
    } on TimeoutException {
      return;
    } on GesitApiException catch (error) {
      _syncFailureCount += 1;
      if (error.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }
      if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
        return;
      }
    } catch (_) {
      _syncFailureCount += 1;
    }
  }

  void _applySyncPayload(Map<String, dynamic> payload) {
    final nextEventId = (payload['last_event_id'] as num?)?.toInt();
    if (nextEventId != null && nextEventId > _lastEventId) {
      _lastEventId = nextEventId;
    }

    final snapshot = _workspaceFromPayload(payload);
    if (snapshot != null) {
      _applySnapshot(snapshot);
    }
  }

  Duration _syncBackoffFor(int failureCount) {
    if (failureCount <= 0) {
      return Duration.zero;
    }

    final seconds = math.min(8, failureCount * 2);
    return Duration(seconds: seconds);
  }

  Future<void> _waitBeforeNextSync(Duration duration) {
    if (_disposed) {
      return Future<void>.value();
    }
    if (duration <= Duration.zero) {
      return Future<void>.delayed(Duration.zero);
    }

    _cancelSyncLoopDelay();
    final completer = Completer<void>();
    _syncLoopDelayCompleter = completer;
    _syncLoopDelayTimer = Timer(duration, () {
      _syncLoopDelayTimer = null;
      _syncLoopDelayCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }

  void _cancelSyncLoopDelay() {
    _syncLoopDelayTimer?.cancel();
    _syncLoopDelayTimer = null;

    final completer = _syncLoopDelayCompleter;
    _syncLoopDelayCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  ChatWorkspaceSnapshot? _workspaceFromPayload(Map<String, dynamic> payload) {
    final events = _eventsFromPayload(payload);
    final rawWorkspace = payload['workspace'] ?? payload['chat_workspace'];
    if (rawWorkspace is Map<String, dynamic>) {
      return _normalizeSnapshotUrls(
        ChatWorkspaceSnapshot.fromJson(rawWorkspace),
      ).copyWithEvents(events);
    }
    if (rawWorkspace is Map) {
      return _normalizeSnapshotUrls(
        ChatWorkspaceSnapshot.fromJson(rawWorkspace.cast<String, dynamic>()),
      ).copyWithEvents(events);
    }

    if (payload.containsKey('conversations') ||
        payload.containsKey('messages_by_conversation')) {
      return _normalizeSnapshotUrls(
        ChatWorkspaceSnapshot.fromJson(payload),
      ).copyWithEvents(events);
    }

    return null;
  }

  List<ChatWorkspaceEvent> _eventsFromPayload(Map<String, dynamic> payload) {
    return ((payload['events'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => ChatWorkspaceEvent.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  ChatWorkspaceSnapshot _normalizeSnapshotUrls(ChatWorkspaceSnapshot snapshot) {
    final baseUrl = sessionController.session?.apiBaseUrl;
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return snapshot;
    }

    final normalizedMessages = snapshot.messagesByConversation.map((
      key,
      value,
    ) {
      return MapEntry(
        key,
        value
            .map(
              (message) => message.attachmentUrl == null
                  ? message
                  : message.copyWith(
                      attachmentUrl: AppRuntimeConfig.resolveHostedUrl(
                        baseUrl,
                        message.attachmentUrl!,
                      ),
                    ),
            )
            .toList(growable: false),
      );
    });

    return ChatWorkspaceSnapshot(
      conversations: snapshot.conversations,
      messagesByConversation: normalizedMessages,
      membersByConversation: snapshot.membersByConversation,
      assetsByConversation: snapshot.assetsByConversation,
      directoryMembers: snapshot.directoryMembers,
      activeCall: snapshot.activeCall,
      events: snapshot.events,
      lastEventId: snapshot.lastEventId,
    );
  }

  void _applySnapshot(
    ChatWorkspaceSnapshot snapshot, {
    bool notify = true,
    bool persist = true,
  }) {
    final previousMessages = <String, String?>{
      for (final entry in _messagesByConversation.entries)
        entry.key: entry.value.isEmpty ? null : entry.value.last.id,
    };
    final previousMessageLists = _messagesByConversation.map(
      (key, value) => MapEntry(key, List<ChatMessage>.from(value)),
    );
    final previousCall = _activeCall;

    _conversations
      ..clear()
      ..addAll(snapshot.conversations);
    _messagesByConversation
      ..clear()
      ..addAll(
        snapshot.messagesByConversation.map(
          (key, value) => MapEntry(
            key,
            _mergeLocalAttachmentState(previousMessageLists[key], value),
          ),
        ),
      );
    _membersByConversation
      ..clear()
      ..addAll(
        snapshot.membersByConversation.map(
          (key, value) => MapEntry(key, List<GroupMember>.from(value)),
        ),
      );
    _assetsByConversation
      ..clear()
      ..addAll(
        snapshot.assetsByConversation.map(
          (key, value) => MapEntry(key, List<ConversationAsset>.from(value)),
        ),
      );
    _directoryMembers
      ..clear()
      ..addAll(_sortMembers(List<GroupMember>.from(snapshot.directoryMembers)));
    _lastEventId = snapshot.lastEventId;
    _setActiveCall(snapshot.activeCall, isRemote: snapshot.activeCall != null);
    unawaited(_syncCallMediaEngine());

    _emitIncomingChatNotifications(previousMessages);
    _emitIncomingCallNotification(previousCall, snapshot.activeCall);

    if (_activeCall?.status == ChatCallStatus.active) {
      _startCallTicker();
    } else {
      _stopCallTicker();
    }

    _handleWorkspaceEvents(snapshot.events);

    if (persist) {
      unawaited(_persistSnapshot());
    }
    if (notify) {
      _notifyListenersSafely();
    }
  }

  Future<ChatCallSession?> _recoverOutgoingCallStart(
    String conversationId,
  ) async {
    await _refreshFromServer();
    final recoveredCall = _activeCall;
    if (recoveredCall == null) {
      return null;
    }

    if (recoveredCall.conversationId != conversationId) {
      return null;
    }

    return recoveredCall;
  }

  List<ChatMessage> _mergeLocalAttachmentState(
    List<ChatMessage>? previousMessages,
    List<ChatMessage> incomingMessages,
  ) {
    final previous = previousMessages ?? const <ChatMessage>[];
    if (previous.isEmpty) {
      return List<ChatMessage>.from(incomingMessages);
    }

    final candidates = previous
        .where(
          (message) =>
              message.hasAttachment &&
              ((message.attachmentLocalPath?.trim().isNotEmpty ?? false) ||
                  (message.attachmentPreviewBytes?.isNotEmpty ?? false)),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return List<ChatMessage>.from(incomingMessages);
    }

    final usedCandidateIndexes = <int>{};
    return incomingMessages
        .map((message) {
          if (!message.hasAttachment) {
            return message;
          }

          if ((message.attachmentLocalPath?.trim().isNotEmpty ?? false) ||
              (message.attachmentPreviewBytes?.isNotEmpty ?? false)) {
            return message;
          }

          final candidateIndex = _findLocalAttachmentCandidateIndex(
            message,
            candidates,
            usedCandidateIndexes,
          );
          if (candidateIndex == null) {
            return message;
          }

          usedCandidateIndexes.add(candidateIndex);
          final candidate = candidates[candidateIndex];
          return message.copyWith(
            attachmentLocalPath: candidate.attachmentLocalPath,
            attachmentPreviewBytes: candidate.attachmentPreviewBytes,
          );
        })
        .toList(growable: false);
  }

  int? _findLocalAttachmentCandidateIndex(
    ChatMessage target,
    List<ChatMessage> candidates,
    Set<int> usedCandidateIndexes,
  ) {
    for (var index = candidates.length - 1; index >= 0; index -= 1) {
      if (usedCandidateIndexes.contains(index)) {
        continue;
      }

      final candidate = candidates[index];
      if (candidate.isMine != target.isMine ||
          candidate.isVoiceNote != target.isVoiceNote) {
        continue;
      }

      if ((candidate.attachmentLabel ?? '').trim() !=
          (target.attachmentLabel ?? '').trim()) {
        continue;
      }

      if ((candidate.attachmentMimeType ?? '').trim() !=
          (target.attachmentMimeType ?? '').trim()) {
        continue;
      }

      if ((candidate.voiceNoteDuration ?? '').trim() !=
          (target.voiceNoteDuration ?? '').trim()) {
        continue;
      }

      if (candidate.text.trim() != target.text.trim()) {
        continue;
      }

      final candidateSentAt = candidate.sentAt;
      final targetSentAt = target.sentAt;
      if (candidateSentAt != null && targetSentAt != null) {
        final difference = candidateSentAt
            .difference(targetSentAt)
            .inSeconds
            .abs();
        if (difference > 150) {
          continue;
        }
      } else if (candidate.timeLabel != target.timeLabel) {
        continue;
      }

      return index;
    }

    return null;
  }

  void _emitIncomingChatNotifications(Map<String, String?> previousMessages) {
    for (final conversation in _conversations) {
      final latestMessage =
          (_messagesByConversation[conversation.id] ?? const []).lastOrNull;
      if (latestMessage == null) {
        continue;
      }

      if (latestMessage.isMine ||
          latestMessage.isSystem ||
          previousMessages[conversation.id] == latestMessage.id ||
          _activeConversationId == conversation.id ||
          conversation.isMuted) {
        continue;
      }

      final notificationMessage = latestMessage.hasAttachment
          ? '${latestMessage.senderName ?? conversation.title} mengirim ${latestMessage.attachmentLabel ?? 'file'}.'
          : latestMessage.isVoiceNote
          ? '${latestMessage.senderName ?? conversation.title} mengirim voice note.'
          : latestMessage.text;

      _sendTransientNotification(
        title: conversation.title,
        message: notificationMessage,
        detail:
            'Aktivitas chat hanya tampil sebagai push dan tidak disimpan di pusat notifikasi.',
        type: AppNotificationType.chat,
      );
    }
  }

  void _emitIncomingCallNotification(
    ChatCallSession? previousCall,
    ChatCallSession? nextCall,
  ) {
    if (nextCall == null ||
        !nextCall.isIncoming ||
        nextCall.status != ChatCallStatus.ringing) {
      return;
    }

    if (previousCall?.id == nextCall.id &&
        previousCall?.status == nextCall.status) {
      return;
    }

    _sendTransientNotification(
      title: nextCall.title,
      message:
          '${nextCall.type.label}${nextCall.isGroup ? ' grup' : ''} masuk dari ${nextCall.title}.',
      detail:
          'Aktivitas ini berasal dari menu chat dan tidak disimpan di pusat notifikasi.',
      type: AppNotificationType.call,
    );
  }

  Future<void> _markConversationReadRemote(String conversationId) async {
    final session = sessionController.session;
    if (session == null || !_remoteChatAvailable) {
      return;
    }

    try {
      final payload = await _apiClient.markChatConversationRead(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId,
      );
      await sessionController.syncCookies(payload.cookies);
      final snapshot = _workspaceFromPayload(payload.data);
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      }
    } on TimeoutException {
      // Keep local read state and let the next sync reconcile.
    } catch (_) {
      // Ignore transient read sync failures.
    }
  }

  Future<void> _pushConversationPreferences(String conversationId) async {
    final session = sessionController.session;
    final conversation = conversationById(conversationId);
    if (session == null || !_remoteChatAvailable || conversation == null) {
      return;
    }

    try {
      final payload = await _apiClient.updateChatConversationPreferences(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId,
        isPinned: conversation.isPinned,
        isMuted: conversation.isMuted,
      );
      await sessionController.syncCookies(payload.cookies);
      final snapshot = _workspaceFromPayload(payload.data);
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else if (error.statusCode == 404 || error.statusCode == 501) {
        _remoteChatAvailable = false;
      }
    } on TimeoutException {
      // Keep optimistic local state; sync loop will reconcile later.
    } catch (_) {
      // Ignore transient preference sync failures.
    }
  }

  ConversationPreview? _findDirectConversationForMember(GroupMember member) {
    for (final conversation in _conversations) {
      if (conversation.isGroup) {
        continue;
      }

      final members = _membersByConversation[conversation.id] ?? const [];
      final matches = members.any(
        (item) =>
            !item.isCurrentUser &&
            (item.id ?? item.name) == (member.id ?? member.name),
      );
      if (matches) {
        return conversation;
      }
    }

    return null;
  }

  void _appendMessage(String conversationId, ChatMessage message) {
    final messages = List<ChatMessage>.from(
      _messagesByConversation[conversationId] ?? const <ChatMessage>[],
    );
    messages.add(message);
    _messagesByConversation[conversationId] = messages;
  }

  void _storeAsset(String conversationId, ConversationAsset asset) {
    final assets = List<ConversationAsset>.from(
      _assetsByConversation[conversationId] ?? const <ConversationAsset>[],
    );
    assets.removeWhere((item) => item.label == asset.label);
    assets.insert(0, asset);
    _assetsByConversation[conversationId] = assets;
  }

  void _updateMessageDelivery(
    String conversationId,
    String messageId,
    MessageDelivery delivery,
  ) {
    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      return;
    }

    messages[index] = messages[index].copyWith(delivery: delivery);
    _notifyListenersSafely();
    unawaited(_persistSnapshot());
  }

  String _previewLabelForAttachment(
    String fileName, {
    required String? attachmentMimeType,
    required String caption,
  }) {
    final trimmedCaption = caption.trim();
    if (trimmedCaption.isNotEmpty) {
      return trimmedCaption;
    }

    if (attachmentMimeType?.startsWith('image/') == true) {
      return 'Foto';
    }

    return fileName;
  }

  void _promoteConversation(
    String conversationId, {
    required String preview,
    required DateTime updatedAt,
    bool resetUnread = false,
    bool incrementUnread = false,
    bool clearTyping = false,
  }) {
    _updateConversation(
      conversationId,
      (conversation) => conversation.copyWith(
        preview: preview,
        timestamp: _formatConversationTimestamp(updatedAt),
        updatedAt: updatedAt,
        unreadCount: resetUnread
            ? 0
            : incrementUnread
            ? conversation.unreadCount + 1
            : conversation.unreadCount,
        isTyping: clearTyping ? false : conversation.isTyping,
      ),
      shouldNotify: false,
    );
  }

  void _updateConversation(
    String conversationId,
    ConversationPreview Function(ConversationPreview conversation) transform, {
    bool shouldNotify = true,
  }) {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0) {
      return;
    }

    _conversations[index] = transform(_conversations[index]);
    if (shouldNotify) {
      _notifyListenersSafely();
    }
  }

  List<ChatCallParticipant> _buildCallParticipants(
    String conversationId, {
    required ChatCallType type,
    required bool connected,
  }) {
    final members = _membersByConversation[conversationId] ?? const [];
    if (members.isEmpty) {
      return [
        ChatCallParticipant(
          id: 'self-$_sessionUserId',
          name: _currentUserName,
          role: _currentUserRole,
          accentColor: AppColors.goldDeep,
          isCurrentUser: true,
          isMuted: false,
          isVideoEnabled: type == ChatCallType.video,
          isConnected: true,
        ),
      ];
    }

    return members
        .map((member) {
          return ChatCallParticipant(
            id: member.id ?? _slugify(member.name),
            name: member.name,
            role: member.role,
            accentColor: member.accentColor,
            isCurrentUser: member.isCurrentUser,
            isMuted: false,
            isVideoEnabled: type == ChatCallType.video && member.active,
            isConnected: member.isCurrentUser ? true : connected,
          );
        })
        .toList(growable: false);
  }

  void _setActiveCall(ChatCallSession? session, {required bool isRemote}) {
    _activeCall = session;
    _activeCallIsRemote = session != null && isRemote;
  }

  bool _isPreparedOutgoingCall(ChatCallSession? session) {
    return session != null &&
        session.isIncoming == false &&
        session.metadata['is_staged_outgoing'] == true;
  }

  void _cancelPreparedOutgoingCall(String provisionalCallId) {
    _cancelledPreparedOutgoingCallIds.add(provisionalCallId);
    _discardPreparedOutgoingCall(provisionalCallId);
  }

  bool _consumeCancelledPreparedOutgoingCall(String provisionalCallId) {
    return _cancelledPreparedOutgoingCallIds.remove(provisionalCallId);
  }

  void _discardPreparedOutgoingCall(String provisionalCallId) {
    final session = _activeCall;
    if (session == null ||
        session.id != provisionalCallId ||
        _activeCallIsRemote) {
      return;
    }

    _callConnectTimer?.cancel();
    _callConnectTimer = null;
    _stopCallTicker();
    _setActiveCall(null, isRemote: false);
    unawaited(_syncCallMediaEngine());
    _notifyListenersSafely();
  }

  Future<void> _endRemoteCallSilently({
    required String baseUrl,
    required Map<String, String> cookies,
    required String callId,
  }) async {
    try {
      final payload = await _apiClient.endChatCall(
        baseUrl: baseUrl,
        cookies: cookies,
        callId: callId,
      );
      await sessionController.syncCookies(payload.cookies);
    } catch (_) {
      // Ignore best-effort cleanup for cancelled optimistic calls.
    }
  }

  void _startCallTicker() {
    _callTickTimer?.cancel();
    _callTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _activeCall;
      if (session == null || session.status != ChatCallStatus.active) {
        return;
      }
      _notifyListenersSafely();
    });
  }

  void _stopCallTicker() {
    _callTickTimer?.cancel();
    _callTickTimer = null;
  }

  void _syncCurrentUserParticipant({bool? videoEnabled}) {
    final session = _activeCall;
    if (session == null) {
      return;
    }

    final participants = session.participants
        .map((participant) {
          if (!participant.isCurrentUser) {
            return participant;
          }
          return participant.copyWith(
            isMuted: !session.micEnabled,
            isVideoEnabled: videoEnabled ?? session.cameraEnabled,
          );
        })
        .toList(growable: false);

    _setActiveCall(
      session.copyWith(participants: participants),
      isRemote: _activeCallIsRemote,
    );
  }

  void _finishLocalCall(ChatCallStatus status) {
    final session = _activeCall;
    if (session == null) {
      return;
    }

    _callConnectTimer?.cancel();
    _callConnectTimer = null;
    _stopCallTicker();

    final endedAt = DateTime.now();
    final endedSession = session.copyWith(status: status, endedAt: endedAt);
    _appendMessage(
      session.conversationId,
      ChatMessage(
        id: 'call-summary-${endedAt.microsecondsSinceEpoch}',
        text: _callSummaryFor(endedSession),
        timeLabel: _formatMessageTime(endedAt),
        delivery: MessageDelivery.delivered,
        isSystem: true,
        sentAt: endedAt,
      ),
    );
    _promoteConversation(
      session.conversationId,
      preview: _callSummaryPreview(status, endedSession.type),
      updatedAt: endedAt,
      resetUnread: _activeConversationId == session.conversationId,
      incrementUnread: _activeConversationId != session.conversationId,
    );
    _setActiveCall(null, isRemote: false);
    unawaited(_syncCallMediaEngine());
    _notifyListenersSafely();
    unawaited(_persistSnapshot());
  }

  String _callSummaryFor(ChatCallSession session) {
    final scopeLabel = session.type == ChatCallType.video
        ? (session.isGroup ? 'Video call grup' : 'Video call')
        : (session.isGroup ? 'Panggilan suara grup' : 'Panggilan suara');

    switch (session.status) {
      case ChatCallStatus.ended:
        return '$scopeLabel selesai • ${_formatDuration(session.elapsed)}';
      case ChatCallStatus.missed:
        return '$scopeLabel tidak terjawab';
      case ChatCallStatus.declined:
        return '$scopeLabel ditolak';
      case ChatCallStatus.active:
      case ChatCallStatus.ringing:
        return scopeLabel;
    }
  }

  String _callSummaryPreview(ChatCallStatus status, ChatCallType type) {
    if (status == ChatCallStatus.ended) {
      return type == ChatCallType.video
          ? 'Video call selesai'
          : 'Panggilan selesai';
    }
    if (status == ChatCallStatus.missed) {
      return 'Panggilan tidak terjawab';
    }
    return 'Panggilan ditolak';
  }

  void _sendTransientNotification({
    required String title,
    required String message,
    required String detail,
    required AppNotificationType type,
  }) {
    notificationController?.receiveNotification(
      AppNotification(
        id: 'chat-push-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        message: message,
        detail: detail,
        type: type,
        createdAt: DateTime.now(),
        storesInCenter: false,
        destination: NotificationDestination.chat,
        primaryActionLabel: type == AppNotificationType.call
            ? 'Jawab'
            : 'Buka chat',
      ),
    );
  }

  Future<void> _persistSnapshot() async {
    final userId = _sessionUserId;
    if (userId.isEmpty) {
      return;
    }

    await _store.writeWorkspace(
      userId,
      ChatWorkspaceSnapshot(
        conversations: List<ConversationPreview>.from(_conversations),
        messagesByConversation: Map<String, List<ChatMessage>>.from(
          _messagesByConversation.map(
            (key, value) => MapEntry(key, List<ChatMessage>.from(value)),
          ),
        ),
        membersByConversation: Map<String, List<GroupMember>>.from(
          _membersByConversation.map(
            (key, value) => MapEntry(key, List<GroupMember>.from(value)),
          ),
        ),
        assetsByConversation: Map<String, List<ConversationAsset>>.from(
          _assetsByConversation.map(
            (key, value) => MapEntry(key, List<ConversationAsset>.from(value)),
          ),
        ),
        directoryMembers: List<GroupMember>.from(_directoryMembers),
        activeCall: _activeCall,
        events: const [],
        lastEventId: _lastEventId,
      ),
    );
  }

  int get _syncWaitSeconds {
    // Keep long-poll windows short so interactive POST actions do not feel
    // blocked by a hanging sync request during demos and regular chat usage.
    return CallRuntimeConfig.activeCallSyncWaitSeconds;
  }

  void _handleWorkspaceEvents(List<ChatWorkspaceEvent> events) {
    if (events.isEmpty) {
      return;
    }

    for (final event in events) {
      if (!event.isCallSignal) {
        continue;
      }

      final signal = ChatCallSignalEvent.fromWorkspaceEvent(event);
      if (signal.callId.isEmpty || signal.signalType.isEmpty) {
        continue;
      }

      _callSignalController.add(signal);
      unawaited(
        _callMediaEngine.handleSignal(signal, currentUserId: _sessionUserId),
      );
      _applyCallSignalSideEffects(signal);
    }
  }

  void _applyCallSignalSideEffects(ChatCallSignalEvent signal) {
    final session = _activeCall;
    if (session == null || session.id != signal.callId) {
      return;
    }

    if (signal.signalType != 'media_state') {
      return;
    }

    final micEnabled = signal.payload['mic_enabled'] != false;
    final cameraEnabled = signal.payload['camera_enabled'] == true;
    final participants = session.participants
        .map((participant) {
          if (participant.id != signal.fromUserId) {
            return participant;
          }

          return participant.copyWith(
            isMuted: !micEnabled,
            isVideoEnabled: cameraEnabled,
          );
        })
        .toList(growable: false);

    _setActiveCall(
      session.copyWith(
        metadata: {
          ...session.metadata,
          'last_signal_type': signal.signalType,
          'last_signal_event_id': signal.eventId,
        },
        participants: participants,
      ),
      isRemote: _activeCallIsRemote,
    );
    _notifyListenersSafely();
  }

  Future<void> _broadcastCurrentCallMediaState({
    String signalType = 'media_state',
  }) async {
    final session = _activeCall;
    if (session == null) {
      return;
    }
    await sendActiveCallSignal(
      signalType,
      payload: {
        'mic_enabled': session.micEnabled,
        'camera_enabled': session.cameraEnabled,
        'speaker_enabled': session.speakerEnabled,
        'call_type': session.type.storageValue,
      },
    );
  }

  void _notifyListenersSafely() {
    if (_disposed) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer =
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;
    if (!shouldDefer) {
      notifyListeners();
      return;
    }

    if (_notifyScheduled) {
      return;
    }

    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) {
        return;
      }
      notifyListeners();
    });
  }

  bool _hasSnapshotData(ChatWorkspaceSnapshot snapshot) {
    return snapshot.conversations.isNotEmpty ||
        snapshot.messagesByConversation.isNotEmpty ||
        snapshot.membersByConversation.isNotEmpty ||
        snapshot.assetsByConversation.isNotEmpty ||
        snapshot.directoryMembers.isNotEmpty ||
        snapshot.activeCall != null ||
        snapshot.lastEventId > 0;
  }

  void _clearWorkspace() {
    _conversations.clear();
    _messagesByConversation.clear();
    _membersByConversation.clear();
    _assetsByConversation.clear();
    _directoryMembers.clear();
    _lastEventId = 0;
    _setActiveCall(null, isRemote: false);
    unawaited(_syncCallMediaEngine());
  }

  Future<void> _handleUnauthorized() async {
    final userId = _sessionUserId;
    _remoteChatAvailable = false;
    _clearWorkspace();
    if (userId.isNotEmpty) {
      await _store.clearWorkspace(userId);
    }
    await sessionController.invalidateSession(
      errorMessage: 'Sesi login berakhir. Silakan masuk lagi.',
    );
  }

  List<GroupMember> _sortMembers(List<GroupMember> members) {
    final sorted = List<GroupMember>.from(members);
    sorted.sort((left, right) {
      if (left.active != right.active) {
        return left.active ? -1 : 1;
      }
      return left.name.compareTo(right.name);
    });
    return sorted;
  }

  String get _currentUserName =>
      sessionController.session?.user.name ?? 'Internal User';

  String get _currentUserRole =>
      sessionController.session?.user.primaryRole ?? 'Internal';

  String get _sessionUserId => sessionController.session?.user.id ?? '';

  void _handleCallMediaEngineChanged() {
    if (_disposed) {
      return;
    }
    _notifyListenersSafely();
  }

  Future<void> _syncCallMediaEngine() {
    return _callMediaEngine.syncSession(
      _activeCall,
      isRemote: _activeCallIsRemote,
      currentUserId: _sessionUserId,
      sendSignal: sendActiveCallSignal,
    );
  }

  String _slugify(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    return normalized.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _formatConversationTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    if (_isSameDate(now, timestamp)) {
      return DateFormat('HH:mm').format(timestamp);
    }

    if (_isSameDate(now.subtract(const Duration(days: 1)), timestamp)) {
      return 'Kemarin';
    }

    return DateFormat('dd MMM').format(timestamp);
  }

  String _formatMessageTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 35999);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(1, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelSyncLoopDelay();
    _callConnectTimer?.cancel();
    _stopCallTicker();
    for (final timer in _timers) {
      timer.cancel();
    }
    unawaited(_callSignalController.close());
    _apiClient.close();
    _callMediaEngine.removeListener(_handleCallMediaEngineChanged);
    unawaited(_callMediaEngine.close());
    super.dispose();
  }
}

extension on ChatWorkspaceSnapshot {
  ChatWorkspaceSnapshot copyWithEvents(List<ChatWorkspaceEvent> nextEvents) {
    return ChatWorkspaceSnapshot(
      conversations: conversations,
      messagesByConversation: messagesByConversation,
      membersByConversation: membersByConversation,
      assetsByConversation: assetsByConversation,
      directoryMembers: directoryMembers,
      activeCall: activeCall,
      events: nextEvents,
      lastEventId: lastEventId,
    );
  }
}

extension<T> on Iterable<T> {
  T? get lastOrNull {
    if (isEmpty) {
      return null;
    }
    return last;
  }
}
