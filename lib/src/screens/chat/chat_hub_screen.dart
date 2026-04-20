import 'package:flutter/material.dart';

import '../../data/chat_workspace_controller.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({
    super.key,
    required this.controller,
    required this.onOpenConversation,
  });

  final ChatWorkspaceController controller;
  final ValueChanged<ConversationPreview> onOpenConversation;

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final query = _searchController.text.trim().toLowerCase();
        final allConversations = widget.controller.conversations;
        final pinned = allConversations
            .where((conversation) => conversation.isPinned)
            .toList(growable: false);
        final filtered = allConversations
            .where((conversation) {
              final matchesFilter = switch (_selectedFilter) {
                'Belum Dibaca' => conversation.unreadCount > 0,
                'Grup' => conversation.isGroup,
                _ => true,
              };
              final matchesQuery =
                  query.isEmpty ||
                  conversation.title.toLowerCase().contains(query) ||
                  conversation.preview.toLowerCase().contains(query);
              return matchesFilter && matchesQuery;
            })
            .toList(growable: false);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomBarInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RevealUp(child: Text('Chat', style: textTheme.headlineMedium)),
              const SizedBox(height: 14),
              AppSearchField(
                controller: _searchController,
                hintText: 'Cari percakapan',
                onChanged: (_) => setState(() {}),
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppColors.goldDeep.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilterPill(
                    label: 'Semua',
                    selected: _selectedFilter == 'Semua',
                    onTap: () => setState(() => _selectedFilter = 'Semua'),
                  ),
                  FilterPill(
                    label: 'Belum Dibaca',
                    selected: _selectedFilter == 'Belum Dibaca',
                    onTap: () =>
                        setState(() => _selectedFilter = 'Belum Dibaca'),
                  ),
                  FilterPill(
                    label: 'Grup',
                    selected: _selectedFilter == 'Grup',
                    onTap: () => setState(() => _selectedFilter = 'Grup'),
                  ),
                ],
              ),
              if (pinned.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Pinned',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 144,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: pinned.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final conversation = pinned[index];
                      return SizedBox(
                        width: 210,
                        child: RevealUp(
                          index: index + 1,
                          child: BrandSurface(
                            onTap: () =>
                                widget.onOpenConversation(conversation),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ConversationAvatar(
                                      label: conversation.title,
                                      accentColor: conversation.accentColor,
                                      isGroup: conversation.isGroup,
                                    ),
                                    const Spacer(),
                                    if (conversation.isMuted)
                                      const Icon(
                                        Icons.volume_off_rounded,
                                        size: 18,
                                        color: AppColors.inkMuted,
                                      ),
                                    if (conversation.unreadCount > 0) ...[
                                      const SizedBox(width: 8),
                                      StatusChip(
                                        label: '${conversation.unreadCount}',
                                        color: conversation.accentColor,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  conversation.title,
                                  style: textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  conversation.subtitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkSoft,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Conversations',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                BrandSurface(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    allConversations.isEmpty &&
                            query.isEmpty &&
                            _selectedFilter == 'Semua'
                        ? 'Belum ada percakapan chat dari server.'
                        : 'Tidak ada percakapan yang cocok.',
                  ),
                ),
              for (var index = 0; index < filtered.length; index++) ...[
                RevealUp(
                  index: index + 3,
                  child: BrandSurface(
                    onTap: () => widget.onOpenConversation(filtered[index]),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConversationAvatar(
                          label: filtered[index].title,
                          accentColor: filtered[index].accentColor,
                          isGroup: filtered[index].isGroup,
                          showOnlineDot: filtered[index].isOnline,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      filtered[index].title,
                                      style: textTheme.titleMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    filtered[index].timestamp,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                filtered[index].preview,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: filtered[index].isTyping
                                      ? AppColors.emerald
                                      : AppColors.inkSoft,
                                  fontWeight: filtered[index].isTyping
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            if (filtered[index].isMuted)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: Icon(
                                  Icons.volume_off_rounded,
                                  color: AppColors.inkMuted,
                                  size: 18,
                                ),
                              ),
                            if (filtered[index].unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: filtered[index].accentColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${filtered[index].unreadCount}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (index != filtered.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}
