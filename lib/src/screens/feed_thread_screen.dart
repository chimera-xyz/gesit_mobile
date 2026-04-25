import 'dart:async';

import 'package:flutter/material.dart';

import '../data/feed_controller.dart';
import '../models/feed_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/feed_widgets.dart';

class FeedThreadScreen extends StatefulWidget {
  const FeedThreadScreen({
    super.key,
    required this.controller,
    required this.postId,
  });

  final FeedController controller;
  final String postId;

  @override
  State<FeedThreadScreen> createState() => _FeedThreadScreenState();
}

class _FeedThreadScreenState extends State<FeedThreadScreen> {
  late final TextEditingController _commentController;
  FeedComment? _replyingTo;
  final Map<String, FeedAudienceMember> _mentionedUsersById =
      <String, FeedAudienceMember>{};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    unawaited(_loadThread());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  FeedPost? get _post =>
      widget.controller.threadById(widget.postId) ??
      widget.controller.postById(widget.postId);

  Future<void> _loadThread({bool forceRefresh = false}) async {
    try {
      await widget.controller.fetchThread(
        widget.postId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = null;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = '$error';
      });
    }
  }

  Future<void> _togglePostLike() async {
    try {
      await widget.controller.togglePostLike(widget.postId);
    } on Exception catch (error) {
      _showSnackBar('$error');
    }
  }

  Future<void> _toggleCommentLike(FeedComment comment) async {
    try {
      await widget.controller.toggleCommentLike(
        postId: widget.postId,
        commentId: comment.id,
      );
    } on Exception catch (error) {
      _showSnackBar('$error');
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      return;
    }

    final normalizedContent = _normalizedCommentContent(content);
    if (normalizedContent.isEmpty) {
      _showSnackBar('Isi balasan belum diisi.');
      return;
    }

    try {
      await widget.controller.addComment(
        postId: widget.postId,
        content: normalizedContent,
        parentId: _replyingTo?.id,
        mentionedUserIds: _mentionedUserIdsForContent(content),
      );
      if (!mounted) {
        return;
      }
      _commentController.clear();
      setState(() {
        _replyingTo = null;
        _mentionedUsersById.clear();
      });
    } on Exception catch (error) {
      _showSnackBar('$error');
    }
  }

  Future<void> _confirmDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Hapus postingan?'),
        content: const Text(
          'Thread ini akan hilang untuk semua audience yang bisa melihatnya.',
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

    if (confirmed != true) {
      return;
    }

    try {
      await widget.controller.deletePost(widget.postId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on Exception catch (error) {
      _showSnackBar('$error');
    }
  }

  Future<void> _confirmDeleteComment(FeedComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Hapus komentar?'),
        content: Text(
          comment.parentId == null
              ? 'Balasan di bawah komentar ini juga akan ikut terhapus.'
              : 'Komentar ini akan dihapus dari thread.',
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

    if (confirmed != true) {
      return;
    }

    try {
      await widget.controller.deleteComment(
        postId: widget.postId,
        commentId: comment.id,
      );
      if (!mounted) {
        return;
      }
      if (_replyingTo != null &&
          _commentContainsReplyTarget(comment, _replyingTo!.id)) {
        _clearReplyTarget();
      }
    } on Exception catch (error) {
      _showSnackBar('$error');
    }
  }

  void _startReply(FeedComment comment) {
    final draft = _stripReplyMention(_commentController.text, _replyingTo);
    final nextText = '${_replyMention(comment)}${draft.trimLeft()}';

    setState(() {
      _replyingTo = comment;
    });
    _setComposerText(nextText);
  }

  void _clearReplyTarget() {
    final draft = _stripReplyMention(_commentController.text, _replyingTo);

    setState(() {
      _replyingTo = null;
    });
    _setComposerText(draft);
  }

  void _setComposerText(String value) {
    _commentController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _pickMention() async {
    try {
      await widget.controller.ensureAudienceMembersLoaded();
    } on Exception catch (error) {
      _showSnackBar('$error');
      return;
    }

    if (!mounted) {
      return;
    }

    final selectedMember = await showFeedMentionPickerSheet(
      context,
      audienceMembers: widget.controller.audienceMembers,
    );
    if (!mounted || selectedMember == null) {
      return;
    }

    final mentionToken = '@${selectedMember.name}';
    final currentText = _commentController.text;
    final nextText = currentText.trimRight().isEmpty
        ? '$mentionToken '
        : currentText.contains(mentionToken)
        ? currentText
        : '${currentText.trimRight()} $mentionToken ';

    setState(() {
      _mentionedUsersById[selectedMember.id] = selectedMember;
    });
    _setComposerText(nextText);
  }

  String _normalizedCommentContent(String value) {
    return _stripReplyMention(value, _replyingTo).trim();
  }

  List<String> _mentionedUserIdsForContent(String value) {
    final normalizedValue = value.toLowerCase();

    return _mentionedUsersById.entries
        .where(
          (entry) =>
              normalizedValue.contains('@${entry.value.name.toLowerCase()}'),
        )
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  String _stripReplyMention(String value, FeedComment? target) {
    if (target == null) {
      return value;
    }

    final mention = _replyMention(target);
    if (value.startsWith(mention)) {
      return value.substring(mention.length);
    }

    return value;
  }

  String _replyMention(FeedComment comment) => '@${comment.author.name} ';

  bool _commentContainsReplyTarget(FeedComment comment, String targetId) {
    if (comment.id == targetId) {
      return true;
    }

    for (final reply in comment.replies) {
      if (_commentContainsReplyTarget(reply, targetId)) {
        return true;
      }
    }

    return false;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _buildCommentWidgets(List<FeedComment> comments) {
    final widgets = <Widget>[];

    for (final comment in comments) {
      widgets.add(
        FeedCommentCard(
          comment: comment,
          onReply: () => _startReply(comment),
          onToggleLike: () => unawaited(_toggleCommentLike(comment)),
          onDelete: comment.canDelete
              ? () => unawaited(_confirmDeleteComment(comment))
              : null,
          likeBusy: widget.controller.isCommentLikeBusy(comment.id),
          deleteBusy: widget.controller.isDeletingComment(comment.id),
        ),
      );

      for (final reply in comment.replies) {
        widgets.add(
          FeedCommentCard(
            comment: reply,
            depth: 1,
            onReply: () => _startReply(reply),
            onToggleLike: () => unawaited(_toggleCommentLike(reply)),
            onDelete: reply.canDelete
                ? () => unawaited(_confirmDeleteComment(reply))
                : null,
            likeBusy: widget.controller.isCommentLikeBusy(reply.id),
            deleteBusy: widget.controller.isDeletingComment(reply.id),
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final post = _post;
        final isLoading = widget.controller.isThreadLoading(widget.postId);

        return Scaffold(
          backgroundColor: AppColors.canvasTop,
          appBar: AppBar(
            backgroundColor: AppColors.canvasTop,
            surfaceTintColor: Colors.transparent,
            title: const Text('Thread Feed'),
            actions: [
              IconButton(
                tooltip: 'Refresh thread',
                onPressed: isLoading
                    ? null
                    : () => unawaited(_loadThread(forceRefresh: true)),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: GesitBackground(
            child: SafeArea(
              top: false,
              child: post == null && isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      children: [
                        if (_loadError != null && post == null)
                          BrandSurface(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Thread belum bisa dimuat',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _loadError!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        if (post != null) ...[
                          FeedPostCard(
                            post: post,
                            compact: false,
                            onOpenThread: () {},
                            onToggleLike: () => unawaited(_togglePostLike()),
                            onDelete: post.canDelete
                                ? () => unawaited(_confirmDeletePost())
                                : null,
                            likeBusy: widget.controller.isPostLikeBusy(post.id),
                          ),
                          const SizedBox(height: 22),
                          const SectionHeader(
                            eyebrow: 'Komentar',
                            title: 'Percakapan Thread',
                          ),
                          const SizedBox(height: 14),
                          if (post.comments.isEmpty)
                            BrandSurface(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                'Belum ada komentar di thread ini.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          else
                            ..._buildCommentWidgets(post.comments),
                        ],
                      ],
                    ),
            ),
          ),
          bottomNavigationBar: ColoredBox(
            color: AppColors.canvasTop,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: BrandSurface(
                  radius: 24,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Membalas ${_replyingTo!.author.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.blue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              InkWell(
                                onTap: _clearReplyTarget,
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Mention user',
                            onPressed: () => unawaited(_pickMention()),
                            icon: const Icon(Icons.alternate_email_rounded),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: _replyingTo == null
                                    ? 'Tulis komentar...'
                                    : 'Tulis balasan...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed:
                                widget.controller.isCommentSubmitting(
                                  widget.postId,
                                )
                                ? null
                                : () => unawaited(_submitComment()),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(54, 54),
                              padding: EdgeInsets.zero,
                            ),
                            child:
                                widget.controller.isCommentSubmitting(
                                  widget.postId,
                                )
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
