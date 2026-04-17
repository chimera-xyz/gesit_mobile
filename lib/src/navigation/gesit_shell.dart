import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/chat/chat_conversation_screen.dart';
import '../screens/chat/chat_hub_screen.dart';
import '../screens/chat/group_detail_screen.dart';
import '../screens/forms_screen.dart';
import '../screens/helpdesk_screen.dart';
import '../screens/home_screen.dart';
import '../screens/knowledge_assistant_screen.dart';
import '../screens/knowledge_hub_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/submission_detail_screen.dart';
import '../screens/tasks_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

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

  @override
  void initState() {
    super.initState();
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
    pushBrandedRoute(context, const KnowledgeHubScreen());
  }

  void _openAiAssist() {
    pushBrandedRoute(context, const KnowledgeAssistantScreen());
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

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavItem(label: 'Home', icon: Icons.dashboard_rounded),
      _NavItem(label: 'Tasks', icon: Icons.fact_check_rounded),
      _NavItem(label: 'Forms', icon: Icons.description_rounded),
      _NavItem(label: 'Chat', icon: Icons.forum_rounded),
      _NavItem(label: 'Profile', icon: Icons.person_rounded),
    ];
    final screens = <Widget>[
      HomeScreen(
        key: const PageStorageKey('home-tab'),
        onOpenTasks: () => _selectTab(1),
        onOpenForms: () => _selectTab(2),
        onOpenAiAssist: _openAiAssist,
        onOpenChat: () => _selectTab(3),
        onOpenHelpdesk: _openHelpdesk,
        onOpenSubmission: _openSubmission,
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
      body: GesitBackground(
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
                      isOutgoing: _isTransitioning && index == _previousIndex,
                      progress: progress,
                      child: screens[index],
                    ),
                ],
              );
            },
          ),
        ),
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
                            Icon(
                              items[index].icon,
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
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
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
