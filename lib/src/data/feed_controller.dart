import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_runtime_config.dart';
import '../models/feed_models.dart';
import '../models/session_models.dart';
import 'app_session_controller.dart';
import 'gesit_api_client.dart';

class FeedController extends ChangeNotifier {
  FeedController({
    required AppSessionController sessionController,
    GesitApiClient? apiClient,
    Duration autoRefreshInterval = const Duration(seconds: 20),
  }) : _sessionController = sessionController,
       _apiClient = apiClient ?? GesitApiClient(),
       _autoRefreshInterval = autoRefreshInterval;

  final AppSessionController _sessionController;
  final GesitApiClient _apiClient;
  final Duration _autoRefreshInterval;

  final Map<String, FeedPost> _threadCache = <String, FeedPost>{};
  final Set<String> _threadLoadingIds = <String>{};
  final Set<String> _postLikeBusyIds = <String>{};
  final Set<String> _commentLikeBusyIds = <String>{};
  final Set<String> _commentSubmittingPostIds = <String>{};
  final Set<String> _deletingPostIds = <String>{};
  final Set<String> _deletingCommentIds = <String>{};
  Timer? _autoRefreshTimer;
  bool _autoRefreshEnabled = true;

  List<FeedPost> _posts = const <FeedPost>[];
  List<FeedAudienceMember> _audienceMembers = const <FeedAudienceMember>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  bool _creatingPost = false;
  bool _autoRefreshing = false;
  bool _loadingAudienceMembers = false;
  String? _error;
  int _currentPage = 0;
  int _lastPage = 1;

  List<FeedPost> get posts => _posts;
  List<FeedAudienceMember> get audienceMembers => _audienceMembers;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get loaded => _loaded;
  bool get creatingPost => _creatingPost;
  bool get loadingAudienceMembers => _loadingAudienceMembers;
  String? get error => _error;
  bool get hasMore => _currentPage < _lastPage;

  FeedPost? postById(String postId) {
    for (final post in _posts) {
      if (post.id == postId) {
        return post;
      }
    }

    return _threadCache[postId];
  }

  FeedPost? threadById(String postId) => _threadCache[postId];

  bool isThreadLoading(String postId) => _threadLoadingIds.contains(postId);

  bool isPostLikeBusy(String postId) => _postLikeBusyIds.contains(postId);

  bool isCommentLikeBusy(String commentId) =>
      _commentLikeBusyIds.contains(commentId);

  bool isCommentSubmitting(String postId) =>
      _commentSubmittingPostIds.contains(postId);

  bool isDeletingPost(String postId) => _deletingPostIds.contains(postId);

  bool isDeletingComment(String commentId) =>
      _deletingCommentIds.contains(commentId);

