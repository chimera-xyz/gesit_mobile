import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/feed_models.dart';
import '../theme/app_theme.dart';
import 'brand_widgets.dart';

class FeedComposerDraft {
  const FeedComposerDraft({
    required this.content,
    required this.visibility,
    this.recipientUserIds = const <String>[],
  });

  final String content;
  final FeedVisibility visibility;
  final List<String> recipientUserIds;
}

Future<FeedComposerDraft?> showFeedComposerSheet(
  BuildContext context, {
  required String userDivisionLabel,
  List<FeedAudienceMember> audienceMembers = const <FeedAudienceMember>[],
}) {
  return showModalBottomSheet<FeedComposerDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FeedComposerSheet(
      userDivisionLabel: userDivisionLabel,
      audienceMembers: audienceMembers,
    ),
  );
}

Future<Set<String>?> showFeedAudienceSelectionSheet(
  BuildContext context, {
  required List<FeedAudienceMember> audienceMembers,
  Set<String> initialSelectedIds = const <String>{},
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FeedAudienceSelectionSheet(
      audienceMembers: audienceMembers,
      initialSelectedIds: initialSelectedIds,
    ),
  );
}

Future<FeedAudienceMember?> showFeedMentionPickerSheet(
  BuildContext context, {
  required List<FeedAudienceMember> audienceMembers,
}) {
  return showModalBottomSheet<FeedAudienceMember>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _FeedMentionPickerSheet(audienceMembers: audienceMembers),
  );
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.onOpenThread,
    required this.onToggleLike,
    this.onDelete,
    this.likeBusy = false,
    this.compact = false,
  });

  final FeedPost post;
  final VoidCallback onOpenThread;
  final VoidCallback onToggleLike;
  final VoidCallback? onDelete;
  final bool likeBusy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authorSubtitle = [
      post.author.primaryRole,
      if (post.author.department?.trim().isNotEmpty == true)
        post.author.department!.trim(),
    ].join(' • ');

    return BrandSurface(
      padding: const EdgeInsets.all(18),
      onTap: onOpenThread,
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeedAvatar(initials: post.author.initials, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.author.name, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      authorSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatFeedRelativeTime(
                      post.lastActivityAt ?? post.createdAt,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusChip(
                    label: post.visibilityLabel,
                    color: _visibilityColor(post.visibility),
                    icon: _visibilityIcon(post.visibility),
                  ),
                ],
              ),
              if (post.canDelete && onDelete != null) ...[
                const SizedBox(width: 4),
                PopupMenuButton<_FeedMenuAction>(
                  tooltip: 'Aksi postingan',
                  color: AppColors.surface,
                  icon: const Icon(Icons.more_horiz_rounded),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _FeedMenuAction.delete,
                      child: Text('Hapus'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == _FeedMenuAction.delete) {
                      onDelete!();
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.content,
            maxLines: compact ? 5 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _FeedActionButton(
                  icon: post.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likesCount}',
                  accentColor: post.likedByMe
                      ? AppColors.red
                      : AppColors.inkSoft,
                  busy: likeBusy,
                  onTap: onToggleLike,
                ),
                const SizedBox(width: 10),
                _FeedActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentsCount}',
                  accentColor: AppColors.blue,
                  onTap: onOpenThread,
                ),
                const Spacer(),
                Text(
                  formatFeedAbsoluteTime(post.createdAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedCommentCard extends StatelessWidget {
  const FeedCommentCard({
    super.key,
    required this.comment,
    required this.onReply,
    required this.onToggleLike,
    this.onDelete,
    this.likeBusy = false,
    this.deleteBusy = false,
    this.depth = 0,
  });

  final FeedComment comment;
  final VoidCallback onReply;
  final VoidCallback onToggleLike;
  final VoidCallback? onDelete;
  final bool likeBusy;
  final bool deleteBusy;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = depth == 0 ? AppColors.goldDeep : AppColors.blue;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: AppColors.ink,
      height: 1.5,
    );
    final replyPrefix = comment.replyToUser == null
        ? null
        : '@${comment.replyToUser!.name} ';

    return Container(
      margin: EdgeInsets.only(left: depth == 0 ? 0 : 18, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeedAvatar(initials: comment.author.initials, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.author.name, style: textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      [
                        comment.author.primaryRole,
                        formatFeedRelativeTime(comment.createdAt),
                      ].join(' • '),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (comment.canDelete && onDelete != null)
                PopupMenuButton<_FeedMenuAction>(
                  tooltip: 'Aksi komentar',
                  enabled: !deleteBusy,
                  color: AppColors.surface,
                  icon: deleteBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_horiz_rounded),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _FeedMenuAction.delete,
                      child: Text('Hapus'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == _FeedMenuAction.delete) {
                      onDelete!();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: bodyStyle,
              children: [
                if (replyPrefix != null)
                  TextSpan(
                    text: replyPrefix,
                    style: bodyStyle?.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                TextSpan(text: comment.content),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeedInlineAction(
                icon: comment.likedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${comment.likesCount}',
                color: comment.likedByMe ? AppColors.red : accent,
                busy: likeBusy,
                onTap: onToggleLike,
              ),
              _FeedInlineAction(
                icon: Icons.reply_rounded,
                label: 'Balas',
                color: AppColors.blue,
                onTap: onReply,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedComposerSheet extends StatefulWidget {
  const _FeedComposerSheet({
    required this.userDivisionLabel,
    required this.audienceMembers,
  });

  final String userDivisionLabel;
  final List<FeedAudienceMember> audienceMembers;

  @override
  State<_FeedComposerSheet> createState() => _FeedComposerSheetState();
}

class _FeedComposerSheetState extends State<_FeedComposerSheet> {
  late final TextEditingController _controller;
  FeedVisibility _visibility = FeedVisibility.publicScope;
  final Set<String> _selectedAudienceUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleDraftChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _controller.text.trim().isNotEmpty &&
        (_visibility != FeedVisibility.selectedUsers ||
            _selectedAudienceUserIds.isNotEmpty);
    final selectedAudienceMembers = widget.audienceMembers
        .where((member) => _selectedAudienceUserIds.contains(member.id))
        .toList(growable: false);

    return _KeyboardAwareSheetFrame(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tulis update',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _audienceDescription(
              _visibility,
              userDivisionLabel: widget.userDivisionLabel,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          SegmentedButton<FeedVisibility>(
            segments: [
              const ButtonSegment(
                value: FeedVisibility.publicScope,
                icon: Icon(Icons.public_rounded),
                label: Text('Semua'),
              ),
              ButtonSegment(
                value: FeedVisibility.department,
                icon: const Icon(Icons.groups_rounded),
                label: Text(
                  widget.userDivisionLabel.trim().isEmpty ? 'Divisi' : 'Divisi',
                ),
              ),
              const ButtonSegment(
                value: FeedVisibility.selectedUsers,
                icon: Icon(Icons.alternate_email_rounded),
                label: Text('Tertentu'),
              ),
              const ButtonSegment(
                value: FeedVisibility.privateScope,
                icon: Icon(Icons.lock_rounded),
                label: Text('Private'),
              ),
            ],
            selected: <FeedVisibility>{_visibility},
            onSelectionChanged: (selection) {
              setState(() {
                _visibility = selection.first;
              });
            },
          ),
          if (_visibility == FeedVisibility.selectedUsers) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Penerima thread',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.audienceMembers.isEmpty
                            ? null
                            : () async {
                                final nextSelection =
                                    await showFeedAudienceSelectionSheet(
                                      context,
                                      audienceMembers: widget.audienceMembers,
                                      initialSelectedIds:
                                          _selectedAudienceUserIds,
                                    );
                                if (!mounted || nextSelection == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedAudienceUserIds
                                    ..clear()
                                    ..addAll(nextSelection);
                                });
                              },
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Pilih'),
                      ),
                    ],
                  ),
                  if (selectedAudienceMembers.isEmpty)
                    Text(
                      widget.audienceMembers.isEmpty
                          ? 'Daftar user belum tersedia untuk dipilih.'
                          : 'Pilih user yang boleh melihat thread ini.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedAudienceMembers
                          .map(
                            (member) => InputChip(
                              label: Text(member.name),
                              onDeleted: () {
                                setState(() {
                                  _selectedAudienceUserIds.remove(member.id);
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            maxLines: 7,
            minLines: 5,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Jangan lupa besok ada MCU, prepare semua ya...',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canSubmit
                      ? () {
                          final content = _controller.text.trim();
                          if (content.isEmpty) {
                            return;
                          }

                          Navigator.of(context).pop(
                            FeedComposerDraft(
                              content: content,
                              visibility: _visibility,
                              recipientUserIds: _selectedAudienceUserIds.toList(
                                growable: false,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Posting'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyboardAwareSheetFrame extends StatelessWidget {
  const _KeyboardAwareSheetFrame({
    required this.child,
    required this.padding,
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.top - bottomInset - 16;
    final sheetMaxHeight = availableHeight <= 0
        ? 0.0
        : availableHeight > 720
        ? 720.0
        : availableHeight;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: sheetMaxHeight),
            child: BrandSurface(
              radius: radius,
              backgroundColor: AppColors.surface,
              padding: padding,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedAudienceSelectionSheet extends StatefulWidget {
  const _FeedAudienceSelectionSheet({
    required this.audienceMembers,
    required this.initialSelectedIds,
  });

  final List<FeedAudienceMember> audienceMembers;
  final Set<String> initialSelectedIds;

  @override
  State<_FeedAudienceSelectionSheet> createState() =>
      _FeedAudienceSelectionSheetState();
}

class _FeedAudienceSelectionSheetState
    extends State<_FeedAudienceSelectionSheet> {
  late final TextEditingController _searchController;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _KeyboardAwareSheetFrame(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pilih audience',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Cari nama atau divisi',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 320,
            child: Builder(
              builder: (context) {
                final query = _searchController.text.trim().toLowerCase();
                final filteredMembers = widget.audienceMembers
                    .where((member) {
                      if (query.isEmpty) {
                        return true;
                      }

                      return member.name.toLowerCase().contains(query) ||
                          (member.department?.toLowerCase().contains(query) ??
                              false) ||
                          member.primaryRole.toLowerCase().contains(query);
                    })
                    .toList(growable: false);

                if (filteredMembers.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('User tidak ditemukan.'),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return CheckboxListTile(
                      value: _selectedIds.contains(member.id),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedIds.add(member.id);
                          } else {
                            _selectedIds.remove(member.id);
                          }
                        });
                      },
                      title: Text(member.name),
                      subtitle: Text(
                        [
                          member.primaryRole,
                          if (member.department?.trim().isNotEmpty == true)
                            member.department!.trim(),
                        ].join(' • '),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(Set<String>.from(_selectedIds)),
                  child: Text('Simpan (${_selectedIds.length})'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedMentionPickerSheet extends StatefulWidget {
  const _FeedMentionPickerSheet({required this.audienceMembers});

  final List<FeedAudienceMember> audienceMembers;

  @override
  State<_FeedMentionPickerSheet> createState() =>
      _FeedMentionPickerSheetState();
}

class _FeedMentionPickerSheetState extends State<_FeedMentionPickerSheet> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _KeyboardAwareSheetFrame(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Cari user untuk mention',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 320,
            child: Builder(
              builder: (context) {
                final query = _searchController.text.trim().toLowerCase();
                final filteredMembers = widget.audienceMembers
                    .where((member) {
                      if (query.isEmpty) {
                        return true;
                      }

                      return member.name.toLowerCase().contains(query) ||
                          (member.department?.toLowerCase().contains(query) ??
                              false) ||
                          member.primaryRole.toLowerCase().contains(query);
                    })
                    .toList(growable: false);

                if (filteredMembers.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('User tidak ditemukan.'),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredMembers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceAlt,
                        child: Text(
                          member.initials,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(member.name),
                      subtitle: Text(
                        [
                          member.primaryRole,
                          if (member.department?.trim().isNotEmpty == true)
                            member.department!.trim(),
                        ].join(' • '),
                      ),
                      onTap: () => Navigator.of(context).pop(member),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                )
              else
                Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedInlineAction extends StatelessWidget {
  const _FeedInlineAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedAvatar extends StatelessWidget {
  const _FeedAvatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldDeep, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}

enum _FeedMenuAction { delete }

Color _visibilityColor(FeedVisibility visibility) {
  switch (visibility) {
    case FeedVisibility.department:
      return AppColors.blue;
    case FeedVisibility.selectedUsers:
      return AppColors.inkSoft;
    case FeedVisibility.privateScope:
      return AppColors.red;
    case FeedVisibility.publicScope:
      return AppColors.goldDeep;
  }
}

IconData _visibilityIcon(FeedVisibility visibility) {
  switch (visibility) {
    case FeedVisibility.department:
      return Icons.groups_rounded;
    case FeedVisibility.selectedUsers:
      return Icons.alternate_email_rounded;
    case FeedVisibility.privateScope:
      return Icons.lock_rounded;
    case FeedVisibility.publicScope:
      return Icons.public_rounded;
  }
}

String _audienceDescription(
  FeedVisibility visibility, {
  required String userDivisionLabel,
}) {
  switch (visibility) {
    case FeedVisibility.department:
      final division = userDivisionLabel.trim();
      return division.isEmpty
          ? 'Update ini hanya akan dilihat oleh divisi Anda.'
          : 'Update ini hanya akan dilihat oleh divisi $division.';
    case FeedVisibility.selectedUsers:
      return 'Update ini hanya akan dikirim ke user yang Anda pilih.';
    case FeedVisibility.privateScope:
      return 'Update ini hanya akan dilihat oleh Anda sendiri.';
    case FeedVisibility.publicScope:
      return 'Update ini akan muncul untuk seluruh user aktif.';
  }
}

String formatFeedRelativeTime(DateTime createdAt) {
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

String formatFeedAbsoluteTime(DateTime createdAt) {
  return DateFormat('d MMM yyyy • HH:mm', 'id_ID').format(createdAt);
}
