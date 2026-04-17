import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenTasks,
    required this.onOpenForms,
    required this.onOpenAiAssist,
    required this.onOpenChat,
    required this.onOpenHelpdesk,
    required this.onOpenSubmission,
  });

  final VoidCallback onOpenTasks;
  final VoidCallback onOpenForms;
  final VoidCallback onOpenAiAssist;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenHelpdesk;
  final ValueChanged<TaskItem> onOpenSubmission;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final approvalItems = DemoData.tasks
        .where((task) => task.lane == TaskLane.approvals)
        .take(2)
        .toList();
    final pendingApprovalCount = DemoData.tasks
        .where((task) => task.lane == TaskLane.approvals)
        .length;
    final today = DateFormat(
      'EEEE, d MMM yyyy',
      'id_ID',
    ).format(DateTime.now());

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
                        label: today,
                        color: AppColors.goldDeep,
                        icon: Icons.calendar_today_rounded,
                      ),
                      StatusChip(
                        label: '$pendingApprovalCount review',
                        color: AppColors.blue,
                        icon: Icons.fact_check_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onOpenTasks,
                          icon: const Icon(Icons.fact_check_rounded),
                          label: const Text('Tasks'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenAiAssist,
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
          SectionHeader(
            eyebrow: 'Approval',
            title: 'Need review',
            trailing: TextButton(
              onPressed: onOpenTasks,
              child: const Text('Lihat semua'),
            ),
          ),
          const SizedBox(height: 14),
          RevealUp(
            index: 2,
            child: BrandSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < approvalItems.length;
                    index++
                  ) ...[
                    _ApprovalInboxRow(
                      item: approvalItems[index],
                      onTap: () => onOpenSubmission(approvalItems[index]),
                    ),
                    if (index != approvalItems.length - 1)
                      const Divider(height: 1),
                  ],
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
                  title: 'Forms',
                  value: '16',
                  subtitle: 'Aktif',
                  icon: Icons.description_rounded,
                  accentColor: AppColors.goldDeep,
                  onTap: onOpenForms,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactStatusCard(
                  title: 'Helpdesk',
                  value: '4',
                  subtitle: 'Open',
                  icon: Icons.support_agent_rounded,
                  accentColor: AppColors.red,
                  onTap: onOpenHelpdesk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactStatusCard(
                  title: 'Chat',
                  value: '27',
                  subtitle: 'Unread',
                  icon: Icons.mark_chat_unread_rounded,
                  accentColor: AppColors.emerald,
                  onTap: onOpenChat,
                ),
              ),
            ],
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
    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(height: 18),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _ApprovalInboxRow extends StatelessWidget {
  const _ApprovalInboxRow({required this.item, required this.onTap});

  final TaskItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(label: item.statusLabel, color: item.accentColor),
                  const Spacer(),
                  Text(
                    item.timeLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.requester,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (item.requiresSignature)
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.draw_rounded,
                        size: 16,
                        color: AppColors.red,
                      ),
                    ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.goldDeep,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
