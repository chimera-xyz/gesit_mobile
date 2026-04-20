import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/chat_store.dart';
import 'package:gesit_app/src/data/chat_workspace_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/models/app_models.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatWorkspaceController', () {
    late AppSessionController sessionController;
    late ChatStore store;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      sessionController = AppSessionController(apiClient: GesitApiClient());
      await sessionController.syncSession(_buildSession(), notify: false);
      store = ChatStore();
      await store.clearWorkspace('test-user');
    });

    tearDown(() async {
      await store.clearWorkspace('test-user');
      sessionController.dispose();
    });

    test(
      'ensureLoaded hydrates chat workspace from backend snapshot',
      () async {
        final controller = ChatWorkspaceController(
          sessionController: sessionController,
          store: store,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/api/chat/workspace')) {
                return _jsonResponse({'workspace': _workspaceJson()});
              }
              if (request.url.path.endsWith('/api/chat/sync')) {
                return _jsonResponse({
                  'last_event_id': 7,
                  'has_changes': false,
                });
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();

        final conversation = controller.conversationById('srv-1');
        expect(conversation, isNotNull);
        expect(conversation?.preview, 'Halo dari server');
        expect(
          controller.messagesFor('srv-1').last.senderName,
          'Nadia Finance',
        );
        expect(
          controller.directoryMembers.map((item) => item.name),
          contains('Nadia Finance'),
        );
      },
    );

    test(
      'ensureDirectConversation no longer creates local dummy chats',
      () async {
        await store.writeWorkspace(
          'test-user',
          ChatWorkspaceSnapshot.fromJson(
            _workspaceJson(
              conversations: const [],
              messagesByConversation: const {},
              membersByConversation: const {},
              assetsByConversation: const {},
              directoryMembers: [
                _directoryMemberJson(
                  id: 'user-2',
                  name: 'Nadia Finance',
                  role: 'Finance',
                ),
              ],
              lastEventId: 0,
            ),
          ),
        );

        final controller = ChatWorkspaceController(
          sessionController: sessionController,
          store: store,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              return _jsonResponse({
                'message': 'Chat backend belum aktif',
              }, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();

        expect(controller.directoryMembers, hasLength(1));
        await expectLater(
          controller.ensureDirectConversation(
            controller.directoryMembers.first,
          ),
          throwsA(
            isA<GesitApiException>().having(
              (error) => error.message,
              'message',
              contains('Kontak chat belum bisa dimuat dari server'),
            ),
          ),
        );
        expect(controller.conversations, isEmpty);
      },
    );

    test('sendTextMessage updates conversation from server response', () async {
      final sentBodies = <Map<String, dynamic>>[];
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
              sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
              return _jsonResponse({
                'workspace': _workspaceJson(
                  preview: 'Dokumen final vendor sudah saya approve.',
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
                      text: 'Dokumen final vendor sudah saya approve.',
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
      addTearDown(controller.dispose);

      await controller.ensureLoaded();
      await controller.sendTextMessage(
        'srv-1',
        'Dokumen final vendor sudah saya approve.',
      );

      expect(
        sentBodies.single['text'],
        'Dokumen final vendor sudah saya approve.',
      );
      expect(controller.messagesFor('srv-1'), hasLength(2));
      expect(
        controller.messagesFor('srv-1').last.text,
        'Dokumen final vendor sudah saya approve.',
      );
      expect(controller.messagesFor('srv-1').last.isMine, isTrue);
      expect(
        controller.conversationById('srv-1')?.preview,
        'Dokumen final vendor sudah saya approve.',
      );
    });

    test(
      '401 workspace response clears cached chat and invalidates session',
      () async {
        await store.writeWorkspace(
          'test-user',
          ChatWorkspaceSnapshot.fromJson(_workspaceJson()),
        );

        final controller = ChatWorkspaceController(
          sessionController: sessionController,
          store: store,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              return _jsonResponse({
                'message': 'Unauthorized',
              }, statusCode: 401);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();

        expect(sessionController.session, isNull);
        expect(sessionController.status, AppSessionStatus.unauthenticated);
        expect(controller.conversations, isEmpty);
        expect(controller.directoryMembers, isEmpty);
        expect(await store.readWorkspace('test-user'), isNull);
      },
    );

    test(
      'startOutgoingCall recovers the active remote call after 409',
      () async {
        var workspaceFetchCount = 0;

        final controller = ChatWorkspaceController(
          sessionController: sessionController,
          store: store,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/api/chat/workspace')) {
                workspaceFetchCount += 1;
                return _jsonResponse({
                  'workspace': _workspaceJson(
                    activeCall: workspaceFetchCount >= 2
                        ? _callJson(
                            id: 'call-409',
                            conversationId: 'srv-1',
                            type: 'voice',
                            status: 'ringing',
                            isIncoming: false,
                          )
                        : null,
                  ),
                });
              }
              if (request.url.path.endsWith('/api/chat/sync')) {
                return _jsonResponse({
                  'last_event_id': workspaceFetchCount + 7,
                  'has_changes': false,
                });
              }
              if (request.url.path.endsWith(
                '/api/chat/conversations/srv-1/calls',
              )) {
                return _jsonResponse({
                  'message': 'Call already active.',
                }, statusCode: 409);
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();

        final recoveredCall = await controller.startOutgoingCall(
          'srv-1',
          type: ChatCallType.voice,
        );

        expect(workspaceFetchCount, greaterThanOrEqualTo(2));
        expect(recoveredCall, isNotNull);
        expect(recoveredCall?.id, 'call-409');
        expect(recoveredCall?.status, ChatCallStatus.ringing);
        expect(recoveredCall?.isIncoming, isFalse);
        expect(controller.activeCall?.id, 'call-409');
      },
    );

    test(
      'refresh keeps local attachment path when server snapshot omits it',
      () async {
        await store.writeWorkspace(
          'test-user',
          ChatWorkspaceSnapshot.fromJson(
            _workspaceJson(
              preview: 'Foto',
              messages: [
                _attachmentMessageJson(
                  id: 'local-photo-1',
                  senderName: 'Raihan Carjasti',
                  isMine: true,
                  sentAt: '2026-04-19T08:18:00.000Z',
                  attachmentLabel: 'IMG_0001.jpg',
                  attachmentTypeLabel: 'Foto',
                  attachmentSizeLabel: '1.2 MB',
                  attachmentMimeType: 'image/jpeg',
                  attachmentLocalPath: '/tmp/chat/photo.jpg',
                ),
              ],
            ),
          ),
        );

        final controller = ChatWorkspaceController(
          sessionController: sessionController,
          store: store,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/api/chat/workspace')) {
                return _jsonResponse({
                  'workspace': _workspaceJson(
                    preview: 'Foto',
                    messages: [
                      _attachmentMessageJson(
                        id: 'remote-photo-1',
                        senderName: 'Raihan Carjasti',
                        isMine: true,
                        sentAt: '2026-04-19T08:18:00.000Z',
                        attachmentLabel: 'IMG_0001.jpg',
                        attachmentTypeLabel: 'Foto',
                        attachmentSizeLabel: '1.2 MB',
                        attachmentMimeType: 'image/jpeg',
                      ),
                    ],
                  ),
                });
              }
              if (request.url.path.endsWith('/api/chat/sync')) {
                return _jsonResponse({
                  'last_event_id': 8,
                  'has_changes': false,
                });
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();

        final syncedMessage = controller.messagesFor('srv-1').single;
        expect(syncedMessage.id, 'remote-photo-1');
        expect(syncedMessage.attachmentLocalPath, '/tmp/chat/photo.jpg');
        expect(syncedMessage.attachmentLabel, 'IMG_0001.jpg');
        expect(syncedMessage.hasAttachment, isTrue);
      },
    );

    test(
      'workspace events emit call signals and update remote media state',
      () async {
        final nextSignal = Completer<ChatCallSignalEvent>();

        final controller = ChatWorkspaceController(
          sessionController: sessionController,
          store: store,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/api/chat/workspace')) {
                return _jsonResponse({
                  'workspace': _workspaceJson(
                    activeCall: _callJson(
                      id: 'call-media-1',
                      conversationId: 'srv-1',
                      type: 'video',
                      status: 'active',
                      isIncoming: false,
                    ),
                  ),
                  'events': [
                    {
                      'id': 21,
                      'event_type': 'call.signal',
                      'conversation_id': 'srv-1',
                      'call_session_id': 'call-media-1',
                      'created_at': '2026-04-19T08:21:00.000Z',
                      'payload': {
                        'call_id': 'call-media-1',
                        'signal_type': 'media_state',
                        'from_user_id': 'user-2',
                        'payload': {
                          'mic_enabled': false,
                          'camera_enabled': false,
                        },
                      },
                    },
                  ],
                });
              }
              if (request.url.path.endsWith('/api/chat/sync')) {
                return _jsonResponse({
                  'last_event_id': 21,
                  'has_changes': false,
                });
              }
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
        );
        addTearDown(controller.dispose);

        final subscription = controller.callSignalStream.listen((signal) {
          if (!nextSignal.isCompleted) {
            nextSignal.complete(signal);
          }
        });
        addTearDown(subscription.cancel);

        await controller.ensureLoaded();

        final signal = await nextSignal.future;
        final remoteParticipant = controller.activeCall?.participants
            .firstWhere((participant) => participant.id == 'user-2');

        expect(signal.callId, 'call-media-1');
        expect(signal.signalType, 'media_state');
        expect(signal.fromUserId, 'user-2');
        expect(remoteParticipant, isNotNull);
        expect(remoteParticipant?.isMuted, isTrue);
        expect(remoteParticipant?.isVideoEnabled, isFalse);
      },
    );

    test('sendActiveCallSignal posts generic call signaling payload', () async {
      Map<String, dynamic>? sentSignalBody;

      final controller = ChatWorkspaceController(
        sessionController: sessionController,
        store: store,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/api/chat/workspace')) {
              return _jsonResponse({
                'workspace': _workspaceJson(
                  activeCall: _callJson(
                    id: 'call-signal-1',
                    conversationId: 'srv-1',
                    type: 'voice',
                    status: 'ringing',
                    isIncoming: false,
                  ),
                ),
              });
            }
            if (request.url.path.endsWith('/api/chat/sync')) {
              return _jsonResponse({'last_event_id': 7, 'has_changes': false});
            }
            if (request.url.path.endsWith(
              '/api/chat/calls/call-signal-1/signal',
            )) {
              sentSignalBody = jsonDecode(request.body) as Map<String, dynamic>;
              return _jsonResponse({
                'workspace': _workspaceJson(
                  activeCall: _callJson(
                    id: 'call-signal-1',
                    conversationId: 'srv-1',
                    type: 'voice',
                    status: 'ringing',
                    isIncoming: false,
                  ),
                ),
              });
            }
            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();
      await controller.sendActiveCallSignal(
        'offer',
        payload: const {'sdp': 'fake-offer-sdp'},
      );

      expect(sentSignalBody, isNotNull);
      expect(sentSignalBody?['type'], 'offer');
      expect(sentSignalBody?['payload'], {'sdp': 'fake-offer-sdp'});
    });
  });
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
  List<Map<String, dynamic>>? conversations,
  Map<String, List<Map<String, dynamic>>>? messagesByConversation,
  Map<String, List<Map<String, dynamic>>>? membersByConversation,
  Map<String, List<Map<String, dynamic>>>? assetsByConversation,
  List<Map<String, dynamic>>? directoryMembers,
  List<Map<String, dynamic>>? messages,
  Map<String, dynamic>? activeCall,
}) {
  return {
    'conversations':
        conversations ??
        [
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
    'messages_by_conversation':
        messagesByConversation ??
        {
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
    'members_by_conversation':
        membersByConversation ??
        {
          'srv-1': [
            _directoryMemberJson(
              id: 'test-user',
              name: 'Raihan Carjasti',
              role: 'Internal Ops',
              accentColor: 4288371479,
              isCurrentUser: true,
            ),
            _directoryMemberJson(
              id: 'user-2',
              name: 'Nadia Finance',
              role: 'Finance',
            ),
          ],
        },
    'assets_by_conversation': assetsByConversation ?? {'srv-1': []},
    'directory_members':
        directoryMembers ??
        [
          _directoryMemberJson(
            id: 'user-2',
            name: 'Nadia Finance',
            role: 'Finance',
          ),
        ],
    'active_call': activeCall,
    'last_event_id': lastEventId,
  };
}

Map<String, dynamic> _directoryMemberJson({
  required String id,
  required String name,
  required String role,
  int accentColor = 4281427624,
  bool active = true,
  bool isCurrentUser = false,
}) {
  return {
    'id': id,
    'name': name,
    'role': role,
    'accent_color': accentColor,
    'active': active,
    'is_current_user': isCurrentUser,
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

Map<String, dynamic> _attachmentMessageJson({
  required String id,
  required String senderName,
  required bool isMine,
  required String sentAt,
  required String attachmentLabel,
  required String attachmentTypeLabel,
  required String attachmentSizeLabel,
  required String attachmentMimeType,
  String text = '',
  String? attachmentLocalPath,
}) {
  return {
    'id': id,
    'text': text,
    'time_label': '08:18',
    'delivery': 'delivered',
    'sender_name': senderName,
    'is_mine': isMine,
    'is_system': false,
    'has_attachment': true,
    'attachment_label': attachmentLabel,
    'attachment_type_label': attachmentTypeLabel,
    'attachment_size_label': attachmentSizeLabel,
    'attachment_url': '/storage/chat-attachments/$attachmentLabel',
    'attachment_mime_type': attachmentMimeType,
    'attachment_local_path': attachmentLocalPath,
    'is_voice_note': false,
    'sent_at': sentAt,
  };
}

Map<String, dynamic> _callJson({
  required String id,
  required String conversationId,
  required String type,
  required String status,
  required bool isIncoming,
}) {
  return {
    'id': id,
    'conversation_id': conversationId,
    'title': 'Nadia Finance',
    'subtitle': 'Finance',
    'is_group': false,
    'type': type,
    'status': status,
    'is_incoming': isIncoming,
    'created_at': '2026-04-19T08:20:00.000Z',
    'participants': [
      {
        'id': 'test-user',
        'name': 'Raihan Carjasti',
        'role': 'Internal Ops',
        'accent_color': 4288371479,
        'is_current_user': true,
        'is_muted': false,
        'is_video_enabled': false,
        'is_connected': true,
      },
      {
        'id': 'user-2',
        'name': 'Nadia Finance',
        'role': 'Finance',
        'accent_color': 4281427624,
        'is_current_user': false,
        'is_muted': false,
        'is_video_enabled': false,
        'is_connected': true,
      },
    ],
    'speaker_enabled': true,
    'mic_enabled': true,
    'camera_enabled': false,
  };
}