  Future<void> ensureLoaded() async {
    if (_autoRefreshEnabled) {
      _startAutoRefresh();
    }

    if (_loaded || _loading) {
      return;
    }

    await refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    final session = _sessionController.session;
    if (session == null) {
      return;
    }

    if (silent && _shouldSkipSilentRefresh) {
      return;
    }

    if (silent) {
      if (_autoRefreshing) {
        return;
      }
      _autoRefreshing = true;
    } else {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final payload = await _apiClient.fetchFeed(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      await _sessionController.syncCookies(payload.cookies);

      final data = payload.data;
      _posts = _adaptPosts(data['posts']);
      _currentPage = _intValue(
        _mapValue(data['pagination'])['current_page'],
        1,
      );
      _lastPage = _intValue(_mapValue(data['pagination'])['last_page'], 1);
      if (!silent || !_loaded) {
        _error = null;
      }
    } on GesitApiException catch (error) {
      if (!silent || !_loaded || error.statusCode == 401) {
        await _handleLoadFailure(error);
      }
    } on TimeoutException {
      if (!silent || !_loaded) {
        _error = 'Feed terlalu lama merespons.';
      }
    } catch (_) {
      if (!silent || !_loaded) {
        _error = 'Feed belum bisa dimuat.';
      }
    } finally {
      if (silent) {
        _autoRefreshing = false;
      } else {
        _loading = false;
      }
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !hasMore) {
      return;
    }

    final session = _requireSession();
    _loadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final payload = await _apiClient.fetchFeed(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        page: nextPage,
      );
      await _sessionController.syncCookies(payload.cookies);

      final data = payload.data;
      final nextPosts = _adaptPosts(data['posts']);
      final merged = List<FeedPost>.from(_posts);

      for (final post in nextPosts) {
        final index = merged.indexWhere((item) => item.id == post.id);
        if (index >= 0) {
          merged[index] = _mergeWithCachedThread(post);
        } else {
          merged.add(_mergeWithCachedThread(post));
        }
      }

      _posts = List<FeedPost>.unmodifiable(merged);
      _currentPage = _intValue(
        _mapValue(data['pagination'])['current_page'],
        nextPage,
      );
      _lastPage = _intValue(
        _mapValue(data['pagination'])['last_page'],
        _lastPage,
      );
      _error = null;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
        _posts = const <FeedPost>[];
      } else {
        _error = error.message;
      }
    } on TimeoutException {
      _error = 'Feed tambahan belum bisa dimuat.';
    } catch (_) {
      _error = 'Feed tambahan belum bisa dimuat.';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<FeedPost> fetchThread(
    String postId, {
    bool forceRefresh = false,
  }) async {
    final cached = _threadCache[postId];
    if (!forceRefresh && cached != null && cached.comments.isNotEmpty) {
      return cached;
    }
    if (_threadLoadingIds.contains(postId) && cached != null) {
      return cached;
    }

    final session = _requireSession();
    _threadLoadingIds.add(postId);
    notifyListeners();

    try {
      final payload = await _apiClient.fetchFeedPost(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        postId: postId,
      );
      await _sessionController.syncCookies(payload.cookies);

      final post = FeedPost.fromJson(_mapValue(payload.data['post']));
      _threadCache[postId] = post;
      _upsertPost(post);
      _error = null;
      return post;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _threadLoadingIds.remove(postId);
      notifyListeners();
    }
  }

  Future<FeedPost> createPost({
    required String content,
    required FeedVisibility visibility,
    List<String> recipientUserIds = const <String>[],
  }) async {
    final session = _requireSession();
    _creatingPost = true;
    notifyListeners();

    try {
      final payload = await _apiClient.createFeedPost(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        content: content,
        visibility: visibility.storageValue,
        recipientUserIds: recipientUserIds,
      );
      await _sessionController.syncCookies(payload.cookies);

      final post = FeedPost.fromJson(_mapValue(payload.data['post']));
      _threadCache[post.id] = post;
      _posts = List<FeedPost>.unmodifiable(<FeedPost>[
        post,
        ..._posts.where((item) => item.id != post.id),
      ]);
      _error = null;
      notifyListeners();
      return post;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _creatingPost = false;
      notifyListeners();
    }
  }

  Future<FeedPost> togglePostLike(String postId) async {
    final session = _requireSession();
    _postLikeBusyIds.add(postId);
    notifyListeners();

    try {
      final payload = await _apiClient.toggleFeedPostLike(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        postId: postId,
      );
      await _sessionController.syncCookies(payload.cookies);

      final post = FeedPost.fromJson(_mapValue(payload.data['post']));
      _upsertPost(post);
      return _threadCache[post.id] ?? post;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _postLikeBusyIds.remove(postId);
      notifyListeners();
    }
  }

  Future<FeedComment> addComment({
    required String postId,
    required String content,
    String? parentId,
    List<String> mentionedUserIds = const <String>[],
  }) async {
    final session = _requireSession();
    _commentSubmittingPostIds.add(postId);
    notifyListeners();

    try {
      final payload = await _apiClient.createFeedComment(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        postId: postId,
        content: content,
        parentId: parentId,
        mentionedUserIds: mentionedUserIds,
      );
      await _sessionController.syncCookies(payload.cookies);

      final post = FeedPost.fromJson(_mapValue(payload.data['post']));
      final comment = FeedComment.fromJson(_mapValue(payload.data['comment']));
      _upsertPost(post);
      await fetchThread(postId, forceRefresh: true);
      return comment;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _commentSubmittingPostIds.remove(postId);
      notifyListeners();
    }
  }

  Future<FeedComment> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    final session = _requireSession();
    _commentLikeBusyIds.add(commentId);
    notifyListeners();

    try {
      final payload = await _apiClient.toggleFeedCommentLike(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        commentId: commentId,
      );
      await _sessionController.syncCookies(payload.cookies);

      final updatedComment = FeedComment.fromJson(
        _mapValue(payload.data['comment']),
      );
      final currentThread = _threadCache[postId];
      if (currentThread != null) {
        _threadCache[postId] = currentThread.copyWith(
          comments: _replaceCommentInTree(
            currentThread.comments,
            updatedComment,
          ),
        );
        _upsertPost(_threadCache[postId]!);
      }
      return updatedComment;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _commentLikeBusyIds.remove(commentId);
      notifyListeners();
    }
  }

  Future<void> deletePost(String postId) async {
    final session = _requireSession();
    _deletingPostIds.add(postId);
    notifyListeners();

    try {
      final payload = await _apiClient.deleteFeedPost(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        postId: postId,
      );
      await _sessionController.syncCookies(payload.cookies);

      final deletedId =
          _normalizedString(payload.data['deleted_post_id']) ?? postId;
      _threadCache.remove(deletedId);
      _posts = List<FeedPost>.unmodifiable(
        _posts.where((item) => item.id != deletedId),
      );
      notifyListeners();
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _deletingPostIds.remove(postId);
      notifyListeners();
    }
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final session = _requireSession();
    _deletingCommentIds.add(commentId);
    notifyListeners();

    try {
      final payload = await _apiClient.deleteFeedComment(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        commentId: commentId,
      );
      await _sessionController.syncCookies(payload.cookies);

      final post = FeedPost.fromJson(_mapValue(payload.data['post']));
      _upsertPost(post);
      await fetchThread(postId, forceRefresh: true);
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _deletingCommentIds.remove(commentId);
      notifyListeners();
    }
  }

