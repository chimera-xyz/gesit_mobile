import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenTasks,
    required this.onOpenForms,
    required this.onOpenAiAssist,
    required this.onOpenHelpdesk,
    required this.onOpenNotifications,
    required this.unreadNotificationCount,
  });

  final VoidCallback onOpenTasks;
  final VoidCallback onOpenForms;
  final VoidCallback onOpenAiAssist;
  final VoidCallback onOpenHelpdesk;
  final VoidCallback onOpenNotifications;
  final int unreadNotificationCount;

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pendingApprovalCount = DemoData.pendingApprovalCount;
    final today = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_now);
    final currentTime = DateFormat('HH:mm:ss', 'id_ID').format(_now);

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
                          'RC',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DemoData.userName.split(' ').first,
                            style: textTheme.labelLarge,
                          ),
                          Text(
                            'Internal',
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
                    'Selamat datang, ${DemoData.userName.split(' ').first}.',
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
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.onOpenTasks,
                          icon: const Icon(Icons.fact_check_rounded),
                          label: const Text('Tasks'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
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
          Row(
            children: [
              Expanded(
                child: _CompactStatusCard(
                  title: 'Form Aktif',
                  value: '${DemoData.activeFormCount}',
                  subtitle: 'Tersedia',
                  icon: Icons.description_rounded,
                  accentColor: AppColors.goldDeep,
                  onTap: widget.onOpenForms,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactStatusCard(
                  title: 'Task',
                  value: '$pendingApprovalCount',
                  subtitle: 'Pengajuan baru',
                  icon: Icons.fact_check_rounded,
                  accentColor: AppColors.blue,
                  onTap: widget.onOpenTasks,
                ),
              ),
              const SizedBox(width: 12),
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
