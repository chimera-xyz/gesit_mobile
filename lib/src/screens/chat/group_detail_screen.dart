import 'package:flutter/material.dart';

import '../../data/chat_workspace_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({
    super.key,
    required this.controller,
    required this.conversationId,
    this.onStartVoiceCall,
    this.onStartVideoCall,
  });

  final ChatWorkspaceController controller;
  final String conversationId;
  final VoidCallback? onStartVoiceCall;
  final VoidCallback? onStartVideoCall;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final conversation = controller.conversationById(conversationId);
        if (conversation == null) {
          return const SizedBox.shrink();
        }

        final textTheme = Theme.of(context).textTheme;
        final members = controller.membersFor(conversationId);
        final sharedAssets = controller.assetsFor(conversationId);

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
                              'Ruang koordinasi cepat untuk operasional internal. Semua update, file kerja, voice note, dan call grup stay di satu thread.',
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
                                  label: '${members.length} anggota',
                                  color: conversation.accentColor,
                                  icon: Icons.groups_rounded,
                                ),
                                if (conversation.isPinned)
                                  const StatusChip(
                                    label: 'Pinned',
                                    color: AppColors.goldDeep,
                                    icon: Icons.push_pin_rounded,
                                  ),
                                if (conversation.isMuted)
                                  const StatusChip(
                                    label: 'Muted',
                                    color: AppColors.inkMuted,
                                    icon: Icons.volume_off_rounded,
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
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 106,
                          child: _GroupActionTile(
                            icon: conversation.isMuted
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            label: conversation.isMuted ? 'Unmute' : 'Mute',
                            onTap: () => controller.toggleMuted(conversationId),
                          ),
                        ),
                        SizedBox(
                          width: 106,
                          child: _GroupActionTile(
                            icon: conversation.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            label: conversation.isPinned ? 'Unpin' : 'Pin',
                            onTap: () =>
                                controller.togglePinned(conversationId),
                          ),
                        ),
                        SizedBox(
                          width: 106,
                          child: _GroupActionTile(
                            icon: Icons.call_rounded,
                            label: 'Call',
                            onTap: onStartVoiceCall ?? () {},
                          ),
                        ),
                        SizedBox(
                          width: 106,
                          child: _GroupActionTile(
                            icon: Icons.videocam_rounded,
                            label: 'Video',
                            onTap: onStartVideoCall ?? () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const SectionHeader(
                      eyebrow: 'Shared Files',
                      title: 'Dokumen yang sering dirujuk',
                    ),
                    const SizedBox(height: 14),
                    if (sharedAssets.isEmpty)
                      const BrandSurface(
                        padding: EdgeInsets.all(16),
                        child: Text('Belum ada file yang dibagikan.'),
                      ),
                    ...sharedAssets
                        .take(6)
                        .map(
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
                                      color: asset.accentColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.insert_drive_file_rounded,
                                      color: asset.accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          asset.label,
                                          style: textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${asset.typeLabel} • ${asset.sizeLabel}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.inkMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          asset.uploadedBy,
                                          style: textTheme.labelSmall?.copyWith(
                                            color: AppColors.inkSoft,
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
                    const SectionHeader(
                      eyebrow: 'Members',
                      title: 'Anggota grup',
                    ),
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
                                    Text(
                                      member.isCurrentUser
                                          ? '${member.name} (You)'
                                          : member.name,
                                      style: textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member.role,
                                      style: textTheme.bodyMedium,
                                    ),
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
      },
    );
  }
}

class _GroupActionTile extends StatelessWidget {
  const _GroupActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      onTap: onTap,
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
