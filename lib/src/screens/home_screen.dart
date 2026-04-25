import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../data/feed_controller.dart';
import '../data/demo_data.dart';
import '../models/feed_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/feed_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.userInitials,
    required this.userRoleLabel,
    required this.userDivisionLabel,
    required this.activeFormCount,
    required this.pendingActionCount,
    required this.canOpenTasks,
    required this.canOpenForms,
    required this.canOpenHelpdesk,
    required this.canOpenChat,
    required this.onOpenTasks,
    required this.onOpenForms,
    required this.onOpenChat,
    required this.onOpenAiAssist,
    required this.onOpenHelpdesk,
    required this.onOpenNotifications,
    required this.unreadNotificationCount,
    required this.feedController,
    required this.onOpenFeedThread,
  });

  final String userName;
  final String userInitials;
  final String userRoleLabel;
  final String userDivisionLabel;
  final int activeFormCount;
  final int pendingActionCount;
  final bool canOpenTasks;
  final bool canOpenForms;
  final bool canOpenHelpdesk;
  final bool canOpenChat;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenForms;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAiAssist;
  final VoidCallback onOpenHelpdesk;
  final VoidCallback onOpenNotifications;
  final int unreadNotificationCount;
  final FeedController feedController;
  final ValueChanged<FeedPost> onOpenFeedThread;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _openComposer() async {
    try {
      await widget.feedController.ensureAudienceMembersLoaded();
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }

    if (!mounted) {
      return;
    }

    final draft = await showFeedComposerSheet(
      context,
      userDivisionLabel: widget.userDivisionLabel,
      audienceMembers: widget.feedController.audienceMembers,
    );
    if (!mounted || draft == null) {
      return;
    }

    try {
      await widget.feedController.createPost(
        content: draft.content,
        visibility: draft.visibility,
        recipientUserIds: draft.recipientUserIds,
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _togglePostLike(FeedPost post) async {
    try {
      await widget.feedController.togglePostLike(post.id);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Hapus postingan?'),
        content: const Text(
          'Postingan ini akan hilang dari feed untuk audience yang bisa melihatnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.feedController.deletePost(post.id);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final today = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_now);
    final currentTime = DateFormat('HH:mm:ss', 'id_ID').format(_now);
    final firstName = widget.userName
        .trim()
        .split(RegExp(r'\s+'))
        .firstWhere((part) => part.isNotEmpty, orElse: () => 'User');
    final statusCards = <Widget>[
      if (widget.canOpenForms)
        Expanded(
          child: _CompactStatusCard(
            title: 'Form Aktif',
            value: '${widget.activeFormCount}',
            subtitle: 'Tersedia',
            icon: Icons.description_rounded,
            accentColor: AppColors.goldDeep,
            onTap: widget.onOpenForms,
          ),
        ),
      if (widget.canOpenTasks)
        Expanded(
          child: _CompactStatusCard(
            title: 'Task',
            value: '${widget.pendingActionCount}',
            subtitle: 'Perlu aksi',
            icon: Icons.fact_check_rounded,
            accentColor: AppColors.blue,
            onTap: widget.onOpenTasks,
          ),
        ),
      if (widget.canOpenHelpdesk)
        Expanded(
          child: _CompactStatusCard(
            title: 'Helpdesk',
            value: '${DemoData.openHelpdeskCount}',
            subtitle: 'Open',
            icon: Icons.support_agent_rounded,
            accentColor: AppColors.red,
            onTap: widget.onOpenHelpdesk,
          ),
        ),
      if (widget.canOpenChat)
        Expanded(
          child: _CompactStatusCard(
            title: 'Chat',
            value: '${DemoData.unreadChatCount}',
            subtitle: 'Belum dibaca',
            icon: Icons.forum_rounded,
            accentColor: AppColors.emerald,
            onTap: widget.onOpenChat,
          ),
        ),
    ];
    final visibleStatusCards = statusCards.take(3).toList(growable: false);
    final feedPosts = widget.feedController.posts
        .take(4)
        .toList(growable: false);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomBarInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealUp(
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/branding/company-login-lockup.svg',
                  height: 30,
                ),
                const Spacer(),
                _NotificationButton(
                  unreadCount: widget.unreadNotificationCount,
                  onTap: widget.onOpenNotifications,
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.goldDeep, AppColors.gold],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.userInitials,
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(firstName, style: textTheme.labelLarge),
                          Text(
                            widget.userRoleLabel,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          RevealUp(
            index: 1,
            child: BrandSurface(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat datang, $firstName.',
                    style: textTheme.headlineMedium?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      StatusChip(
                        label: '$today • $currentTime',
                        color: AppColors.goldDeep,
                        icon: Icons.calendar_today_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (widget.canOpenTasks)
                        SizedBox(
                          width: 164,
                          child: FilledButton.icon(
                            onPressed: widget.onOpenTasks,
                            icon: const Icon(Icons.fact_check_rounded),
                            label: const Text('Tasks'),
                          ),
                        ),
                      if (widget.canOpenForms)
                        SizedBox(
                          width: 164,
                          child: OutlinedButton.icon(
                            onPressed: widget.onOpenForms,
                            icon: const Icon(Icons.description_rounded),
                            label: const Text('Forms'),
                          ),
                        ),
                      SizedBox(
                        width: 164,
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenAiAssist,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('AI Assist'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(eyebrow: 'Status', title: 'Today'),
          const SizedBox(height: 14),
          if (visibleStatusCards.isNotEmpty)
            Row(
              children: [
                for (
                  var index = 0;
                  index < visibleStatusCards.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 12),
                  visibleStatusCards[index],
                ],
              ],
            ),
          const SizedBox(height: 24),
          SectionHeader(
            eyebrow: 'Feed',
            title: 'Update Internal',
            trailing: SizedBox(
              width: 52,
              height: 52,
              child: FilledButton(
                onPressed: widget.feedController.creatingPost
                    ? null
                    : _openComposer,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: widget.feedController.creatingPost
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (widget.feedController.loading && feedPosts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.feedController.error != null && feedPosts.isEmpty)
            BrandSurface(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Feed belum bisa dimuat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.feedController.error!,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else if (feedPosts.isEmpty)
            BrandSurface(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Belum ada update di feed. Mulai thread pertama dari dashboard ini.',
                style: textTheme.bodyMedium,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < feedPosts.length; index++) ...[
                  if (index > 0) const SizedBox(height: 14),
                  RevealUp(
                    index: 2 + index,
                    child: FeedPostCard(
                      post: feedPosts[index],
                      compact: true,
                      onOpenThread: () =>
                          widget.onOpenFeedThread(feedPosts[index]),
                      onToggleLike: () =>
                          unawaited(_togglePostLike(feedPosts[index])),
                      onDelete: feedPosts[index].canDelete
                          ? () => unawaited(_deletePost(feedPosts[index]))
                          : null,
                      likeBusy: widget.feedController.isPostLikeBusy(
                        feedPosts[index].id,
                      ),
                    ),
                  ),
                ],
                if (widget.feedController.hasMore) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: widget.feedController.loadingMore
                        ? null
                        : () => unawaited(widget.feedController.loadMore()),
                    icon: widget.feedController.loadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: const Text('Muat lagi'),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final badgeLabel = unreadCount > 9 ? '9+' : '$unreadCount';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: hasUnread ? AppColors.goldSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasUnread ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.ink,
                ),
              ),
              if (hasUnread)
                Positioned(
                  top: 8,
                  right: 7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
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

class _CompactStatusCard extends StatelessWidget {
  const _CompactStatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: BrandSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: accentColor),
            const Spacer(),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
