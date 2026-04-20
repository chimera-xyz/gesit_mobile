import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/chat_store.dart';
import 'package:gesit_app/src/data/chat_workspace_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:gesit_app/src/screens/chat/chat_conversation_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'disposing conversation screen while send is in flight does not use disposed controllers',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      final sessionController = AppSessionController(
        apiClient: GesitApiClient(),
      );
      await sessionController.syncSession(_buildSession(), notify: false);
      final store = ChatStore();
      final responseGate = Completer<void>();

      final controller = ChatWorkspaceController(
        sessionController: sessionController,
        store: store,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/api/chat/workspace')) {
              return _jsonResponse({'workspace': _workspaceJson()});
            }
            if (request.url.path.endsWith('/api/chat/sync')) {
              return _jsonResponse({'last_event_id': 8, 'has_changes': false});
            }
            if (request.url.path.endsWith(
              '/api/chat/conversations/srv-1/messages',
            )) {
              await responseGate.future;
              return _jsonResponse({
                'workspace': _workspaceJson(
                  preview: 'Pesan async',
                  unreadCount: 0,
                  lastEventId: 8,
                  messages: [
                    _messageJson(
                      id: 'msg-1',
                      text: 'Halo dari server',
                      senderName: 'Nadia Finance',
                      isMine: false,
                      sentAt: '2026-04-19T08:15:00.000Z',
                    ),
                    _messageJson(
                      id: 'msg-2',
                      text: 'Pesan async',
                      senderName: 'Raihan Carjasti',
                      isMine: true,
                      sentAt: '2026-04-19T08:18:00.000Z',
                    ),
                  ],
                ),
              });
            }
            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );

      addTearDown(() async {
        controller.dispose();
        await store.clearWorkspace('test-user');
        sessionController.dispose();
      });

      await controller.ensureLoaded();

      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(
            controller: controller,
            conversationId: 'srv-1',
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Pesan async');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      responseGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
    },
  );
}

AppSession _buildSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'test-user',
      name: 'Raihan Carjasti',
      email: 'raihan@example.com',
      roles: ['Internal Ops'],
      permissions: ['view submissions', 'view forms'],
      department: 'Operations',
    ),
    apiBaseUrl: 'http://127.0.0.1:8000',
    cookies: const {},
    rememberSession: false,
    authenticatedAt: DateTime(2026, 4, 19),
  );
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _workspaceJson({
  String preview = 'Halo dari server',
  int unreadCount = 1,
  int lastEventId = 7,
  List<Map<String, dynamic>>? messages,
}) {
  return {
    'conversations': [
      {
        'id': 'srv-1',
        'title': 'Nadia Finance',
        'preview': preview,
        'timestamp': '08:15',
        'is_group': false,
        'accent_color': 4281427624,
        'subtitle': 'Finance',
        'unread_count': unreadCount,
        'is_pinned': false,
        'is_typing': false,
        'is_online': true,
        'is_muted': false,
        'updated_at': '2026-04-19T08:15:00.000Z',
      },
    ],
    'messages_by_conversation': {
      'srv-1':
          messages ??
          [
            _messageJson(
              id: 'msg-1',
              text: 'Halo dari server',
              senderName: 'Nadia Finance',
              isMine: false,
              sentAt: '2026-04-19T08:15:00.000Z',
            ),
          ],
    },
    'members_by_conversation': {
      'srv-1': [
        {
          'id': 'test-user',
          'name': 'Raihan Carjasti',
          'role': 'Internal Ops',
          'accent_color': 4288371479,
          'active': true,
          'is_current_user': true,
        },
        {
          'id': 'user-2',
          'name': 'Nadia Finance',
          'role': 'Finance',
          'accent_color': 4281427624,
          'active': true,
          'is_current_user': false,
        },
      ],
    },
    'assets_by_conversation': {'srv-1': []},
    'directory_members': [
      {
        'id': 'user-2',
        'name': 'Nadia Finance',
        'role': 'Finance',
        'accent_color': 4281427624,
        'active': true,
        'is_current_user': false,
      },
    ],
    'active_call': null,
    'last_event_id': lastEventId,
  };
}

Map<String, dynamic> _messageJson({
  required String id,
  required String text,
  required String senderName,
  required bool isMine,
  required String sentAt,
}) {
  return {
    'id': id,
    'text': text,
    'time_label': '08:15',
    'delivery': 'delivered',
    'sender_name': senderName,
    'is_mine': isMine,
    'is_system': false,
    'has_attachment': false,
    'is_voice_note': false,
    'sent_at': sentAt,
  };
}