  Future<List<FeedAudienceMember>> ensureAudienceMembersLoaded({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _audienceMembers.isNotEmpty) {
      return audienceMembers;
    }
    if (_loadingAudienceMembers && !forceRefresh) {
      return audienceMembers;
    }

    final session = _requireSession();
    _loadingAudienceMembers = true;
    notifyListeners();

    try {
      final payload = await _apiClient.fetchFeedAudienceMembers(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      await _sessionController.syncCookies(payload.cookies);

      _audienceMembers = List<FeedAudienceMember>.unmodifiable(
        ((payload.data['users'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  FeedAudienceMember.fromJson(item.cast<String, dynamic>()),
            )
            .where((member) => member.id.trim().isNotEmpty),
      );
      return audienceMembers;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionController.invalidateSession(errorMessage: error.message);
      }
      rethrow;
    } finally {
      _loadingAudienceMembers = false;
      notifyListeners();
    }
  }

  Future<void> _handleLoadFailure(GesitApiException error) async {
    if (error.statusCode == 401) {
      _posts = const <FeedPost>[];
      _error = 'Sesi login berakhir. Silakan masuk lagi.';
      await _sessionController.invalidateSession(errorMessage: _error);
      return;
    }

    _error = error.message;
  }

  AppSession _requireSession() {
    final session = _sessionController.session;
    if (session == null) {
      throw const GesitApiException('Sesi login belum tersedia.');
    }

    return session;
  }

  List<FeedPost> _adaptPosts(Object? rawPosts) {
    return List<FeedPost>.unmodifiable(
      ((rawPosts as List?) ?? const [])
          .whereType<Map>()
          .map((item) => FeedPost.fromJson(item.cast<String, dynamic>()))
          .map(_mergeWithCachedThread),
    );
  }

  FeedPost _mergeWithCachedThread(FeedPost post) {
    final cached = _threadCache[post.id];
    if (cached == null) {
      return post;
    }

    final resolvedComments = post.comments.isNotEmpty
        ? post.comments
        : cached.comments;
    final merged = post.copyWith(comments: resolvedComments);
    _threadCache[post.id] = merged;
    return merged;
  }

  void _upsertPost(FeedPost post) {
    final merged = _mergeWithCachedThread(post);
    _threadCache[merged.id] = merged;

    final nextPosts = List<FeedPost>.from(_posts);
    final index = nextPosts.indexWhere((item) => item.id == merged.id);
    if (index >= 0) {
      nextPosts[index] = merged;
    } else {
      nextPosts.insert(0, merged);
    }

    nextPosts.sort((left, right) {
      final leftAt = left.lastActivityAt ?? left.createdAt;
      final rightAt = right.lastActivityAt ?? right.createdAt;
      return rightAt.compareTo(leftAt);
    });

    _posts = List<FeedPost>.unmodifiable(nextPosts);
  }

  List<FeedComment> _replaceCommentInTree(
    List<FeedComment> comments,
    FeedComment updated,
  ) {
    return comments
        .map((comment) {
          if (comment.id == updated.id) {
            return updated.copyWith(
              replies: updated.replies.isNotEmpty
                  ? updated.replies
                  : comment.replies,
            );
          }

          final replyIndex = comment.replies.indexWhere(
            (reply) => reply.id == updated.id,
          );
          if (replyIndex < 0) {
            return comment;
          }

          final replies = List<FeedComment>.from(comment.replies);
          replies[replyIndex] = updated;
          return comment.copyWith(replies: replies);
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _mapValue(Object? rawValue) {
    if (rawValue is Map<String, dynamic>) {
      return rawValue;
    }
    if (rawValue is Map) {
      return rawValue.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  int _intValue(Object? value, int fallback) {
    return (value as num?)?.toInt() ?? fallback;
  }

  bool get _shouldSkipSilentRefresh {
    return _loading ||
        _loadingMore ||
        _creatingPost ||
        _autoRefreshing ||
        _threadLoadingIds.isNotEmpty ||
        _postLikeBusyIds.isNotEmpty ||
        _commentLikeBusyIds.isNotEmpty ||
        _commentSubmittingPostIds.isNotEmpty ||
        _deletingPostIds.isNotEmpty ||
        _deletingCommentIds.isNotEmpty;
  }

  void setAutoRefreshActive(bool active) {
    if (_autoRefreshEnabled == active) {
      return;
    }

    _autoRefreshEnabled = active;
    if (_autoRefreshEnabled) {
      _startAutoRefresh();
      return;
    }

    _stopAutoRefresh();
  }

  void _startAutoRefresh() {
    if (!_autoRefreshEnabled || _autoRefreshTimer != null) {
      return;
    }

    final interval = _effectiveAutoRefreshInterval;
    _autoRefreshTimer = Timer.periodic(interval, (_) {
      unawaited(refresh(silent: true));
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Duration get _effectiveAutoRefreshInterval {
    if (AppRuntimeConfig.prefersShortPolling(
      _sessionController.session?.apiBaseUrl,
    )) {
      return const Duration(seconds: 60);
    }

    return _autoRefreshInterval;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }
}

String? _normalizedString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
