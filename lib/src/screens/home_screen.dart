import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../data/feed_controller.dart';
import '../data/demo_data.dart';
import '../models/feed_models.dart';
import '../models/leave_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/feed_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.userInitials,
    this.userProfilePhotoUrl,
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
    required this.onOpenLeave,
    required this.onOpenChat,
    required this.onOpenAiAssist,
    required this.onOpenHelpdesk,
    required this.onOpenNotifications,
    required this.onOpenProfileDetails,
    required this.onToggleLauncher,
    required this.unreadNotificationCount,
    required this.feedController,
    required this.onOpenFeedThread,
    required this.onOpenAllFeed,
    this.leaveSummary,
  });

  final String userName;
  final String userInitials;
  final String? userProfilePhotoUrl;
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
  final VoidCallback onOpenLeave;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAiAssist;
  final VoidCallback onOpenHelpdesk;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfileDetails;
  final VoidCallback onToggleLauncher;
  final int unreadNotificationCount;
  final FeedController feedController;
  final ValueChanged<FeedPost> onOpenFeedThread;
  final VoidCallback onOpenAllFeed;
  final LeaveDashboardSummary? leaveSummary;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        .take(2)
        .toList(growable: false);
    final currentLeave = widget.leaveSummary?.currentLeave;

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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onOpenProfileDetails,
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
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
                          UserProfileAvatar(
                            initials: widget.userInitials,
                            photoUrl: widget.userProfilePhotoUrl,
                            size: 34,
                            radius: 13,
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          RevealUp(
            index: 1,
            child: _WelcomePanel(
              firstName: firstName,
              canOpenForms: widget.canOpenForms,
              onOpenForms: widget.onOpenForms,
              onOpenLeave: widget.onOpenLeave,
              onOpenAiAssist: widget.onOpenAiAssist,
              onToggleLauncher: widget.onToggleLauncher,
            ),
          ),
          if (currentLeave != null) ...[
            const SizedBox(height: 14),
            RevealUp(
              index: 2,
              child: _TodayLeaveBanner(
                request: currentLeave,
                returnDate: widget.leaveSummary?.currentLeaveReturnDate,
                onTap: widget.onOpenLeave,
              ),
            ),
          ],
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
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: widget.onOpenAllFeed,
                  icon: const Icon(Icons.dynamic_feed_rounded),
                  label: const Text('Lihat semua feed'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TodayLeaveBanner extends StatelessWidget {
  const _TodayLeaveBanner({
    required this.request,
    required this.returnDate,
    required this.onTap,
  });

  final LeaveRequestItem request;
  final DateTime? returnDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final leaveName = request.leaveType?.name ?? 'Cuti';

    return BrandSurface(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.green.withValues(alpha: 0.06),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.beach_access_rounded,
              color: AppColors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sedang $leaveName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatHomeDateRange(request.startDate, request.endDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (returnDate != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Masuk lagi ${_formatHomeShortDate(returnDate!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.inkMuted,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.firstName,
    required this.canOpenForms,
    required this.onOpenForms,
    required this.onOpenLeave,
    required this.onOpenAiAssist,
    required this.onToggleLauncher,
  });

  final String firstName;
  final bool canOpenForms;
  final VoidCallback onOpenForms;
  final VoidCallback onOpenLeave;
  final VoidCallback onOpenAiAssist;
  final VoidCallback onToggleLauncher;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actions = <_WelcomeAction>[
      _WelcomeAction(
        title: 'Cuti',
        icon: Icons.beach_access_rounded,
        accentColor: AppColors.goldDeep,
        emphasized: true,
        onTap: onOpenLeave,
      ),
      if (canOpenForms)
        _WelcomeAction(
          title: 'Forms',
          icon: Icons.description_rounded,
          accentColor: AppColors.blue,
          emphasized: false,
          onTap: onOpenForms,
        ),
      _WelcomeAction(
        title: 'AI Assist',
        icon: Icons.auto_awesome_rounded,
        accentColor: AppColors.emerald,
        emphasized: false,
        onTap: onOpenAiAssist,
      ),
    ];

    return BrandSurface(
      radius: 22,
      padding: const EdgeInsets.all(18),
      backgroundColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $firstName.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 25,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Workspace internal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Semantics(
                button: true,
                label: 'Buka menu navigasi',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggleLauncher,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: AppColors.goldDeep,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _ClockStatusChip(),
          const SizedBox(height: 14),
          _WelcomeActionGrid(actions: actions),
        ],
      ),
    );
  }
}

class _WelcomeAction {
  const _WelcomeAction({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.emphasized,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final bool emphasized;
  final VoidCallback onTap;
}

class _WelcomeActionGrid extends StatelessWidget {
  const _WelcomeActionGrid({required this.actions});

  final List<_WelcomeAction> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              Expanded(child: _WelcomeActionButton(action: actions[index])),
              if (index != actions.length - 1)
                const SizedBox(
                  height: 48,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeActionButton extends StatelessWidget {
  const _WelcomeActionButton({required this.action});

  final _WelcomeAction action;

  @override
  Widget build(BuildContext context) {
    final iconBackgroundColor = action.emphasized
        ? AppColors.goldDeep
        : action.accentColor.withValues(alpha: 0.1);
    final iconColor = action.emphasized ? Colors.white : action.accentColor;

    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              action.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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

class _ClockStatusChip extends StatefulWidget {
  const _ClockStatusChip();

  @override
  State<_ClockStatusChip> createState() => _ClockStatusChipState();
}

class _ClockStatusChipState extends State<_ClockStatusChip> {
  final DateFormat _dateFormatter = DateFormat('EEEE, d MMM yyyy', 'id_ID');
  final DateFormat _timeFormatter = DateFormat('HH:mm:ss', 'id_ID');
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.goldSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: AppColors.goldDeep,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_dateFormatter.format(_now)} • ${_timeFormatter.format(_now)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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

String _formatHomeShortDate(DateTime date) {
  return DateFormat('d MMM yyyy', 'id_ID').format(date);
}

String _formatHomeDateRange(DateTime start, DateTime end) {
  if (_dateOnly(start) == _dateOnly(end)) {
    return _formatHomeShortDate(start);
  }

  if (start.year == end.year && start.month == end.month) {
    return '${DateFormat('d', 'id_ID').format(start)}-${DateFormat('d MMM yyyy', 'id_ID').format(end)}';
  }

  return '${DateFormat('d MMM', 'id_ID').format(start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(end)}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
