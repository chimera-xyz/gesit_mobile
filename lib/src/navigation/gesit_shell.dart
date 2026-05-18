import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_session_controller.dart';
import '../data/app_link_controller.dart';
import '../data/chat_call_media_engine.dart';
import '../data/chat_workspace_controller.dart';
import '../data/feed_controller.dart';
import '../data/gesit_api_client.dart';
import '../data/home_banner_controller.dart';
import '../data/leave_data_controller.dart';
import '../data/meeting_workspace_controller.dart';
import '../data/notification_center_controller.dart';
import '../data/push_notification_models.dart';
import '../data/push_notification_service.dart';
import '../data/workspace_data_controller.dart';
import '../models/app_models.dart';
import '../models/feed_models.dart';
import '../models/home_banner_models.dart';
import '../models/meeting_models.dart';
import '../models/session_models.dart';
import '../screens/chat/chat_conversation_screen.dart';
import '../screens/chat/chat_hub_screen.dart';
import '../screens/chat/livekit_chat_call_screen.dart' as chat_call_ui;
import '../screens/feed_screen.dart';
import '../screens/feed_thread_screen.dart';
import '../screens/chat/group_detail_screen.dart';
import '../screens/forms_screen.dart';
import '../screens/helpdesk_screen.dart';
import '../screens/home_screen.dart';
import '../screens/knowledge_workspace_screen.dart';
import '../screens/leave_dashboard_screen.dart';
import '../screens/meeting/meeting_hub_screen.dart';
import '../screens/meeting/livekit_chat_call_screen.dart' as meeting_call_ui;
import '../screens/meeting/meeting_room_screen.dart';
import '../screens/meeting/meeting_waiting_room_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/profile_detail_screen.dart';
import '../screens/submission_detail_screen.dart';
import '../screens/tasks_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/notification_center_sheet.dart';

class GesitShell extends StatefulWidget {
  const GesitShell({
    super.key,
    required this.sessionController,
    required this.appLinkController,
  });

  final AppSessionController sessionController;
  final AppLinkController appLinkController;

  @override
  State<GesitShell> createState() => _GesitShellState();
}

