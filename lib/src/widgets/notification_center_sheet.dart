import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/notification_center_controller.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class NotificationCenterSheet extends StatelessWidget {
  const NotificationCenterSheet({super.key, required this.controller});

  final NotificationCenterController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final notifications = controller.notifications;
        final unreadCount = controller.unreadCount;

        return FractionallySizedBox(
          heightFactor: 0.86,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notifikasi',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontSize: 28),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    unreadCount > 0
                                        ? '$unreadCount belum dibaca'
                                        : 'Semua notifikasi sudah dibaca',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surfaceAlt,
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        if (unreadCount > 0 || notifications.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (unreadCount > 0)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.goldDeep,
                                  ),
                                  onPressed: controller.markAllAsRead,
                                  child: const Text('Tandai baca semua'),
                                ),
                              const Spacer(),
                              if (notifications.isNotEmpty)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.red,
                                  ),
                                  onPressed: () async {
                                    final confirmed =
                                        await _confirmDeleteAllNotifications(
                                          context,
                                        );
                                    if (confirmed) {
                                      controller.deleteAllNotifications();
                                    }
                                  },
                                  child: const Text('Hapus semua'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: notifications.isEmpty
                        ? const _NotificationEmptyState()
                        : ListView.separated(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            itemCount: notifications.length,
                            separatorBuilder: (context, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final notification = notifications[index];

                              return _NotificationRow(
                                key: ValueKey(notification.id),
                                notification: notification,
                                onTap: () =>
                                    Navigator.of(context).pop(notification),
                                onDelete: () {
                                  controller.deleteNotification(
                                    notification.id,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<bool> _confirmDeleteAllNotifications(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final textTheme = Theme.of(dialogContext).textTheme;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'Hapus semua?',
              style: textTheme.titleLarge?.copyWith(color: AppColors.ink),
            ),
            content: Text(
              'Semua notifikasi akan dihapus.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceAlt,
                  foregroundColor: AppColors.ink,
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Hapus'),
              ),
            ],
          );
        },
      ) ??
      false;
}

class NotificationDetailSheet extends StatelessWidget {
  const NotificationDetailSheet({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final accentColor = notificationAccentColor(notification.type);
    final textTheme = Theme.of(context).textTheme;
    final hasPrimaryAction =
        notification.destination != NotificationDestination.none &&
        notification.primaryActionLabel != null;

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    notificationIcon(notification.type),
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      label: notificationTypeLabel(notification.type),
                      color: accentColor,
                    ),
                    _MetaChip(
                      label: formatNotificationDateTime(notification.createdAt),
                      color: AppColors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  notification.title,
                  style: textTheme.headlineMedium?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Text(
                      notification.detail,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (hasPrimaryAction)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Tutup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(notification.primaryActionLabel!),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Tutup'),
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

class NotificationHeadsUpBanner extends StatelessWidget {
  const NotificationHeadsUpBanner({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final accentColor = notificationAccentColor(notification.type);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12291C09),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    notificationIcon(notification.type),
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 34,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 18),
            Text('Belum ada notifikasi', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Aktivitas terbaru akan muncul di sini.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatefulWidget {
  const _NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> {
  double _revealExtent = 0;
  bool _isDragging = false;

  void _handleHorizontalDragStart(DragStartDetails details) {
    if (_isDragging) {
      return;
    }

    setState(() => _isDragging = true);
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final nextExtent = (_revealExtent - delta).clamp(
      0.0,
      _kNotificationActionExtent,
    );

    if (nextExtent == _revealExtent) {
      return;
    }

    setState(() => _revealExtent = nextExtent);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDelete =
        _revealExtent > (_kNotificationActionExtent * 0.88) || velocity < -1100;
    final shouldOpen =
        velocity < -220 ||
        (velocity <= 0 && _revealExtent > (_kNotificationActionExtent * 0.42));

    if (shouldDelete) {
      widget.onDelete();
      return;
    }

    setState(() {
      _isDragging = false;
      _revealExtent = shouldOpen ? _kNotificationActionExtent : 0;
    });
  }

  void _handleHorizontalDragCancel() {
    if (!_isDragging) {
      return;
    }

    setState(() {
      _isDragging = false;
      _revealExtent = _revealExtent > (_kNotificationActionExtent * 0.42)
          ? _kNotificationActionExtent
          : 0;
    });
  }

  void _handleCardTap() {
    if (_revealExtent > 0) {
      setState(() => _revealExtent = 0);
      return;
    }

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final accentColor = notificationAccentColor(notification.type);
    final borderRadius = BorderRadius.circular(_kNotificationRowRadius);
    final cardBackgroundColor = notification.isRead
        ? AppColors.surface
        : Color.alphaBlend(
            AppColors.goldSoft.withValues(alpha: 0.58),
            AppColors.surface,
          );

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: borderRadius,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _kNotificationActionExtent,
                  child: _SwipeDeleteAction(onDelete: widget.onDelete),
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _revealExtent),
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, revealExtent, child) {
                return Transform.translate(
                  offset: Offset(-revealExtent, 0),
                  child: child,
                );
              },
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _handleHorizontalDragStart,
                  onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  onHorizontalDragCancel: _handleHorizontalDragCancel,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: borderRadius,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _handleCardTap,
                      borderRadius: borderRadius,
                      child: Ink(
                        decoration: BoxDecoration(
                          color: cardBackgroundColor,
                          borderRadius: borderRadius,
                          border: Border.all(
                            color: notification.isRead
                                ? AppColors.border
                                : AppColors.borderStrong,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  notificationIcon(notification.type),
                                  color: accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notification.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        if (!notification.isRead) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 9,
                                            height: 9,
                                            margin: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: AppColors.goldDeep,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notification.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.inkSoft),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      formatRelativeNotificationTime(
                                        notification.createdAt,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.inkMuted,
                                            fontWeight: FontWeight.w700,
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeDeleteAction extends StatelessWidget {
  const _SwipeDeleteAction({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.delete_outline_rounded, color: AppColors.red),
              SizedBox(width: 8),
              Text(
                'Hapus',
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const double _kNotificationRowRadius = 26;
const double _kNotificationActionExtent = 132;

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color notificationAccentColor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.approval:
      return AppColors.goldDeep;
    case AppNotificationType.submission:
      return AppColors.emerald;
    case AppNotificationType.helpdesk:
      return AppColors.red;
    case AppNotificationType.system:
      return AppColors.blue;
    case AppNotificationType.knowledge:
      return AppColors.emerald;
    case AppNotificationType.chat:
      return AppColors.blue;
    case AppNotificationType.call:
      return AppColors.goldDeep;
  }
}

IconData notificationIcon(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.approval:
      return Icons.fact_check_rounded;
    case AppNotificationType.submission:
      return Icons.inventory_2_rounded;
    case AppNotificationType.helpdesk:
      return Icons.support_agent_rounded;
    case AppNotificationType.system:
      return Icons.settings_rounded;
    case AppNotificationType.knowledge:
      return Icons.auto_stories_rounded;
    case AppNotificationType.chat:
      return Icons.forum_rounded;
    case AppNotificationType.call:
      return Icons.call_rounded;
  }
}

String notificationTypeLabel(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.approval:
      return 'Approval';
    case AppNotificationType.submission:
      return 'Aktivitas Baru';
    case AppNotificationType.helpdesk:
      return 'Helpdesk';
    case AppNotificationType.system:
      return 'System';
    case AppNotificationType.knowledge:
      return 'Knowledge';
    case AppNotificationType.chat:
      return 'Chat';
    case AppNotificationType.call:
      return 'Panggilan';
  }
}

String formatRelativeNotificationTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt);

  if (difference.inMinutes < 1) {
    return 'Baru saja';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} menit lalu';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} jam lalu';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} hari lalu';
  }

  return DateFormat('d MMM yyyy', 'id_ID').format(createdAt);
}

String formatNotificationDateTime(DateTime createdAt) {
  return DateFormat('d MMM yyyy • HH:mm', 'id_ID').format(createdAt);
}
