class FeedAuthor {
  const FeedAuthor({
    required this.id,
    required this.name,
    required this.initials,
    required this.primaryRole,
    this.department,
  });

  final String id;
  final String name;
  final String initials;
  final String primaryRole;
  final String? department;

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? 'Internal User'}'.trim();
    final fallbackInitials = _fallbackInitials(name);

    return FeedAuthor(
      id: '${json['id'] ?? ''}',
      name: name.isEmpty ? 'Internal User' : name,
      initials: _normalizedString(json['initials']) ?? fallbackInitials,
      primaryRole: _normalizedString(json['primary_role']) ?? 'Internal',
      department: _normalizedString(json['department']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'initials': initials,
      'primary_role': primaryRole,
      'department': department,
    };
  }
}

class FeedAudienceMember {
  const FeedAudienceMember({
    required this.id,
    required this.name,
    required this.initials,
    required this.primaryRole,
    this.department,
  });

  final String id;
  final String name;
  final String initials;
  final String primaryRole;
  final String? department;

  factory FeedAudienceMember.fromJson(Map<String, dynamic> json) {
    final author = FeedAuthor.fromJson(json);

    return FeedAudienceMember(
      id: author.id,
      name: author.name,
      initials: author.initials,
      primaryRole: author.primaryRole,
      department: author.department,
    );
  }
}

enum FeedVisibility { publicScope, department, selectedUsers, privateScope }

extension FeedVisibilityX on FeedVisibility {
  String get storageValue {
    switch (this) {
      case FeedVisibility.publicScope:
        return 'public';
      case FeedVisibility.department:
        return 'department';
      case FeedVisibility.selectedUsers:
        return 'selected_users';
      case FeedVisibility.privateScope:
        return 'private';
    }
  }

  static FeedVisibility fromStorageValue(String? value) {
    switch (value) {
      case 'department':
        return FeedVisibility.department;
      case 'selected_users':
        return FeedVisibility.selectedUsers;
      case 'private':
        return FeedVisibility.privateScope;
      case 'public':
      default:
        return FeedVisibility.publicScope;
    }
  }
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.author,
    required this.createdAt,
    this.parentId,
    this.replyToCommentId,
    this.replyToUser,
    this.likesCount = 0,
    this.replyCount = 0,
    this.likedByMe = false,
    this.canDelete = false,
    this.replies = const <FeedComment>[],
    this.updatedAt,
  });

  final String id;
  final String postId;
  final String? parentId;
  final String? replyToCommentId;
  final FeedAuthor? replyToUser;
  final String content;
  final FeedAuthor author;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final int replyCount;
  final bool likedByMe;
  final bool canDelete;
  final List<FeedComment> replies;

  FeedComment copyWith({
    String? id,
    String? postId,
    String? parentId,
    String? replyToCommentId,
    FeedAuthor? replyToUser,
    String? content,
    FeedAuthor? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? replyCount,
    bool? likedByMe,
    bool? canDelete,
    List<FeedComment>? replies,
  }) {
    return FeedComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      parentId: parentId ?? this.parentId,
      replyToCommentId: replyToCommentId ?? this.replyToCommentId,
      replyToUser: replyToUser ?? this.replyToUser,
      content: content ?? this.content,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      replyCount: replyCount ?? this.replyCount,
      likedByMe: likedByMe ?? this.likedByMe,
      canDelete: canDelete ?? this.canDelete,
      replies: replies ?? this.replies,
    );
  }

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    final replyToUserJson = (json['reply_to_user'] as Map?)
        ?.cast<String, dynamic>();

    return FeedComment(
      id: '${json['id'] ?? ''}',
      postId: '${json['post_id'] ?? ''}',
      parentId: _normalizedString(json['parent_id']),
      replyToCommentId: _normalizedString(json['reply_to_comment_id']),
      replyToUser: replyToUserJson == null
          ? null
          : FeedAuthor.fromJson(replyToUserJson),
      content: '${json['content'] ?? ''}',
      author: FeedAuthor.fromJson(
        (json['author'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      canDelete: json['can_delete'] == true,
      replies: ((json['replies'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => FeedComment.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'parent_id': parentId,
      'reply_to_comment_id': replyToCommentId,
      'reply_to_user': replyToUser?.toJson(),
      'content': content,
      'author': author.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'likes_count': likesCount,
      'reply_count': replyCount,
      'liked_by_me': likedByMe,
      'can_delete': canDelete,
      'replies': replies.map((reply) => reply.toJson()).toList(growable: false),
    };
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.content,
    required this.author,
    required this.visibility,
    required this.visibilityLabel,
    required this.createdAt,
    this.updatedAt,
    this.lastActivityAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
    this.canDelete = false,
    this.comments = const <FeedComment>[],
    this.selectedRecipientCount = 0,
    this.audienceUserIds = const <String>[],
  });

  final String id;
  final String content;
  final FeedAuthor author;
  final FeedVisibility visibility;
  final String visibilityLabel;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActivityAt;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool canDelete;
  final List<FeedComment> comments;
  final int selectedRecipientCount;
  final List<String> audienceUserIds;

  FeedPost copyWith({
    String? id,
    String? content,
    FeedAuthor? author,
    FeedVisibility? visibility,
    String? visibilityLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActivityAt,
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
    bool? canDelete,
    List<FeedComment>? comments,
    int? selectedRecipientCount,
    List<String>? audienceUserIds,
  }) {
    return FeedPost(
      id: id ?? this.id,
      content: content ?? this.content,
      author: author ?? this.author,
      visibility: visibility ?? this.visibility,
      visibilityLabel: visibilityLabel ?? this.visibilityLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
      canDelete: canDelete ?? this.canDelete,
      comments: comments ?? this.comments,
      selectedRecipientCount:
          selectedRecipientCount ?? this.selectedRecipientCount,
      audienceUserIds: audienceUserIds ?? this.audienceUserIds,
    );
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: '${json['id'] ?? ''}',
      content: '${json['content'] ?? ''}',
      author: FeedAuthor.fromJson(
        (json['author'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      visibility: FeedVisibilityX.fromStorageValue(
        _normalizedString(json['visibility']),
      ),
      visibilityLabel:
          _normalizedString(json['visibility_label']) ?? 'Semua orang',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      lastActivityAt: DateTime.tryParse('${json['last_activity_at'] ?? ''}'),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      canDelete: json['can_delete'] == true,
      selectedRecipientCount:
          (json['selected_recipient_count'] as num?)?.toInt() ?? 0,
      audienceUserIds: ((json['audience_user_ids'] as List?) ?? const [])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      comments: ((json['comments'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => FeedComment.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'author': author.toJson(),
      'visibility': visibility.storageValue,
      'visibility_label': visibilityLabel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_activity_at': lastActivityAt?.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'liked_by_me': likedByMe,
      'can_delete': canDelete,
      'selected_recipient_count': selectedRecipientCount,
      'audience_user_ids': audienceUserIds,
      'comments': comments
          .map((comment) => comment.toJson())
          .toList(growable: false),
    };
  }
}

String? _normalizedString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String _fallbackInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'IU';
  }

  if (parts.length == 1) {
    final token = parts.first;
    return token
        .substring(0, token.length >= 2 ? 2 : token.length)
        .toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
