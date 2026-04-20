import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userInitials,
    required this.userRoleLabel,
    required this.userDivisionLabel,
    required this.canOpenTasks,
    required this.canOpenKnowledgeHub,
    required this.canOpenHelpdesk,
    required this.onOpenTasks,
    required this.onOpenKnowledgeHub,
    required this.onOpenHelpdesk,
    required this.onLogout,
  });

  final String userName;
  final String userInitials;
  final String userRoleLabel;
  final String userDivisionLabel;
  final bool canOpenTasks;
  final bool canOpenKnowledgeHub;
  final bool canOpenHelpdesk;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenKnowledgeHub;
  final VoidCallback onOpenHelpdesk;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profileShortcuts = DemoData.profileShortcuts
        .where((item) {
          return switch (item.title) {
            'Approval Inbox' => canOpenTasks,
            'Knowledge Hub' => canOpenKnowledgeHub,
            'IT Helpdesk' => canOpenHelpdesk,
            _ => true,
          };
        })
        .toList(growable: false);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomBarInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealUp(
            child: BrandSurface(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.goldDeep, AppColors.gold],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          userInitials,
                          style: textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(userRoleLabel, style: textTheme.bodyMedium),
                            const SizedBox(height: 2),
                            Text(
                              userDivisionLabel,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      StatusChip(label: '2FA Active', color: AppColors.emerald),
                      StatusChip(
                        label: 'Managed Device',
                        color: AppColors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(eyebrow: 'Menu', title: 'Account'),
          const SizedBox(height: 14),
          ...profileShortcuts.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RevealUp(
                index: index + 1,
                child: BrandSurface(
                  onTap: () => _handleShortcutTap(context, item),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: item.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(item.icon, color: item.accentColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.title, style: textTheme.titleMedium),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              if (canOpenHelpdesk)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenHelpdesk,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Helpdesk'),
                  ),
                ),
              if (canOpenHelpdesk) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleShortcutTap(BuildContext context, ProfileShortcut item) {
    switch (item.title) {
      case 'Approval Inbox':
        onOpenTasks();
        break;
      case 'Knowledge Hub':
        onOpenKnowledgeHub();
        break;
      case 'IT Helpdesk':
        onOpenHelpdesk();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('UI shortcut ini siap untuk tahap berikutnya.'),
          ),
        );
    }
  }
}