class _GesitShellState extends State<GesitShell>
    with SingleTickerProviderStateMixin {
  AppShellModule _currentModule = AppShellModule.home;
  AppShellModule _previousModule = AppShellModule.home;
  bool _isTransitioning = false;
  bool _launcherExpanded = false;
  final Set<AppShellModule> _visitedModules = <AppShellModule>{
    AppShellModule.home,
  };
  late final AnimationController _tabTransitionController;
  late final NotificationCenterController _notificationController;
  late final WorkspaceDataController _workspaceController;
  late final LeaveDataController _leaveController;
  late final ChatWorkspaceController _chatController;
  late final MeetingWorkspaceController _meetingController;
  late final FeedController _feedController;
  late final HomeBannerController _homeBannerController;
  late final Listenable _homeTabListenable;
  late final Listenable _navigationListenable;
  StreamSubscription<AppNotification>? _notificationOpenRequestSubscription;
  StreamSubscription<PushNotificationEnvelope>? _foregroundPushSubscription;

  @override
  void initState() {
    super.initState();
    _notificationController = NotificationCenterController(
      sessionController: widget.sessionController,
    );
    widget.appLinkController.addListener(_handleAppLinkChanged);
    _notificationOpenRequestSubscription = _notificationController.openRequests
        .listen((notification) {
          unawaited(_handleNotificationOpenRequest(notification));
        });
    _chatController = ChatWorkspaceController(
      sessionController: widget.sessionController,
      notificationController: _notificationController,
      callMediaEngine: NoopChatCallMediaEngine(),
    );
    _foregroundPushSubscription = PushNotificationService.instance.messages
        .listen((envelope) {
          if (envelope.isCall) {
            unawaited(_handleForegroundCallPush());
          }
        });
    _workspaceController = WorkspaceDataController(
      sessionController: widget.sessionController,
    );
    _leaveController = LeaveDataController(
      sessionController: widget.sessionController,
    );
    _meetingController = MeetingWorkspaceController(
      sessionController: widget.sessionController,
    );
    _feedController = FeedController(
      sessionController: widget.sessionController,
    );
    _homeBannerController = HomeBannerController(
      sessionController: widget.sessionController,
    );
    _homeTabListenable = Listenable.merge([
      _notificationController,
      _workspaceController,
      _leaveController,
      _feedController,
      _homeBannerController,
    ]);
    _navigationListenable = Listenable.merge([
      _chatController,
      _meetingController,
      _notificationController,
      _workspaceController,
    ]);
    _syncModuleControllers(_currentModule);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeStartupControllers());
      _handleAppLinkChanged();
    });
    _tabTransitionController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 210),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _isTransitioning = false);
          }
        });
  }

  Future<void> _primeStartupControllers() async {
    await _notificationController.ensureLoaded();
    var session = _currentSession;
    if (!mounted || session == null) {
      return;
    }

    await _workspaceController.ensureLoaded();
    session = _currentSession;
    if (!mounted || session == null) {
      return;
    }

    if (session.canAccessLeave) {
      await _leaveController.ensureLoaded();
      session = _currentSession;
      if (!mounted || session == null) {
        return;
      }
    }

    if (session.canAccessMeeting) {
      unawaited(_meetingController.ensureLoaded());
    }

    if (session.canAccessChat) {
      unawaited(_ensureChatLoaded());
    }

    await _feedController.ensureLoaded();
    if (!mounted || _currentSession == null) {
      return;
    }

    await _homeBannerController.ensureLoaded();
  }

  Future<void> _ensureChatLoaded() async {
    final session = _currentSession;
    if (session == null || !session.canAccessChat) {
      return;
    }

    await _chatController.ensureLoaded();
  }

  Future<void> _handleForegroundCallPush() async {
    final session = _currentSession;
    if (session == null || !session.canAccessChat) {
      return;
    }

    await _ensureChatLoaded();
    await _chatController.refreshNow();
  }

  @override
  void dispose() {
    widget.appLinkController.removeListener(_handleAppLinkChanged);
    _notificationOpenRequestSubscription?.cancel();
    _foregroundPushSubscription?.cancel();
    _chatController.dispose();
    _meetingController.dispose();
    _workspaceController.dispose();
    _leaveController.dispose();
    _feedController.dispose();
    _homeBannerController.dispose();
    _notificationController.dispose();
    _tabTransitionController.dispose();
    super.dispose();
  }

  void _setLauncherExpanded(bool expanded) {
    if (_launcherExpanded == expanded) {
      return;
    }

    setState(() => _launcherExpanded = expanded);
  }

  void _toggleLauncherExpanded() {
    setState(() => _launcherExpanded = !_launcherExpanded);
  }

  void _handleHomeNavigationTap() {
    if (_currentModule == AppShellModule.home) {
      _setLauncherExpanded(false);
      return;
    }

    _selectModule(AppShellModule.home);
  }

  void _selectModule(AppShellModule module, {bool expandLauncher = false}) {
    if (module == _currentModule) {
      _setLauncherExpanded(expandLauncher);
      return;
    }

    _syncModuleControllers(module);
    if (module == AppShellModule.chat) {
      unawaited(_ensureChatLoaded());
    }
    if (module == AppShellModule.meeting) {
      unawaited(_meetingController.ensureLoaded());
    }

    setState(() {
      _previousModule = _currentModule;
      _currentModule = module;
      _visitedModules.add(module);
      _isTransitioning = true;
      _launcherExpanded = expandLauncher;
    });

    _tabTransitionController.forward(from: 0);
  }

  void _syncModuleControllers(AppShellModule module) {
    _feedController.setAutoRefreshActive(module == AppShellModule.home);
    // Incoming calls are shell-level events, not chat-tab-only events. Keep the
    // chat realtime/polling listener alive while the authenticated user has
    // chat access so calls surface on Home, Tasks, Meeting, Profile, etc.
    _chatController.setSyncActive(_currentSession?.canAccessChat == true);
  }

  void _openSubmission(TaskItem task) {
    pushBrandedRoute(
      context,
      SubmissionDetailScreen(task: task, controller: _workspaceController),
    );
  }

  void _openHelpdesk() {
    pushBrandedRoute(context, const HelpdeskScreen());
  }

  void _openFeedThread(FeedPost post) {
    pushBrandedRoute(
      context,
      FeedThreadScreen(controller: _feedController, postId: post.id),
    );
  }

  void _openFeedTimeline() {
    final session = _currentSession;
    if (session == null) {
      return;
    }

    pushBrandedRoute(
      context,
      FeedScreen(
        controller: _feedController,
        userDivisionLabel: session.user.divisionLabel,
        onOpenThread: _openFeedThread,
      ),
    );
  }

  Future<void> _openHomeBanner(HomeBannerItem banner) async {
    final session = _currentSession;
    if (session == null) {
      return;
    }

    final actionType = banner.actionType.trim();

    switch (actionType) {
      case 'forms':
        if (session.canAccessForms) {
          _selectModule(AppShellModule.forms);
        }
        return;
      case 'tasks':
        if (session.canAccessTasks) {
          _selectModule(AppShellModule.tasks);
        }
        return;
      case 'leave':
        if (session.canAccessLeave) {
          _openLeaveDashboard();
        }
        return;
      case 'chat':
        if (session.canAccessChat) {
          _selectModule(AppShellModule.chat);
        }
        return;
      case 'helpdesk':
        if (session.canAccessHelpdesk) {
          _openHelpdesk();
        }
        return;
      case 'ai_assist':
        if (session.canAccessKnowledgeHub) {
          _openAiAssist();
        }
        return;
      case 'feed':
        final postId = banner.actionValue?.trim();
        if (postId != null && postId.isNotEmpty) {
          await _openFeedThreadById(postId);
        } else {
          _openFeedTimeline();
        }
        return;
      case 'url':
        await _openBannerUrl(banner.actionValue);
        return;
      case 'none':
      default:
        return;
    }
  }

  Future<void> _openBannerUrl(String? rawUrl) async {
    final url = rawUrl?.trim();
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return;
    }

    final bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link banner belum bisa dibuka.')),
      );
      return;
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link banner belum bisa dibuka.')),
      );
    }
  }

  Future<void> _openFeedThreadById(String postId) async {
    _selectModule(AppShellModule.home);
    final post =
        _feedController.threadById(postId) ?? _feedController.postById(postId);

    if (post == null) {
      await _feedController.fetchThread(postId, forceRefresh: true);
    }

    if (!mounted) {
      return;
    }

    final resolvedPost =
        _feedController.threadById(postId) ?? _feedController.postById(postId);
    if (resolvedPost == null) {
      throw const GesitApiException(
        'Thread feed belum bisa dibuka dari notifikasi.',
      );
    }

    _openFeedThread(resolvedPost);
  }

  void _openKnowledgeHub() {
    pushBrandedRoute(
      context,
      KnowledgeWorkspaceScreen(
        sessionController: widget.sessionController,
        openDocuments: true,
      ),
    );
  }

  void _openSharedKnowledgeDocument(String token) {
    pushBrandedRoute(
      context,
      KnowledgeWorkspaceScreen(
        sessionController: widget.sessionController,
        openDocuments: true,
        initialShareToken: token,
      ),
    );
  }

  void _handleAppLinkChanged() {
    final rawLink = widget.appLinkController.pendingLink;
    if (rawLink == null || rawLink.trim().isEmpty || !mounted) {
      return;
    }

    final uri = Uri.tryParse(rawLink);
    final path = uri?.path.isNotEmpty == true ? uri!.path : rawLink;
    final shareToken = _shareTokenFromPath(path);
    widget.appLinkController.consume(rawLink);
    if (shareToken != null) {
      _openSharedKnowledgeDocument(shareToken);
      return;
    }

    unawaited(
      _openNotificationLink(
        AppNotification(
          id: 'deep-link-${DateTime.now().microsecondsSinceEpoch}',
          title: 'GESIT',
          message: '',
          detail: '',
          type:
              path.contains('/chat/conversations') &&
                  (uri?.queryParameters.containsKey('call') ?? false)
              ? AppNotificationType.call
              : path.contains('/meetings')
              ? AppNotificationType.meeting
              : AppNotificationType.system,
          createdAt: DateTime.now(),
          storesInCenter: false,
          destination: path.contains('/chat/conversations')
              ? NotificationDestination.chat
              : path.contains('/meetings')
              ? NotificationDestination.meeting
              : NotificationDestination.none,
          link: rawLink,
        ),
      ),
    );
  }

  void _openAiAssist() {
    pushBrandedRoute(
      context,
      KnowledgeWorkspaceScreen(sessionController: widget.sessionController),
    );
  }

  void _openLeaveDashboard() {
    _setLauncherExpanded(false);
    pushBrandedRoute(
      context,
      LeaveDashboardScreen(controller: _leaveController),
    );
  }

  void _openProfileDetails() {
    pushBrandedRoute(
      context,
      ProfileDetailScreen(sessionController: widget.sessionController),
    );
  }

  List<_LauncherItem> _buildLauncherItems(
    AppSession session,
    AppShellModule currentModule,
  ) {
    return <_LauncherItem>[
      if (session.canAccessTasks)
        _LauncherItem(
          label: AppShellModule.tasks.label,
          icon: AppShellModule.tasks.icon,
          accentColor: AppColors.goldDeep,
          selected: currentModule == AppShellModule.tasks,
          badgeCount: _workspaceController.pendingActionCount,
          onTap: () => _selectModule(AppShellModule.tasks),
        ),
      if (session.canAccessForms)
        _LauncherItem(
          label: AppShellModule.forms.label,
          icon: AppShellModule.forms.icon,
          accentColor: AppColors.blue,
          selected: currentModule == AppShellModule.forms,
          onTap: () => _selectModule(AppShellModule.forms),
        ),
      _LauncherItem(
        label: 'Cuti',
        icon: Icons.beach_access_rounded,
        accentColor: AppColors.goldDeep,
        onTap: _openLeaveDashboard,
      ),
      _LauncherItem(
        label: 'AI Assist',
        icon: Icons.auto_awesome_rounded,
        accentColor: AppColors.emerald,
        onTap: () {
          _setLauncherExpanded(false);
          _openAiAssist();
        },
      ),
      if (session.canAccessChat)
        _LauncherItem(
          label: AppShellModule.chat.label,
          icon: AppShellModule.chat.icon,
          accentColor: AppColors.blue,
          selected: currentModule == AppShellModule.chat,
          badgeCount: _chatController.unreadConversationCount,
          onTap: () => _selectModule(AppShellModule.chat),
        ),
      if (session.canAccessMeeting)
        _LauncherItem(
          label: AppShellModule.meeting.label,
          icon: AppShellModule.meeting.icon,
          accentColor: AppColors.emerald,
          selected: currentModule == AppShellModule.meeting,
          onTap: () => _selectModule(AppShellModule.meeting),
        ),
      if (session.canAccessHelpdesk)
        _LauncherItem(
          label: 'Helpdesk',
          icon: Icons.support_agent_rounded,
          accentColor: AppColors.red,
          onTap: () {
            _setLauncherExpanded(false);
            _openHelpdesk();
          },
        ),
      _LauncherItem(
        label: AppShellModule.profile.label,
        icon: AppShellModule.profile.icon,
        accentColor: AppColors.goldDeep,
        selected: currentModule == AppShellModule.profile,
        onTap: () => _selectModule(AppShellModule.profile),
      ),
    ];
  }

  void _openConversation(ConversationPreview conversation) {
    unawaited(
      _ensureChatLoaded().then((_) {
        if (!mounted) {
          return;
        }

        pushBrandedRoute(
          context,
          ChatConversationScreen(
            controller: _chatController,
            conversationId: conversation.id,
            onOpenGroupDetail: conversation.isGroup
                ? () => pushBrandedRoute(
                    context,
                    GroupDetailScreen(
                      controller: _chatController,
                      conversationId: conversation.id,
                      onStartVoiceCall: () => unawaited(
                        _startCall(conversation.id, type: ChatCallType.voice),
                      ),
                      onStartVideoCall: () => unawaited(
                        _startCall(conversation.id, type: ChatCallType.video),
                      ),
                    ),
                  )
                : null,
            onStartVoiceCall: () => unawaited(
              _startCall(conversation.id, type: ChatCallType.voice),
            ),
            onStartVideoCall: () => unawaited(
              _startCall(conversation.id, type: ChatCallType.video),
            ),
          ),
        );
      }),
    );
  }

  void _openMeetingRoom(MeetingSummary meeting) {
    unawaited(() async {
      final attempt = await _meetingController.joinMeeting(meeting.id);
      if (!mounted) {
        return;
      }

      if (attempt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _meetingController.errorMessage ??
                  'Meeting belum bisa dibuka. Periksa konfigurasi LiveKit.',
            ),
          ),
        );
        return;
      }

      _openMeetingAttempt(attempt);
    }());
  }

  Future<void> _openMeetingById(String meetingId) async {
    final meeting = await _meetingController.fetchMeetingById(meetingId);
    if (!mounted) {
      return;
    }

    if (meeting == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meeting tidak ditemukan.')));
      return;
    }

    _openMeetingRoom(meeting);
  }

  Future<void> _openConversationById(
    String conversationId, {
    String? callId,
    String? notificationAction,
  }) async {
    await _ensureChatLoaded();
    if (!mounted) {
      return;
    }

    _selectModule(AppShellModule.chat);
    final conversation = _chatController.conversationById(conversationId);
    if (conversation == null) {
      throw const GesitApiException(
        'Percakapan belum bisa dibuka dari notifikasi.',
      );
    }

    final activeCall = _chatController.activeCall;
    if (callId != null &&
        activeCall != null &&
        activeCall.id == callId &&
        activeCall.conversationId == conversationId) {
      if (notificationAction == 'decline') {
        await _chatController.declineActiveCall();
        return;
      }
      if (notificationAction == 'answer' && activeCall.isIncoming) {
        await _chatController.acceptActiveCall();
        if (!mounted) {
          return;
        }
      }
      pushBrandedRoute(
        context,
        chat_call_ui.LiveKitChatCallScreen(
          controller: _chatController,
          conversationId: conversationId,
        ),
      );
      return;
    }

    _openConversation(conversation);
  }

  Future<void> _startCall(
    String conversationId, {
    required ChatCallType type,
  }) async {
    final preparedCall = _chatController.prepareOutgoingCall(
      conversationId,
      type: type,
    );

    if (!mounted) {
      return;
    }

    if (preparedCall == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masih ada panggilan aktif.')),
      );
      return;
    }

    pushBrandedRoute(
      context,
      chat_call_ui.LiveKitChatCallScreen(
        controller: _chatController,
        conversationId: conversationId,
      ),
    );

    unawaited(
      _chatController
          .connectPreparedOutgoingCall(
            preparedCall.id,
            conversationId: conversationId,
            type: type,
          )
          .catchError((error) {
            if (!mounted) {
              return null;
            }
            final message = error is GesitApiException
                ? error.message
                : 'Panggilan belum bisa dimulai.';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            return null;
          }),
    );
  }

  void _openMeetingAttempt(MeetingJoinAttempt attempt) {
    if (attempt.waitingRoom) {
      pushBrandedRoute(
        context,
        MeetingWaitingRoomScreen(
          controller: _meetingController,
          initialMeeting: attempt.meeting,
          onAdmitted: (nextAttempt) {
            Navigator.of(context).pop();
            _openMeetingAttempt(nextAttempt);
          },
        ),
      );
      return;
    }

    final credentials = attempt.credentials;
    if (credentials == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credential LiveKit tidak lengkap.')),
      );
      return;
    }

    pushBrandedRoute(
      context,
      attempt.meeting.isCall
          ? meeting_call_ui.LiveKitChatCallScreen(
              controller: _meetingController,
              meeting: attempt.meeting,
              credentials: credentials,
            )
          : MeetingRoomScreen(
              controller: _meetingController,
              meeting: attempt.meeting,
              credentials: credentials,
            ),
    );
  }

  Future<void> _openChatComposer() async {
    await _ensureChatLoaded();
    if (!mounted) {
      return;
    }
    final selectedConversation =
        await showModalBottomSheet<ConversationPreview>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _StartChatSheet(controller: _chatController),
        );

    if (!mounted || selectedConversation == null) {
      return;
    }

    _openConversation(selectedConversation);
  }

  AppSession? get _currentSession => widget.sessionController.session;

  Future<void> _openNotifications() async {
    final selectedNotification = await showModalBottomSheet<AppNotification>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          NotificationCenterSheet(controller: _notificationController),
    );

    if (!mounted || selectedNotification == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _openNotificationDetail(selectedNotification.id);
  }

  Future<void> _openNotificationDetail(String notificationId) async {
    final notification = _notificationController.notificationById(
      notificationId,
    );
    if (notification == null) {
      return;
    }

    await _notificationController.markAsRead(notificationId);
    if (!mounted) {
      return;
    }
    final detailNotification =
        _notificationController.notificationById(notificationId) ??
        notification.copyWith(isRead: true);

    final openLinkedContent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          NotificationDetailSheet(notification: detailNotification),
    );

    if (!mounted || openLinkedContent != true) {
      return;
    }

    await _openNotificationDestination(detailNotification);
  }

  Future<void> _handleNotificationOpenRequest(
    AppNotification notification,
  ) async {
    final session = _currentSession;
    if (session == null || session.user.id.isEmpty) {
      return;
    }

    await _notificationController.markAsRead(notification.id);
    if (!mounted) {
      return;
    }

    await _openNotificationDestination(notification);
  }

  Future<void> _openNotificationDestination(
    AppNotification notification,
  ) async {
    final session = _currentSession;
    if (session == null) {
      return;
    }

    if (await _openNotificationLink(notification)) {
      return;
    }

    switch (notification.destination) {
      case NotificationDestination.none:
        return;
      case NotificationDestination.feed:
        final link = notification.link;
        final postId = link == null
            ? null
            : _feedPostIdFromPath(Uri.tryParse(link)?.path ?? link);
        if (postId != null) {
          await _openFeedThreadById(postId);
        }
        return;
      case NotificationDestination.tasks:
        if (session.canAccessTasks) {
          _selectModule(AppShellModule.tasks);
        }
        return;
      case NotificationDestination.forms:
        if (session.canAccessForms) {
          _selectModule(AppShellModule.forms);
        }
        return;
      case NotificationDestination.helpdesk:
        if (session.canAccessHelpdesk) {
          _openHelpdesk();
        }
        return;
      case NotificationDestination.chat:
        if (session.canAccessChat) {
          _selectModule(AppShellModule.chat);
        }
        return;
      case NotificationDestination.meeting:
        if (session.canAccessMeeting) {
          _selectModule(AppShellModule.meeting);
        }
        return;
      case NotificationDestination.knowledgeHub:
        if (session.canAccessKnowledgeHub) {
          _openKnowledgeHub();
        }
        return;
      case NotificationDestination.leave:
        if (notification.type == AppNotificationType.approval &&
            session.canAccessTasks) {
          unawaited(_workspaceController.refreshTasks());
          _selectModule(AppShellModule.tasks);
        } else {
          _openLeaveDashboard();
        }
        return;
      case NotificationDestination.profile:
        _selectModule(AppShellModule.profile);
        return;
    }
  }

  Future<bool> _openNotificationLink(AppNotification notification) async {
    final session = _currentSession;
    if (session == null) {
      return false;
    }

    final rawLink = notification.link;
    final normalizedLink = rawLink?.trim();
    if (normalizedLink == null || normalizedLink.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(normalizedLink);
    final path = uri?.path.isNotEmpty == true ? uri!.path : normalizedLink;
    final shareToken = _shareTokenFromPath(path);
    if (shareToken != null) {
      _openSharedKnowledgeDocument(shareToken);
      return true;
    }

    final feedPostId = _feedPostIdFromPath(path);
    if (feedPostId != null) {
      try {
        await _openFeedThreadById(feedPostId);
      } on GesitApiException catch (error) {
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thread feed belum bisa dibuka langsung.'),
          ),
        );
      }
      return true;
    }

    final conversationId = _conversationIdFromPath(path);
    if (conversationId != null && session.canAccessChat) {
      try {
        await _openConversationById(
          conversationId,
          callId: uri?.queryParameters['call'],
          notificationAction: uri?.queryParameters['notification_action'],
        );
      } on GesitApiException catch (error) {
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat belum bisa dibuka langsung dari notifikasi.'),
          ),
        );
      }
      return true;
    }

    final meetingId = _meetingIdFromPath(path);
    if (meetingId != null && session.canAccessMeeting) {
      if (uri?.queryParameters['notification_action'] == 'decline') {
        await _meetingController.endMeeting(meetingId);
        return true;
      }
      await _openMeetingById(meetingId);
      return true;
    }

    final submissionId = _submissionIdFromPath(path);
    if (submissionId != null && session.canAccessTasks) {
      try {
        _selectModule(AppShellModule.tasks);
        final task = await _workspaceController.findOrFetchTaskById(
          submissionId,
        );
        if (!mounted) {
          return true;
        }
        _openSubmission(task);
      } on GesitApiException catch (error) {
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detail notifikasi belum bisa dibuka langsung.'),
          ),
        );
      }
      return true;
    }

    if (path.contains('/helpdesk')) {
      if (session.canAccessHelpdesk) {
        _openHelpdesk();
      }
      return true;
    }

    if (path.contains('/knowledge-hub')) {
      if (session.canAccessKnowledgeHub) {
        _openKnowledgeHub();
      }
      return true;
    }

    if (path.contains('/leaves')) {
      if (notification.type == AppNotificationType.approval &&
          session.canAccessTasks) {
        unawaited(_workspaceController.refreshTasks());
        _selectModule(AppShellModule.tasks);
      } else {
        _openLeaveDashboard();
      }
      return true;
    }

    if (path.contains('/forms')) {
      if (session.canAccessForms) {
        _selectModule(AppShellModule.forms);
      }
      return true;
    }

    if (path.contains('/profile') || path.contains('/user/profile')) {
      _selectModule(AppShellModule.profile);
      return true;
    }

    return false;
  }

  String? _submissionIdFromPath(String path) {
    final match = RegExp(
      r'/(?:submissions|form-submissions)/([^/?#]+)',
    ).firstMatch(path);
    final submissionId = match?.group(1)?.trim();
    if (submissionId == null || submissionId.isEmpty) {
      return null;
    }

    return submissionId;
  }

  String? _shareTokenFromPath(String path) {
    final match = RegExp(r'/share/docs/([^/?#]+)').firstMatch(path);
    final token = match?.group(1)?.trim();
    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }

  String? _feedPostIdFromPath(String path) {
    final match = RegExp(r'/feed/posts/([^/?#]+)').firstMatch(path);
    final postId = match?.group(1)?.trim();
    if (postId == null || postId.isEmpty) {
      return null;
    }

    return postId;
  }

  String? _conversationIdFromPath(String path) {
    final match = RegExp(r'/chat/conversations/([^/?#]+)').firstMatch(path);
    final conversationId = match?.group(1)?.trim();
    if (conversationId == null || conversationId.isEmpty) {
      return null;
    }

    return conversationId;
  }

  String? _meetingIdFromPath(String path) {
    final match = RegExp(r'/meetings/([^/?#]+)').firstMatch(path);
    final meetingId = match?.group(1)?.trim();
    if (meetingId == null || meetingId.isEmpty) {
      return null;
    }

    return meetingId;
  }

  @override
  Widget build(BuildContext context) {
    final session = _currentSession;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final modules = session.shellModules;
    final navigationModules = session.bottomNavigationModules;
    final resolvedCurrentModule = modules.contains(_currentModule)
        ? _currentModule
        : modules.first;
    final resolvedPreviousModule = modules.contains(_previousModule)
        ? _previousModule
        : modules.first;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: false,
      backgroundColor: Colors.transparent,
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: resolvedCurrentModule == AppShellModule.chat
            ? FloatingActionButton(
                key: const ValueKey('chat-fab'),
                onPressed: _openChatComposer,
                backgroundColor: AppColors.goldDeep,
                foregroundColor: Colors.white,
                child: const Icon(Icons.edit_rounded),
              )
            : const SizedBox.shrink(key: ValueKey('empty-fab')),
      ),
      body: Stack(
        children: [
          GesitBackground(
            child: SafeArea(
              bottom: false,
              child: AnimatedBuilder(
                animation: _tabTransitionController,
                builder: (context, _) {
                  final progress = _isTransitioning
                      ? Curves.easeOutCubic.transform(
                          _tabTransitionController.value,
                        )
                      : 1.0;
                  final bodyModules = modules
                      .where(
                        (module) =>
                            module == resolvedCurrentModule ||
                            (_isTransitioning &&
                                module == resolvedPreviousModule) ||
                            _visitedModules.contains(module),
                      )
                      .toList(growable: false);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final module in bodyModules)
                        _TabBodyLayer(
                          key: ValueKey('tab-layer-${module.name}'),
                          isActive: module == resolvedCurrentModule,
                          isOutgoing:
                              _isTransitioning &&
                              module == resolvedPreviousModule,
                          progress: progress,
                          child: _buildModuleScreen(module, session),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_launcherExpanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _setLauncherExpanded(false),
                child: const SizedBox.expand(),
              ),
            ),
          if (!keyboardVisible)
            Positioned(
              left: 14,
              right: 14,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _navigationListenable,
                builder: (context, _) => _LauncherOverlay(
                  expanded: _launcherExpanded,
                  items: _buildLauncherItems(session, resolvedCurrentModule),
                ),
              ),
            ),
          _NotificationBannerLayer(
            controller: _notificationController,
            onOpenRequest: _handleNotificationOpenRequest,
          ),
          _IncomingCallLayer(
            controller: _chatController,
            onAccept: _acceptIncomingCall,
          ),
        ],
      ),
      bottomNavigationBar: keyboardVisible
          ? null
          : AnimatedBuilder(
              animation: _navigationListenable,
              builder: (context, _) {
                final items = navigationModules
                    .map(
                      (module) => _NavItem(
                        module: module,
                        label: module.label,
                        icon: module.icon,
                        badgeCount: module == AppShellModule.chat
                            ? _chatController.unreadConversationCount
                            : 0,
                      ),
                    )
                    .toList(growable: false);

                return _ShellBottomNavigationBar(
                  items: items,
                  currentModule: resolvedCurrentModule,
                  onHomeTap: _handleHomeNavigationTap,
                  onSelect: _selectModule,
                );
              },
            ),
    );
  }

  Widget _buildModuleScreen(AppShellModule module, AppSession session) {
    return switch (module) {
      AppShellModule.home => AnimatedBuilder(
        animation: _homeTabListenable,
        builder: (context, _) => HomeScreen(
          key: const PageStorageKey('home-tab'),
          userName: session.user.name,
          userInitials: session.user.initials,
          userProfilePhotoUrl: session.user.resolvedProfilePhotoUrl(
            session.apiBaseUrl,
          ),
          userRoleLabel: session.user.primaryRole,
          userDivisionLabel: session.user.divisionLabel,
          activeFormCount: _workspaceController.activeFormCount,
          pendingActionCount: _workspaceController.pendingActionCount,
          canOpenTasks: session.canAccessTasks,
          canOpenForms: session.canAccessForms,
          canOpenHelpdesk: session.canAccessHelpdesk,
          canOpenChat: session.canAccessChat,
          onOpenTasks: () => _selectModule(AppShellModule.tasks),
          onOpenForms: () => _selectModule(AppShellModule.forms),
          onOpenLeave: _openLeaveDashboard,
          onOpenChat: () => _selectModule(AppShellModule.chat),
          onOpenAiAssist: _openAiAssist,
          onOpenHelpdesk: _openHelpdesk,
          onOpenNotifications: _openNotifications,
          onOpenProfileDetails: _openProfileDetails,
          onToggleLauncher: _toggleLauncherExpanded,
          unreadNotificationCount: _notificationController.unreadCount,
          feedController: _feedController,
          homeBannerController: _homeBannerController,
          apiBaseUrl: session.apiBaseUrl,
          onOpenFeedThread: _openFeedThread,
          onOpenAllFeed: _openFeedTimeline,
          onOpenHomeBanner: (banner) => unawaited(_openHomeBanner(banner)),
          leaveSummary: _leaveController.dashboard.summary,
        ),
      ),
      AppShellModule.tasks when session.canAccessTasks => TasksScreen(
        key: const PageStorageKey('tasks-tab'),
        controller: _workspaceController,
        onOpenTask: _openSubmission,
      ),
      AppShellModule.forms when session.canAccessForms => FormsScreen(
        key: const PageStorageKey('forms-tab'),
        controller: _workspaceController,
      ),
      AppShellModule.chat when session.canAccessChat => ChatHubScreen(
        key: const PageStorageKey('chat-tab'),
        controller: _chatController,
        onOpenConversation: _openConversation,
      ),
      AppShellModule.meeting when session.canAccessMeeting => MeetingHubScreen(
        key: const PageStorageKey('meeting-tab'),
        controller: _meetingController,
        onJoinMeeting: _openMeetingRoom,
      ),
      AppShellModule.profile => ProfileScreen(
        key: const PageStorageKey('profile-tab'),
        userName: session.user.name,
        userInitials: session.user.initials,
        userProfilePhotoUrl: session.user.resolvedProfilePhotoUrl(
          session.apiBaseUrl,
        ),
        userBio: session.user.bio,
        userRoleLabel: session.user.primaryRole,
        userDivisionLabel: session.user.divisionLabel,
        canOpenTasks: session.canAccessTasks,
        canOpenKnowledgeHub: session.canAccessKnowledgeHub,
        canOpenHelpdesk: session.canAccessHelpdesk,
        onOpenTasks: () => _selectModule(AppShellModule.tasks),
        onOpenKnowledgeHub: _openKnowledgeHub,
        onOpenHelpdesk: _openHelpdesk,
        onOpenProfileDetails: _openProfileDetails,
        onLogout: widget.sessionController.signOut,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _acceptIncomingCall(ChatCallSession incomingCall) async {
    await _chatController.acceptActiveCall();
    if (!mounted) {
      return;
    }

    pushBrandedRoute(
      context,
      chat_call_ui.LiveKitChatCallScreen(
        controller: _chatController,
        conversationId: incomingCall.conversationId,
      ),
    );
  }
}

class _NotificationBannerLayer extends StatelessWidget {
  const _NotificationBannerLayer({
    required this.controller,
    required this.onOpenRequest,
  });

  final NotificationCenterController controller;
  final Future<void> Function(AppNotification notification) onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 20,
      right: 20,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final activeBanner = controller.activeBanner;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.12),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: activeBanner == null
                    ? const SizedBox.shrink(
                        key: ValueKey('notification-banner-empty'),
                      )
                    : NotificationHeadsUpBanner(
                        key: ValueKey(activeBanner.id),
                        notification: activeBanner,
                        onTap: () => unawaited(onOpenRequest(activeBanner)),
                        onDismiss: controller.dismissActiveBanner,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IncomingCallLayer extends StatefulWidget {
  const _IncomingCallLayer({required this.controller, required this.onAccept});

  final ChatWorkspaceController controller;
  final Future<void> Function(ChatCallSession incomingCall) onAccept;

  @override
  State<_IncomingCallLayer> createState() => _IncomingCallLayerState();
}

class _IncomingCallLayerState extends State<_IncomingCallLayer> {
  late final AudioPlayer _ringtonePlayer;
  String? _ringingCallId;

  @override
  void initState() {
    super.initState();
    _ringtonePlayer = AudioPlayer();
    widget.controller.addListener(_syncRingtone);
    _syncRingtone();
  }

  @override
  void didUpdateWidget(covariant _IncomingCallLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_syncRingtone);
    widget.controller.addListener(_syncRingtone);
    _syncRingtone();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncRingtone);
    unawaited(_ringtonePlayer.dispose());
    super.dispose();
  }

  void _syncRingtone() {
    final incomingCall = widget.controller.hasIncomingCall
        ? widget.controller.activeCall
        : null;
    if (incomingCall == null) {
      _ringingCallId = null;
      unawaited(_ringtonePlayer.stop());
      return;
    }

    if (_ringingCallId == incomingCall.id && _ringtonePlayer.playing) {
      return;
    }

    _ringingCallId = incomingCall.id;
    unawaited(_startRingtone());
  }

  Future<void> _startRingtone() async {
    try {
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.setVolume(0.92);
      await _ringtonePlayer.setAsset(
        'assets/audio/yulie_sekuritas_notifikasi_v2.wav',
      );
      await _ringtonePlayer.play();
    } catch (_) {
      try {
        await _ringtonePlayer.setAsset(
          'assets/audio/yulie_sekuritas_notifikasi.mp3',
        );
        await _ringtonePlayer.play();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final incomingCall = widget.controller.hasIncomingCall
            ? widget.controller.activeCall
            : null;
        if (incomingCall == null) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: SafeArea(
            child: Material(
              color: Colors.black.withValues(alpha: 0.46),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _IncomingCallCard(
                    session: incomingCall,
                    accentColor:
                        widget.controller
                            .conversationById(incomingCall.conversationId)
                            ?.accentColor ??
                        AppColors.goldDeep,
                    onDecline: () =>
                        unawaited(widget.controller.declineActiveCall()),
                    onAccept: () => unawaited(widget.onAccept(incomingCall)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LauncherOverlay extends StatefulWidget {
  const _LauncherOverlay({required this.expanded, required this.items});

  final bool expanded;
  final List<_LauncherItem> items;

  @override
  State<_LauncherOverlay> createState() => _LauncherOverlayState();
}

class _LauncherOverlayState extends State<_LauncherOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 220),
      value: widget.expanded ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _LauncherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) {
      return;
    }

    if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.expanded,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!widget.expanded && _controller.value == 0) {
            return const SizedBox.shrink();
          }

          final progress = Curves.easeOutCubic.transform(_controller.value);

          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, (1 - progress) * 18),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: progress,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.99),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A291C09),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: _LauncherPanel(
                        items: widget.items,
                        progress: progress,
                        onTap: (item) => item.onTap(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShellBottomNavigationBar extends StatelessWidget {
  const _ShellBottomNavigationBar({
    required this.items,
    required this.currentModule,
    required this.onHomeTap,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final AppShellModule currentModule;
  final VoidCallback onHomeTap;
  final ValueChanged<AppShellModule> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.canvasTop,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A291C09),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: _ShellNavigationItem(
                      item: item,
                      selected: item.module == currentModule,
                      textTheme: textTheme,
                      onTap: item.module == AppShellModule.home
                          ? onHomeTap
                          : () => onSelect(item.module),
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

class _ShellNavigationItem extends StatelessWidget {
  const _ShellNavigationItem({
    required this.item,
    required this.selected,
    required this.textTheme,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.goldDeep : AppColors.inkMuted;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldSoft.withValues(alpha: 0.86) : null,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavIcon(
                icon: item.icon,
                badgeCount: item.badgeCount,
                color: color,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LauncherPanel extends StatelessWidget {
  const _LauncherPanel({
    required this.items,
    required this.progress,
    required this.onTap,
  });

  final List<_LauncherItem> items;
  final double progress;
  final ValueChanged<_LauncherItem> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const columns = 3;
        const horizontalPadding = 8.0;
        final itemWidth =
            (constraints.maxWidth -
                horizontalPadding -
                (spacing * (columns - 1))) /
            columns;

        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var index = 0; index < items.length; index++)
                SizedBox(
                  width: itemWidth,
                  child: _LauncherActionButton(
                    item: items[index],
                    progress: _staggeredProgress(progress, index),
                    onTap: () => onTap(items[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _staggeredProgress(double progress, int index) {
    final delay = (index * 0.055).clamp(0.0, 0.36).toDouble();
    final value = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    return value.toDouble();
  }
}

class _LauncherActionButton extends StatelessWidget {
  const _LauncherActionButton({
    required this.item,
    required this.progress,
    required this.onTap,
  });

  final _LauncherItem item;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final backgroundColor = item.selected
        ? item.accentColor.withValues(alpha: 0.12)
        : AppColors.surfaceAlt;
    final borderColor = item.selected
        ? item.accentColor.withValues(alpha: 0.34)
        : AppColors.border;

    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * -8),
        child: Transform.scale(
          scale: 0.96 + (progress * 0.04),
          child: Semantics(
            button: true,
            selected: item.selected,
            label: item.label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  height: 76,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: item.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.accentColor,
                                size: 20,
                              ),
                            ),
                            if (item.badgeCount > 0)
                              Positioned(
                                top: -7,
                                right: -9,
                                child: _NavBadge(count: item.badgeCount),
                              ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LauncherItem {
  const _LauncherItem({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.selected = false,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool selected;
  final int badgeCount;
}

class _NavItem {
  const _NavItem({
    required this.module,
    required this.label,
    required this.icon,
    this.badgeCount = 0,
  });

  final AppShellModule module;
  final String label;
  final IconData icon;
  final int badgeCount;
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.color,
    required this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (badgeCount > 0)
          Positioned(top: -8, right: -12, child: _NavBadge(count: badgeCount)),
      ],
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.surface.withValues(alpha: 0.96),
          width: 1.2,
        ),
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _StartChatSheet extends StatelessWidget {
  const _StartChatSheet({required this.controller});

  final ChatWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final contacts = controller.directoryMembers;
    final groups = controller.groupConversations;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: BrandSurface(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          radius: 34,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
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
                const SizedBox(height: 16),
                Text(
                  'Mulai Chat',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                if (contacts.isNotEmpty) ...[
                  Text(
                    'Kontak',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.goldDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...contacts
                      .take(6)
                      .map(
                        (member) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BrandSurface(
                            onTap: () async {
                              try {
                                final conversation = await controller
                                    .ensureDirectConversation(member);
                                if (context.mounted) {
                                  Navigator.of(context).pop(conversation);
                                }
                              } catch (_) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Kontak chat belum siap dari server. Coba login ulang lalu muat lagi.',
                                    ),
                                  ),
                                );
                              }
                            },
                            padding: const EdgeInsets.all(14),
                            radius: 24,
                            child: Row(
                              children: [
                                ConversationAvatar(
                                  label: member.name,
                                  accentColor: member.accentColor,
                                  showOnlineDot: member.active,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        member.role,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                ],
                if (contacts.isEmpty && groups.isEmpty)
                  const BrandSurface(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Belum ada user atau grup chat yang tersedia dari server.',
                    ),
                  ),
                if (groups.isNotEmpty) ...[
                  Text(
                    'Grup',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.goldDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...groups
                      .take(4)
                      .map(
                        (conversation) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BrandSurface(
                            onTap: () =>
                                Navigator.of(context).pop(conversation),
                            padding: const EdgeInsets.all(14),
                            radius: 24,
                            child: Row(
                              children: [
                                ConversationAvatar(
                                  label: conversation.title,
                                  accentColor: conversation.accentColor,
                                  isGroup: true,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conversation.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        conversation.subtitle,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingCallCard extends StatelessWidget {
  const _IncomingCallCard({
    required this.session,
    required this.accentColor,
    required this.onDecline,
    required this.onAccept,
  });

  final ChatCallSession session;
  final Color accentColor;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      radius: 34,
      backgroundColor: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.14),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.28),
                  blurRadius: 34,
                  spreadRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: ConversationAvatar(
              label: session.title,
              accentColor: accentColor,
              isGroup: session.isGroup,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            session.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.type.label}${session.isGroup ? ' grup' : ''} masuk',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDecline,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.call_end_rounded),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Terima'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBodyLayer extends StatelessWidget {
  const _TabBodyLayer({
    super.key,
    required this.isActive,
    required this.isOutgoing,
    required this.progress,
    required this.child,
  });

  final bool isActive;
  final bool isOutgoing;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isActive && !isOutgoing) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }

    final opacity = isActive ? progress : (1 - progress);
    final translateY = isActive ? (1 - progress) * 10 : progress * -4;
    final scale = isActive
        ? (0.996 + (progress * 0.004))
        : (1 - (progress * 0.002));

    return IgnorePointer(
      ignoring: !isActive,
      child: TickerMode(
        enabled: isActive || isOutgoing,
        child: RepaintBoundary(
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
