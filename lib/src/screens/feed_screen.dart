import 'dart:async';

import 'package:flutter/material.dart';

import '../data/feed_controller.dart';
import '../models/feed_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/feed_widgets.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.controller,
    required this.userDivisionLabel,
    required this.onOpenThread,
  });

  final FeedController controller;
  final String userDivisionLabel;
  final ValueChanged<FeedPost> onOpenThread;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  Future<void> _openComposer() async {
    try {
      await widget.controller.ensureAudienceMembersLoaded();
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
      audienceMembers: widget.controller.audienceMembers,
    );
    if (!mounted || draft == null) {
      return;
    }

    try {
      await widget.controller.createPost(
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
      await widget.controller.togglePostLike(post.id);
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
      await widget.controller.deletePost(post.id);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _refresh() {
    return widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final posts = widget.controller.posts;
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          backgroundColor: AppColors.canvasTop,
          appBar: AppBar(
            backgroundColor: AppColors.canvasTop,
            surfaceTintColor: Colors.transparent,
            title: const Text('Feed Internal'),
            actions: [
              IconButton(
                tooltip: 'Refresh feed',
                onPressed: widget.controller.loading
                    ? null
                    : () => unawaited(_refresh()),
                icon: widget.controller.loading && posts.isNotEmpty
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Buat update',
                onPressed: widget.controller.creatingPost
                    ? null
                    : () => unawaited(_openComposer()),
                icon: widget.controller.creatingPost
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: GesitBackground(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  children: [
                    const SectionHeader(eyebrow: 'Feed', title: 'Semua Update'),
                    const SizedBox(height: 14),
                    _FeedComposerPrompt(
                      busy: widget.controller.creatingPost,
                      onTap: () => unawaited(_openComposer()),
                    ),
                    const SizedBox(height: 16),
                    if (widget.controller.loading && posts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 34),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (widget.controller.error != null && posts.isEmpty)
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
                              widget.controller.error!,
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    else if (posts.isEmpty)
                      BrandSurface(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'Belum ada update di feed.',
                          style: textTheme.bodyMedium,
                        ),
                      )
                    else ...[
                      if (widget.controller.error != null) ...[
                        _FeedInlineWarning(message: widget.controller.error!),
                        const SizedBox(height: 14),
                      ],
                      for (var index = 0; index < posts.length; index++) ...[
                        if (index > 0) const SizedBox(height: 14),
                        FeedPostCard(
                          post: posts[index],
                          compact: true,
                          onOpenThread: () => widget.onOpenThread(posts[index]),
                          onToggleLike: () =>
                              unawaited(_togglePostLike(posts[index])),
                          onDelete: posts[index].canDelete
                              ? () => unawaited(_deletePost(posts[index]))
                              : null,
                          likeBusy: widget.controller.isPostLikeBusy(
                            posts[index].id,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (widget.controller.hasMore)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.controller.loadingMore
                                ? null
                                : () => unawaited(widget.controller.loadMore()),
                            icon: widget.controller.loadingMore
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.expand_more_rounded),
                            label: const Text('Muat feed berikutnya'),
                          ),
                        ),
                    ],
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

class _FeedComposerPrompt extends StatelessWidget {
  const _FeedComposerPrompt({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_rounded, color: AppColors.goldDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tulis update internal',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedInlineWarning extends StatelessWidget {
  const _FeedInlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0C6BC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
