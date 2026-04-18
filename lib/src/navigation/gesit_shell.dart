import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/notification_center_controller.dart';
import '../models/app_models.dart';
import '../screens/chat/chat_conversation_screen.dart';
import '../screens/chat/chat_hub_screen.dart';
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
  const GesitShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<GesitShell> createState() => _GesitShellState();
}

class _GesitShellState extends State<GesitShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _isTransitioning = false;
  late final AnimationController _tabTransitionController;
  late final NotificationCenterController _notificationController;

  @override
  void initState() {
    super.initState();
    _notificationController = NotificationCenterController()..startDemoFeed();
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

  @override
  void dispose() {
    _notificationController.dispose();
    _tabTransitionController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _currentIndex) {
      return;
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _isTransitioning = true;
    });

    _tabTransitionController.forward(from: 0);
  }

  void _openSubmission(TaskItem task) {
    pushBrandedRoute(context, SubmissionDetailScreen(task: task));
  }

  void _openHelpdesk() {
    pushBrandedRoute(context, const HelpdeskScreen());
  }

  void _openKnowledgeHub() {
    pushBrandedRoute(context, const KnowledgeWorkspaceScreen());
  }

  void _openAiAssist() {
    pushBrandedRoute(context, const KnowledgeWorkspaceScreen());
  }

  void _openConversation(ConversationPreview conversation) {
    pushBrandedRoute(
      context,
      ChatConversationScreen(
        conversation: conversation,
        onOpenGroupDetail: conversation.isGroup
            ? () => pushBrandedRoute(
                context,
                GroupDetailScreen(conversation: conversation),
              )
            : null,
      ),
    );
  }

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

    _notificationController.markAsRead(notificationId);
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

    _openNotificationDestination(detailNotification);
  }

  void _openNotificationDestination(AppNotification notification) {
    switch (notification.destination) {
      case NotificationDestination.none:
        return;
      case NotificationDestination.tasks:
        _selectTab(1);
        return;
      case NotificationDestination.forms:
        _selectTab(2);
        return;
      case NotificationDestination.helpdesk:
        _openHelpdesk();
        return;
      case NotificationDestination.chat:
        _selectTab(3);
        return;
      case NotificationDestination.knowledgeHub:
        _openKnowledgeHub();
        return;
      case NotificationDestination.profile:
        _selectTab(4);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _notificationController,
      builder: (context, _) {
        final items = [
          _NavItem(label: 'Home', icon: Icons.dashboard_rounded),
          _NavItem(label: 'Tasks', icon: Icons.fact_check_rounded),
          _NavItem(label: 'Forms', icon: Icons.description_rounded),
          _NavItem(
            label: 'Chat',
            icon: Icons.forum_rounded,
            badgeCount: DemoData.unreadChatCount,
          ),
          _NavItem(label: 'Profile', icon: Icons.person_rounded),
        ];
        final screens = <Widget>[
          HomeScreen(
            key: const PageStorageKey('home-tab'),
            onOpenTasks: () => _selectTab(1),
            onOpenForms: () => _selectTab(2),
            onOpenAiAssist: _openAiAssist,
            onOpenHelpdesk: _openHelpdesk,
            onOpenNotifications: _openNotifications,
            unreadNotificationCount: _notificationController.unreadCount,
          ),
          TasksScreen(
            key: const PageStorageKey('tasks-tab'),
            onOpenTask: _openSubmission,
          ),
          const FormsScreen(key: PageStorageKey('forms-tab')),
          ChatHubScreen(
            key: const PageStorageKey('chat-tab'),
            onOpenConversation: _openConversation,
          ),
          ProfileScreen(
            key: const PageStorageKey('profile-tab'),
            onOpenTasks: () => _selectTab(1),
            onOpenKnowledgeHub: _openKnowledgeHub,
            onOpenHelpdesk: _openHelpdesk,
            onLogout: widget.onLogout,
          ),
        ];
        final activeBanner = _notificationController.activeBanner;

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
            child: _currentIndex == 3
                ? FloatingActionButton(
                    key: const ValueKey('chat-fab'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'UI compose chat baru sudah siap untuk tahap backend.',
                          ),
                        ),
                      );
                    },
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
                          for (var index = 0; index < screens.length; index++)
                            _TabBodyLayer(
                              isActive: index == _currentIndex,
                              isOutgoing:
                                  _isTransitioning && index == _previousIndex,
                              progress: progress,
                              child: screens[index],
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
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
                              onTap: () =>
                                  _openNotificationDetail(activeBanner.id),
                              onDismiss:
                                  _notificationController.dismissActiveBanner,
                            ),
                    ),
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
                          onTap: () => _selectTab(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _currentIndex == index
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
                                  color: _currentIndex == index
                                      ? AppColors.goldDeep
                                      : AppColors.inkMuted,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  items[index].label,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: _currentIndex == index
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
    required this.label,
    required this.icon,
    this.badgeCount = 0,
  });

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
