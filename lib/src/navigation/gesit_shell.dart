import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_session_controller.dart';
import '../data/chat_call_media_engine.dart';
import '../data/chat_workspace_controller.dart';
import '../data/feed_controller.dart';
import '../data/gesit_api_client.dart';
import '../data/notification_center_controller.dart';
import '../data/workspace_data_controller.dart';
import '../models/app_models.dart';
import '../models/feed_models.dart';
import '../models/session_models.dart';
import '../screens/chat/chat_call_screen.dart';
import '../screens/chat/chat_conversation_screen.dart';
import '../screens/chat/chat_hub_screen.dart';
import '../screens/feed_thread_screen.dart';
import '../screens/chat/group_detail_screen.dart';
import '../screens/forms_screen.dart';
import '../screens/helpdesk_screen.dart';
import '../screens/home_screen.dart';
import '../screens/knowledge_workspace_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/submission_detail_screen.dart';
import '../screens/tasks_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/notification_center_sheet.dart';

class GesitShell extends StatefulWidget {
  const GesitShell({super.key, required this.sessionController});

  final AppSessionController sessionController;

  @override
  State<GesitShell> createState() => _GesitShellState();
}

class _GesitShellState extends State<GesitShell>
    with SingleTickerProviderStateMixin {
  AppShellModule _currentModule = AppShellModule.home;
  AppShellModule _previousModule = AppShellModule.home;
  bool _isTransitioning = false;
  late final AnimationController _tabTransitionController;
  late final NotificationCenterController _notificationController;
  late final WorkspaceDataController _workspaceController;
  late final ChatWorkspaceController _chatController;
  late final FeedController _feedController;
  StreamSubscription<AppNotification>? _notificationOpenRequestSubscription;

  @override
  void initState() {
    super.initState();
    _notificationController = NotificationCenterController(
      sessionController: widget.sessionController,
    );
    _notificationOpenRequestSubscription = _notificationController.openRequests
        .listen((notification) {
          unawaited(_handleNotificationOpenRequest(notification));
        });
    _chatController = ChatWorkspaceController(
      sessionController: widget.sessionController,
      notificationController: _notificationController,
      callMediaEngine: WebRtcChatCallMediaEngine(),
    );
    _workspaceController = WorkspaceDataController(
      sessionController: widget.sessionController,
    );
    _feedController = FeedController(
      sessionController: widget.sessionController,
    );
    _syncModuleControllers(_currentModule);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeStartupControllers());
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
    if (!mounted) {
      return;
    }

    await _workspaceController.ensureLoaded();
    if (!mounted) {
      return;
    }

    await _feedController.ensureLoaded();
  }

  Future<void> _ensureChatLoaded() async {
    if (!_session.canAccessChat) {
      return;
    }

    await _chatController.ensureLoaded();
  }

  @override
  void dispose() {
    _notificationOpenRequestSubscription?.cancel();
    _chatController.dispose();
    _workspaceController.dispose();
    _feedController.dispose();
    _notificationController.dispose();
    _tabTransitionController.dispose();
    super.dispose();
  }

  void _selectModule(AppShellModule module) {
    if (module == _currentModule) {
      return;
    }

    _syncModuleControllers(module);
    if (module == AppShellModule.chat) {
      unawaited(_ensureChatLoaded());
    }

    setState(() {
      _previousModule = _currentModule;
      _currentModule = module;
      _isTransitioning = true;
    });

    _tabTransitionController.forward(from: 0);
  }

  void _syncModuleControllers(AppShellModule module) {
    _feedController.setAutoRefreshActive(module == AppShellModule.home);
    _chatController.setSyncActive(module == AppShellModule.chat);
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

  void _openAiAssist() {
    pushBrandedRoute(
      context,
      KnowledgeWorkspaceScreen(sessionController: widget.sessionController),
    );
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

  Future<void> _openConversationById(
    String conversationId, {
    String? callId,
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
      pushBrandedRoute(
        context,
        ChatCallScreen(
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
    if (preparedCall == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masih ada panggilan aktif yang belum selesai.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    pushBrandedRoute(
      context,
      ChatCallScreen(
        controller: _chatController,
        conversationId: preparedCall.conversationId,
      ),
    );

    try {
      await _chatController.connectPreparedOutgoingCall(
        preparedCall.id,
        conversationId: conversationId,
        type: type,
      );
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Panggilan belum bisa dimulai. Coba lagi.'),
        ),
      );
      return;
    }
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

  AppSession get _session => widget.sessionController.session!;

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
    if ((_session.user.id).isEmpty) {
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
    if (await _openNotificationLink(notification.link)) {
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
        if (_session.canAccessTasks) {
          _selectModule(AppShellModule.tasks);
        }
        return;
      case NotificationDestination.forms:
        if (_session.canAccessForms) {
          _selectModule(AppShellModule.forms);
        }
        return;
      case NotificationDestination.helpdesk:
        if (_session.canAccessHelpdesk) {
          _openHelpdesk();
        }
        return;
      case NotificationDestination.chat:
        if (_session.canAccessChat) {
          _selectModule(AppShellModule.chat);
        }
        return;
      case NotificationDestination.knowledgeHub:
        if (_session.canAccessKnowledgeHub) {
          _openKnowledgeHub();
        }
        return;
      case NotificationDestination.profile:
        _selectModule(AppShellModule.profile);
        return;
    }
  }

  Future<bool> _openNotificationLink(String? rawLink) async {
    final normalizedLink = rawLink?.trim();
    if (normalizedLink == null || normalizedLink.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(normalizedLink);
    final path = uri?.path.isNotEmpty == true ? uri!.path : normalizedLink;
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
    if (conversationId != null && _session.canAccessChat) {
      try {
        await _openConversationById(
          conversationId,
          callId: uri?.queryParameters['call'],
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

    final submissionId = _submissionIdFromPath(path);
    if (submissionId != null && _session.canAccessTasks) {
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
      if (_session.canAccessHelpdesk) {
        _openHelpdesk();
      }
      return true;
    }

    if (path.contains('/knowledge-hub')) {
      if (_session.canAccessKnowledgeHub) {
        _openKnowledgeHub();
      }
      return true;
    }

    if (path.contains('/forms')) {
      if (_session.canAccessForms) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _notificationController,
        _chatController,
        _workspaceController,
        _feedController,
      ]),
      builder: (context, _) {
        final session = _session;
        final modules = session.shellModules;
        final resolvedCurrentModule = modules.contains(_currentModule)
            ? _currentModule
            : modules.first;
        final resolvedPreviousModule = modules.contains(_previousModule)
            ? _previousModule
            : modules.first;
        final items = modules
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
        final screens = <AppShellModule, Widget>{
          AppShellModule.home: HomeScreen(
            key: const PageStorageKey('home-tab'),
            userName: session.user.name,
            userInitials: session.user.initials,
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
            onOpenChat: () => _selectModule(AppShellModule.chat),
            onOpenAiAssist: _openAiAssist,
            onOpenHelpdesk: _openHelpdesk,
            onOpenNotifications: _openNotifications,
            unreadNotificationCount: _notificationController.unreadCount,
            feedController: _feedController,
            onOpenFeedThread: _openFeedThread,
          ),
          if (session.canAccessTasks)
            AppShellModule.tasks: TasksScreen(
              key: const PageStorageKey('tasks-tab'),
              controller: _workspaceController,
              onOpenTask: _openSubmission,
            ),
          if (session.canAccessForms)
            AppShellModule.forms: FormsScreen(
              key: PageStorageKey('forms-tab'),
              controller: _workspaceController,
            ),
          if (session.canAccessChat)
            AppShellModule.chat: ChatHubScreen(
              key: const PageStorageKey('chat-tab'),
              controller: _chatController,
              onOpenConversation: _openConversation,
            ),
          AppShellModule.profile: ProfileScreen(
            key: const PageStorageKey('profile-tab'),
            userName: session.user.name,
            userInitials: session.user.initials,
            userRoleLabel: session.user.primaryRole,
            userDivisionLabel: session.user.divisionLabel,
            canOpenTasks: session.canAccessTasks,
            canOpenKnowledgeHub: session.canAccessKnowledgeHub,
            canOpenHelpdesk: session.canAccessHelpdesk,
            onOpenTasks: () => _selectModule(AppShellModule.tasks),
            onOpenKnowledgeHub: _openKnowledgeHub,
            onOpenHelpdesk: _openHelpdesk,
            onLogout: () {
              widget.sessionController.signOut();
            },
          ),
        };
        final activeBanner = _notificationController.activeBanner;
        final incomingCall = _chatController.hasIncomingCall
            ? _chatController.activeCall
            : null;

        return Scaffold(
          extendBody: true,
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

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final module in modules)
                            _TabBodyLayer(
                              isActive: module == resolvedCurrentModule,
                              isOutgoing:
                                  _isTransitioning &&
                                  module == resolvedPreviousModule,
                              progress: progress,
                              child: screens[module] ?? const SizedBox.shrink(),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: AnimatedSwitcher(
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
                              onTap: () => unawaited(
                                _handleNotificationOpenRequest(activeBanner),
                              ),
                              onDismiss:
                                  _notificationController.dismissActiveBanner,
                            ),
                    ),
                  ),
                ),
              ),
              if (incomingCall != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 120,
                  child: SafeArea(
                    top: false,
                    child: _IncomingCallCard(
                      session: incomingCall,
                      accentColor:
                          _chatController
                              .conversationById(incomingCall.conversationId)
                              ?.accentColor ??
                          AppColors.goldDeep,
                      onDecline: () =>
                          unawaited(_chatController.declineActiveCall()),
                      onAccept: () async {
                        await _chatController.acceptActiveCall();
                        if (!context.mounted) {
                          return;
                        }
                        pushBrandedRoute(
                          context,
                          ChatCallScreen(
                            controller: _chatController,
                            conversationId: incomingCall.conversationId,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F291C09),
                      blurRadius: 36,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectModule(items[index].module),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  resolvedCurrentModule == items[index].module
                                  ? AppColors.goldSoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _NavIcon(
                                  icon: items[index].icon,
                                  badgeCount: items[index].badgeCount,
                                  color:
                                      resolvedCurrentModule ==
                                          items[index].module
                                      ? AppColors.goldDeep
                                      : AppColors.inkMuted,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  items[index].label,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color:
                                            resolvedCurrentModule ==
                                                items[index].module
                                            ? AppColors.goldDeep
                                            : AppColors.inkMuted,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
      padding: const EdgeInsets.all(18),
      radius: 30,
      backgroundColor: AppColors.surface,
      child: Row(
        children: [
          ConversationAvatar(
            label: session.title,
            accentColor: accentColor,
            isGroup: session.isGroup,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.type.label}${session.isGroup ? ' grup' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecline,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.red.withValues(alpha: 0.12),
              foregroundColor: AppColors.red,
            ),
            icon: const Icon(Icons.call_end_rounded),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onAccept,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.emerald.withValues(alpha: 0.16),
              foregroundColor: AppColors.emerald,
            ),
            icon: const Icon(Icons.call_rounded),
          ),
        ],
      ),
    );
  }
}

class _TabBodyLayer extends StatelessWidget {
  const _TabBodyLayer({
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
