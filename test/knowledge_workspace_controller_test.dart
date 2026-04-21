import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/knowledge_workspace_controller.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KnowledgeWorkspaceController', () {
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
      'loads knowledge hub documents and conversations from backend',
      () async {
        final controller = KnowledgeWorkspaceController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub') {
                return _jsonResponse(_hubJson());
              }
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub/conversations') {
                return _jsonResponse({
                  'conversations': [_conversationJson()],
                });
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();

        expect(controller.loaded, isTrue);
        expect(controller.spaces.single.name, 'Corporate Operations');
        expect(controller.documents.single.title, 'SOP Approval Pengadaan');
        expect(
          controller.documents.single.attachmentUrl,
          'http://localhost:8000/storage/knowledge/sop.pdf',
        );
        expect(controller.suggestedQuestions.first, 'Ringkas SOP approval');
        expect(controller.conversations.single.title, 'Approval Pengadaan');
      },
    );

    test('asks assistant and maps document source cards', () async {
      final controller = KnowledgeWorkspaceController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/knowledge-hub') {
              return _jsonResponse(_hubJson());
            }
            if (request.method == 'GET' &&
                request.url.path == '/api/knowledge-hub/conversations') {
              return _jsonResponse({'conversations': []});
            }
            if (request.method == 'POST' &&
                request.url.path == '/api/knowledge-hub/ask') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['question'], 'Ringkas SOP approval');
              expect(body.containsKey('conversation_id'), isFalse);
              return _jsonResponse({
                'conversation': _conversationJson(id: 9),
                'user_message': {
                  'id': 20,
                  'role': 'user',
                  'content': 'Ringkas SOP approval',
                  'sources': [],
                },
                'assistant_message': {
                  'id': 21,
                  'role': 'assistant',
                  'content':
                      'Ini ringkasannya.\n\n[[DOCUMENT_CARDS]]\n\nBuka dokumen untuk detail.',
                  'source_intro': 'Ini ringkasannya.',
                  'source_closing': 'Buka dokumen untuk detail.',
                  'sources': [_sourceJson()],
                },
              });
            }
            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();
      await controller.ask('Ringkas SOP approval');

      expect(controller.activeConversationId, '9');
      expect(controller.messages, hasLength(2));
      expect(controller.messages.last.text, 'Ini ringkasannya.');
      expect(
        controller.messages.last.sourceClosing,
        'Buka dokumen untuk detail.',
      );
      expect(controller.messages.last.sources.single.documentId, '5');
      expect(controller.conversations.single.id, '9');
    });

    test('runs assistant message action and appends real ticket response', () async {
      final controller = KnowledgeWorkspaceController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/knowledge-hub') {
              return _jsonResponse(_hubJson());
            }
            if (request.method == 'GET' &&
                request.url.path == '/api/knowledge-hub/conversations') {
              return _jsonResponse({'conversations': []});
            }
            if (request.method == 'POST' &&
                request.url.path == '/api/knowledge-hub/ask') {
              return _jsonResponse({
                'conversation': _conversationJson(id: 12),
                'user_message': {
                  'id': 40,
                  'role': 'user',
                  'content': 'Akun S21+ saya keblokir',
                  'sources': [],
                  'actions': [],
                },
                'assistant_message': {
                  'id': 41,
                  'role': 'assistant',
                  'content':
                      'Saya bisa buatkan ticket ke Tim IT langsung dari percakapan ini.',
                  'sources': [],
                  'actions': [
                    {
                      'key': 's21plus_contact_it',
                      'label': 'Buat ticket ke Tim IT',
                      'variant': 'secondary',
                    },
                  ],
                },
              });
            }
            if (request.method == 'POST' &&
                request.url.path ==
                    '/api/knowledge-hub/conversations/12/actions') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['message_id'], '41');
              expect(body['action_key'], 's21plus_contact_it');
              return _jsonResponse({
                'conversation': _conversationJson(id: 12),
                'updated_message': {
                  'id': 41,
                  'role': 'assistant',
                  'content':
                      'Saya bisa buatkan ticket ke Tim IT langsung dari percakapan ini.',
                  'sources': [],
                  'actions': [],
                },
                'user_message': {
                  'id': 42,
                  'role': 'user',
                  'content': 'Buat ticket ke Tim IT',
                  'sources': [],
                  'actions': [],
                },
                'assistant_message': {
                  'id': 43,
                  'role': 'assistant',
                  'content':
                      'Saya sudah buat ticket HD-001 untuk kendala akses akun S21Plus.',
                  'sources': [],
                  'actions': [],
                },
              });
            }
            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();
      await controller.ask('Akun S21+ saya keblokir');

      final actionMessage = controller.messages.last;
      expect(actionMessage.actions.single.label, 'Buat ticket ke Tim IT');

      await controller.runMessageAction(
        message: actionMessage,
        action: actionMessage.actions.single,
      );

      expect(controller.messages, hasLength(4));
      expect(controller.messages[1].actions, isEmpty);
      expect(controller.messages[2].text, 'Buat ticket ke Tim IT');
      expect(
        controller.messages.last.text,
        'Saya sudah buat ticket HD-001 untuk kendala akses akun S21Plus.',
      );
    });

    test(
      'does not claim ticket exists before pending ticket action runs',
      () async {
        var askCount = 0;
        final controller = KnowledgeWorkspaceController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub') {
                return _jsonResponse(_hubJson());
              }
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub/conversations') {
                return _jsonResponse({'conversations': []});
              }
              if (request.method == 'POST' &&
                  request.url.path == '/api/knowledge-hub/ask') {
                askCount += 1;
                return _jsonResponse({
                  'conversation': _conversationJson(id: 12),
                  'user_message': {
                    'id': 50,
                    'role': 'user',
                    'content': 'Akun S21+ saya keblokir',
                    'sources': [],
                    'actions': [],
                  },
                  'assistant_message': {
                    'id': 51,
                    'role': 'assistant',
                    'content':
                        'Saya bisa buatkan ticket ke Tim IT langsung dari percakapan ini.',
                    'sources': [],
                    'actions': [
                      {
                        'key': 's21plus_contact_it',
                        'label': 'Buat ticket ke Tim IT',
                        'variant': 'secondary',
                      },
                    ],
                  },
                });
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();
        await controller.ask('Akun S21+ saya keblokir');
        await controller.ask('udah dibuat ticketnya?');

        expect(askCount, 1);
        expect(controller.messages.last.isUser, isFalse);
        expect(controller.messages.last.text, startsWith('Belum.'));
        expect(
          controller.messages.last.text,
          contains('Buat ticket ke Tim IT'),
        );
      },
    );

    test(
      'toggleBookmark updates document optimistically from backend result',
      () async {
        final controller = KnowledgeWorkspaceController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub') {
                return _jsonResponse(_hubJson(isBookmarked: false));
              }
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub/conversations') {
                return _jsonResponse({'conversations': []});
              }
              if (request.method == 'POST' &&
                  request.url.path == '/api/knowledge-hub/entries/5/bookmark') {
                return _jsonResponse({'entry_id': 5, 'bookmarked': true});
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();

        expect(controller.documents.single.isBookmarked, isFalse);

        await controller.toggleBookmark('5');

        expect(controller.documents.single.isBookmarked, isTrue);
      },
    );

    test(
      'timeout keeps the user message retryable without assistant noise',
      () async {
        var askCount = 0;
        final controller = KnowledgeWorkspaceController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub') {
                return _jsonResponse(_hubJson());
              }
              if (request.method == 'GET' &&
                  request.url.path == '/api/knowledge-hub/conversations') {
                return _jsonResponse({'conversations': []});
              }
              if (request.method == 'POST' &&
                  request.url.path == '/api/knowledge-hub/ask') {
                askCount += 1;
                if (askCount == 1) {
                  throw TimeoutException('slow assistant');
                }
                return _jsonResponse({
                  'conversation': _conversationJson(id: 10),
                  'user_message': {
                    'id': 30,
                    'role': 'user',
                    'content': 'Cek akun S21+ saya',
                    'sources': [],
                  },
                  'assistant_message': {
                    'id': 31,
                    'role': 'assistant',
                    'content': 'Saya cekkan status akun S21+ Anda.',
                    'sources': [],
                  },
                });
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();
        await controller.ask('Cek akun S21+ saya');

        expect(controller.messages, hasLength(1));
        expect(controller.messages.single.isUser, isTrue);
        expect(controller.messages.single.text, 'Cek akun S21+ saya');
        expect(controller.canRetryLastQuestion, isTrue);
        expect(controller.errorMessage, contains('Coba lagi'));

        await controller.retryLastQuestion();

        expect(askCount, 2);
        expect(controller.messages, hasLength(2));
        expect(controller.messages.first.text, 'Cek akun S21+ saya');
        expect(
          controller.messages.last.text,
          'Saya cekkan status akun S21+ Anda.',
        );
        expect(controller.canRetryLastQuestion, isFalse);
        expect(controller.errorMessage, isNull);
      },
    );
  });
}

