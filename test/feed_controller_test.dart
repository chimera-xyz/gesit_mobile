import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/feed_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/models/feed_models.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedController', () {
    late AppSessionController sessionController;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      sessionController = AppSessionController(apiClient: GesitApiClient());
      await sessionController.syncSession(_buildSession(), notify: false);
    });

    tearDown(() {
      sessionController.dispose();
    });

    test(
      'ensureLoaded hydrates feed and addComment refreshes thread cache',
      () async {
        var threadHasComment = false;

        final controller = FeedController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' && request.url.path == '/api/feed') {
                return _jsonResponse({
                  'posts': [
                    _postJson(
                      id: 'post-1',
                      commentsCount: threadHasComment ? 1 : 0,
                    ),
                  ],
                  'pagination': {
                    'current_page': 1,
                    'last_page': 1,
                    'per_page': 10,
                    'total': 1,
                  },
                });
              }

              if (request.method == 'GET' &&
                  request.url.path == '/api/feed/posts/post-1') {
                return _jsonResponse({
                  'post': _postJson(
                    id: 'post-1',
                    commentsCount: threadHasComment ? 1 : 0,
                    comments: threadHasComment
                        ? [
                            _commentJson(
                              id: 'comment-1',
                              content: 'Siap, saya bantu remind juga.',
                            ),
                          ]
                        : const [],
                  ),
                });
              }

              if (request.method == 'POST' &&
                  request.url.path == '/api/feed/posts/post-1/comments') {
                threadHasComment = true;
                return _jsonResponse({
                  'post': _postJson(id: 'post-1', commentsCount: 1),
                  'comment': _commentJson(
                    id: 'comment-1',
                    content: 'Siap, saya bantu remind juga.',
                  ),
                }, statusCode: 201);
              }

              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();
        expect(controller.posts.single.commentsCount, 0);

        await controller.fetchThread('post-1');
        expect(controller.threadById('post-1')?.comments, isEmpty);

        await controller.addComment(
          postId: 'post-1',
          content: 'Siap, saya bantu remind juga.',
        );

        expect(controller.postById('post-1')?.commentsCount, 1);
        expect(
          controller.threadById('post-1')?.comments.single.content,
          'Siap, saya bantu remind juga.',
        );
      },
    );

    test('createPost inserts new post at the top of the feed', () async {
      final controller = FeedController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' && request.url.path == '/api/feed') {
              return _jsonResponse({
                'posts': [_postJson(id: 'post-1')],
                'pagination': {
                  'current_page': 1,
                  'last_page': 1,
                  'per_page': 10,
                  'total': 1,
                },
              });
            }

            if (request.method == 'POST' &&
                request.url.path == '/api/feed/posts') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(
                body['visibility'],
                FeedVisibility.department.storageValue,
              );
              expect(body['content'], 'Reminder divisi siang ini.');

              return _jsonResponse({
                'post': _postJson(
                  id: 'post-2',
                  visibility: 'department',
                  visibilityLabel: 'Divisi Operations',
                  content: 'Reminder divisi siang ini.',
                ),
              }, statusCode: 201);
            }

            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();
      await controller.createPost(
        content: 'Reminder divisi siang ini.',
        visibility: FeedVisibility.department,
      );

      expect(controller.posts, hasLength(2));
      expect(controller.posts.first.id, 'post-2');
      expect(controller.posts.first.visibility, FeedVisibility.department);
    });

    test(
      'createPost forwards selected recipient ids and audience members can be loaded',
      () async {
        final controller = FeedController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' &&
                  request.url.path == '/api/feed/audience-members') {
                return _jsonResponse({
                  'users': [
                    {
                      'id': 'user-9',
                      'name': 'Dina Finance',
                      'initials': 'DF',
                      'department': 'Finance',
                      'primary_role': 'Accounting',
                    },
                  ],
                });
              }

              if (request.method == 'GET' && request.url.path == '/api/feed') {
                return _jsonResponse({
                  'posts': const [],
                  'pagination': {
                    'current_page': 1,
                    'last_page': 1,
                    'per_page': 10,
                    'total': 0,
                  },
                });
              }

              if (request.method == 'POST' &&
                  request.url.path == '/api/feed/posts') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(
                  body['visibility'],
                  FeedVisibility.selectedUsers.storageValue,
                );
                expect(body['recipient_user_ids'], ['user-9']);

                return _jsonResponse({
                  'post': _postJson(
                    id: 'post-9',
                    visibility: 'selected_users',
                    visibilityLabel: 'Orang tertentu (1)',
                    content: 'Private update untuk user tertentu.',
                  ),
                }, statusCode: 201);
              }

              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        final members = await controller.ensureAudienceMembersLoaded();
        expect(members, hasLength(1));
        expect(members.single.id, 'user-9');

        await controller.createPost(
          content: 'Private update untuk user tertentu.',
          visibility: FeedVisibility.selectedUsers,
          recipientUserIds: const ['user-9'],
        );

        expect(controller.posts.first.visibility, FeedVisibility.selectedUsers);
      },
    );

    test('addComment forwards mentioned user ids', () async {
      final controller = FeedController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path == '/api/feed/posts/post-1/comments') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['mentioned_user_ids'], ['user-7']);

              return _jsonResponse({
                'post': _postJson(id: 'post-1', commentsCount: 1),
                'comment': _commentJson(
                  id: 'comment-7',
                  content: 'Mention ke Dina dulu ya.',
                ),
              }, statusCode: 201);
            }

            if (request.method == 'GET' &&
                request.url.path == '/api/feed/posts/post-1') {
              return _jsonResponse({
                'post': _postJson(
                  id: 'post-1',
                  commentsCount: 1,
                  comments: [
                    _commentJson(
                      id: 'comment-7',
                      content: 'Mention ke Dina dulu ya.',
                    ),
                  ],
                ),
              });
            }

            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.addComment(
        postId: 'post-1',
        content: 'Mention ke Dina dulu ya.',
        mentionedUserIds: const ['user-7'],
      );

      expect(controller.threadById('post-1')?.comments.single.id, 'comment-7');
    });

    test('fetchThread keeps reply target metadata on flat replies', () async {
      final controller = FeedController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' && request.url.path == '/api/feed') {
              return _jsonResponse({
                'posts': [_postJson(id: 'post-1', commentsCount: 3)],
                'pagination': {
                  'current_page': 1,
                  'last_page': 1,
                  'per_page': 10,
                  'total': 1,
                },
              });
            }

            if (request.method == 'GET' &&
                request.url.path == '/api/feed/posts/post-1') {
              return _jsonResponse({
                'post': _postJson(
                  id: 'post-1',
                  commentsCount: 3,
                  comments: [
                    _commentJson(
                      id: 'comment-1',
                      content: 'Siap, nanti saya teruskan.',
                      authorName: 'Raihan Carjasti',
                      authorRole: 'Employee',
                      authorDepartment: 'Operations',
                      replies: [
                        _commentJson(
                          id: 'reply-1',
                          content: 'Oke, bantu remind ya.',
                          parentId: 'comment-1',
                          replyToCommentId: 'comment-1',
                          replyToUserName: 'Raihan Carjasti',
                          replyToUserRole: 'Employee',
                          replyToUserDepartment: 'Operations',
                          authorName: 'Nadia Finance',
                          authorInitials: 'NF',
                          authorRole: 'Accounting',
                          authorDepartment: 'Finance',
                        ),
                        _commentJson(
                          id: 'reply-2',
                          content: 'Siap, saya lanjut follow up.',
                          parentId: 'comment-1',
                          replyToCommentId: 'reply-1',
                          replyToUserName: 'Nadia Finance',
                          replyToUserInitials: 'NF',
                          replyToUserRole: 'Accounting',
                          replyToUserDepartment: 'Finance',
                          authorName: 'Budi IT',
                          authorInitials: 'BI',
                          authorRole: 'IT Staff',
                          authorDepartment: 'IT',
                        ),
                      ],
                    ),
                  ],
                ),
              });
            }

            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();
      await controller.fetchThread('post-1');

      final replies = controller.threadById('post-1')!.comments.single.replies;
      expect(replies, hasLength(2));
      expect(replies.last.parentId, 'comment-1');
      expect(replies.last.replyToCommentId, 'reply-1');
      expect(replies.last.replyToUser?.name, 'Nadia Finance');
    });
  });
}

