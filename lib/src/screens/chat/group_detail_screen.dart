import 'package:flutter/material.dart';

import '../../data/demo_data.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.conversation});

  final ConversationPreview conversation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final members = DemoData.membersFor(conversation.id);
    final pinnedAssets = const [
      ('workflow-approval-v2.pdf', 'PDF'),
      ('budget-forecast-april.xlsx', 'Sheet'),
      ('branch-network-snapshot.png', 'Image'),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RevealUp(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface.withValues(
                            alpha: 0.9,
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Group Info',
                          style: textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                RevealUp(
                  index: 1,
                  child: BrandSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConversationAvatar(
                          label: conversation.title,
                          accentColor: conversation.accentColor,
                          isGroup: true,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          conversation.title,
                          style: textTheme.displayMedium?.copyWith(
                            fontSize: 30,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ruang koordinasi cepat untuk kebutuhan operasional internal. Thread dibuat supaya keputusan dan update teknis tetap rapi.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            StatusChip(
                              label: conversation.subtitle,
                              color: conversation.accentColor,
                            ),
                            const StatusChip(
                              label: 'Pinned room',
                              color: AppColors.goldDeep,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const SectionHeader(
                  eyebrow: 'Quick Actions',
                  title: 'Kelola room',
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Expanded(
                      child: _GroupActionTile(
                        icon: Icons.notifications_off_rounded,
                        label: 'Mute',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _GroupActionTile(
                        icon: Icons.folder_copy_rounded,
                        label: 'Files',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _GroupActionTile(
                        icon: Icons.push_pin_rounded,
                        label: 'Pinned',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _GroupActionTile(
                        icon: Icons.call_rounded,
                        label: 'Call',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionHeader(
                  eyebrow: 'Pinned Assets',
                  title: 'Dokumen yang sering dirujuk',
                ),
                const SizedBox(height: 14),
                ...pinnedAssets.map(
                  (asset) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BrandSurface(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: conversation.accentColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.insert_drive_file_rounded,
                              color: conversation.accentColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(asset.$1, style: textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  asset.$2,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.goldDeep,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const SectionHeader(eyebrow: 'Members', title: 'Anggota grup'),
                const SizedBox(height: 14),
                ...members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BrandSurface(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ConversationAvatar(
                            label: member.name,
                            accentColor: member.accentColor,
                            showOnlineDot: member.active,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.name, style: textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(member.role, style: textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          StatusChip(
                            label: member.active ? 'Active' : 'Away',
                            color: member.active
                                ? AppColors.emerald
                                : AppColors.inkMuted,
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

class _GroupActionTile extends StatelessWidget {
  const _GroupActionTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: AppColors.goldDeep),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