AppSession _buildSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'user-1',
      name: 'Raihan Carjasti',
      email: 'raihan@example.com',
      roles: ['IT Staff'],
      permissions: ['view knowledge hub'],
    ),
    apiBaseUrl: 'http://localhost:8000',
    cookies: const {'gesit_session': 'session'},
    rememberSession: true,
    authenticatedAt: DateTime(2026, 4, 20, 9, 0),
  );
}

Map<String, dynamic> _hubJson({bool isBookmarked = true}) {
  return {
    'spaces': [
      {
        'id': 1,
        'name': 'Corporate Operations',
        'description': 'SOP dan workflow operasional.',
        'icon': 'apartment',
        'kind': 'division',
        'entry_count': 1,
        'sections': [
          {
            'id': 2,
            'knowledge_space_id': 1,
            'name': 'Procurement',
            'description': 'SOP pembelian',
            'entry_count': 1,
          },
        ],
      },
    ],
    'entries': [
      {
        'id': 5,
        'title': 'SOP Approval Pengadaan',
        'summary': 'Alur approval pengadaan.',
        'body': 'Requester isi form, head division review, finance validasi.',
        'type': 'sop',
        'type_label': 'SOP',
        'source_kind_label': 'Dokumen',
        'space_id': 1,
        'space_name': 'Corporate Operations',
        'section_id': 2,
        'section_name': 'Procurement',
        'path_label': 'Corporate Operations / Procurement',
        'owner_name': 'Operations Team',
        'attachment_url': '/storage/knowledge/sop.pdf',
        'attachment_name': 'sop.pdf',
        'attachment_mime': 'application/pdf',
        'is_bookmarked': isBookmarked,
        'updated_at': '2026-04-20T08:30:00.000000Z',
      },
    ],
    'suggested_questions': ['Ringkas SOP approval'],
  };
}

Map<String, dynamic> _conversationJson({int id = 7}) {
  return {
    'id': id,
    'title': 'Approval Pengadaan',
    'preview': 'Ini ringkasannya.',
    'message_count': 2,
    'updated_at': '2026-04-20T08:45:00.000000Z',
    'last_message_at': '2026-04-20T08:45:00.000000Z',
  };
}

Map<String, dynamic> _sourceJson() {
  return {
    'id': 5,
    'title': 'SOP Approval Pengadaan',
    'path_label': 'Corporate Operations / Procurement',
    'type_label': 'SOP',
  };
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