AppSession _buildSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'user-1',
      name: 'Raihan Carjasti',
      email: 'raihan@example.com',
      roles: ['Employee'],
      permissions: ['view submissions'],
      department: 'Operations',
    ),
    apiBaseUrl: 'http://localhost:8000',
    cookies: const {'laravel_session': 'cookie'},
    rememberSession: true,
    authenticatedAt: DateTime(2026, 4, 20, 8, 30),
  );
}

Map<String, dynamic> _postJson({
  required String id,
  String visibility = 'public',
  String visibilityLabel = 'Semua orang',
  String content = 'Update internal hari ini.',
  int likesCount = 0,
  int commentsCount = 0,
  List<Map<String, dynamic>> comments = const [],
}) {
  return {
    'id': id,
    'content': content,
    'visibility': visibility,
    'visibility_label': visibilityLabel,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'liked_by_me': false,
    'can_delete': true,
    'created_at': '2026-04-20T08:15:00.000Z',
    'updated_at': '2026-04-20T08:15:00.000Z',
    'last_activity_at': '2026-04-20T08:15:00.000Z',
    'author': {
      'id': 'user-2',
      'name': 'Nadia Finance',
      'initials': 'NF',
      'department': 'Finance',
      'primary_role': 'Accounting',
    },
    'comments': comments,
  };
}

Map<String, dynamic> _commentJson({
  required String id,
  required String content,
  String? parentId,
  String? replyToCommentId,
  String? replyToUserName,
  String? replyToUserInitials,
  String? replyToUserRole,
  String? replyToUserDepartment,
  String authorName = 'Raihan Carjasti',
  String authorInitials = 'RC',
  String authorRole = 'Employee',
  String authorDepartment = 'Operations',
  List<Map<String, dynamic>> replies = const [],
}) {
  return {
    'id': id,
    'post_id': 'post-1',
    'parent_id': parentId,
    'reply_to_comment_id': replyToCommentId,
    'reply_to_user': replyToUserName == null
        ? null
        : {
            'id': 'reply-user-$id',
            'name': replyToUserName,
            'initials': replyToUserInitials ?? 'RU',
            'department': replyToUserDepartment,
            'primary_role': replyToUserRole ?? 'Internal',
          },
    'content': content,
    'likes_count': 0,
    'reply_count': 0,
    'liked_by_me': false,
    'can_delete': true,
    'created_at': '2026-04-20T08:18:00.000Z',
    'updated_at': '2026-04-20T08:18:00.000Z',
    'author': {
      'id': 'user-1',
      'name': authorName,
      'initials': authorInitials,
      'department': authorDepartment,
      'primary_role': authorRole,
    },
    'replies': replies,
  };
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
