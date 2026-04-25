import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/notification_center_controller.dart';
import 'package:gesit_app/src/models/app_models.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationCenterController', () {
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

    test('ensureLoaded hydrates notifications from backend feed', () async {
      var streamRequests = 0;
      var alertPlays = 0;
      final controller = NotificationCenterController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/notifications') {
              return _jsonResponse({
                'notifications': [
                  _notificationJson(
                    id: 42,
                    title: 'Approval terbaru',
                    message: 'Pengajuan perjalanan dinas butuh approval.',
                    type: 'approval_needed',
                    link: '/submissions/42',
                  ),
                ],
                'unread_count': 1,
              });
            }

            if (request.method == 'GET' &&
                request.url.path == '/api/notifications/stream') {
              streamRequests += 1;
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }

            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
        foregroundAlertPlayer: () async {
          alertPlays += 1;
        },
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(controller.notifications, hasLength(1));
      expect(controller.notifications.single.id, '42');
      expect(controller.notifications.single.link, '/submissions/42');
      expect(controller.unreadCount, 1);
      expect(controller.activeBanner?.id, '42');
      expect(alertPlays, 1);
      expect(streamRequests, 0);
    });

    test(
      'realtime stream inserts new notifications and surfaces banner',
      () async {
        var streamServed = false;
        await sessionController.syncSession(
          _buildSession(apiBaseUrl: 'https://gesit.example.com'),
          notify: false,
        );

        final controller = NotificationCenterController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' &&
                  request.url.path == '/api/notifications') {
                return _jsonResponse({
                  'notifications': [
                    _notificationJson(
                      id: 10,
                      title: 'Riwayat lama',
                      message: 'Notifikasi lama tetap tampil.',
                      type: 'general',
                      link: '/helpdesk/10',
                      isRead: true,
                    ),
                  ],
                  'unread_count': 0,
                });
              }

              if (request.method == 'GET' &&
                  request.url.path == '/api/notifications/stream' &&
                  !streamServed) {
                streamServed = true;
                return http.Response(
                  'event: notifications\n'
                  'id: 11\n'
                  'data: ${jsonEncode({
                    'last_notification_id': 11,
                    'notifications': [_notificationJson(id: 11, title: 'Ticket IT diperbarui', message: 'Status tiket Anda berubah menjadi In Progress.', type: 'general', link: '/helpdesk/11')],
                  })}\n'
                  '\n',
                  200,
                  headers: {'content-type': 'text/event-stream'},
                );
              }

              if (request.method == 'GET' &&
                  request.url.path == '/api/notifications/stream') {
                return _jsonResponse({'message': 'Not found'}, statusCode: 404);
              }

              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
          foregroundAlertPlayer: () async {},
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();
        await pumpEventQueue(times: 4);

        expect(controller.notifications.first.id, '11');
        expect(controller.notifications.first.message, contains('In Progress'));
        expect(controller.activeBanner?.id, '11');
      },
    );

    test(
      'markChatConversationAsRead marks only matching chat notifications and keeps center entries',
      () async {
        final markedNotificationIds = <String>[];
        final controller = NotificationCenterController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'POST' &&
                  request.url.path == '/api/notifications/51/read') {
                markedNotificationIds.add('51');
                return _jsonResponse({
                  'notification': _notificationJson(
                    id: 51,
                    title: 'Budi IT',
                    message: 'Mengirim photo.',
                    type: 'general',
                    link: '/chat/conversations/abc',
                    isRead: true,
                  ),
                });
              }

              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }),
          ),
          initialNotifications: [
            AppNotification(
              id: '51',
              title: 'Budi IT',
              message: 'Mengirim photo.',
              detail: 'Chat baru',
              type: AppNotificationType.chat,
              createdAt: DateTime.parse('2026-04-23T10:15:00.000Z'),
              destination: NotificationDestination.chat,
              link: '/chat/conversations/abc',
            ),
            AppNotification(
              id: '52',
              title: 'Budi IT',
              message: 'Mengirim file.',
              detail: 'Chat baru',
              type: AppNotificationType.chat,
              createdAt: DateTime.parse('2026-04-23T10:16:00.000Z'),
              destination: NotificationDestination.chat,
              link: '/chat/conversations/xyz',
            ),
            AppNotification(
              id: '53',
              title: 'Ticket IT',
              message: 'Status berubah.',
              detail: 'Helpdesk',
              type: AppNotificationType.helpdesk,
              createdAt: DateTime.parse('2026-04-23T10:17:00.000Z'),
              destination: NotificationDestination.helpdesk,
              link: '/helpdesk/88',
            ),
          ],
          foregroundAlertPlayer: () async {},
        );
        addTearDown(controller.dispose);

        await controller.markChatConversationAsRead('abc');

        expect(markedNotificationIds, ['51']);
        expect(controller.notificationById('51')?.isRead, isTrue);
        expect(controller.notificationById('52')?.isRead, isFalse);
        expect(controller.notificationById('53')?.isRead, isFalse);
        expect(controller.notifications, hasLength(3));
      },
    );
  });
}

AppSession _buildSession({String apiBaseUrl = 'http://127.0.0.1:8000'}) {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'test-user',
      name: 'Raihan Carjasti',
      email: 'raihan@example.com',
      roles: ['Employee'],
      permissions: ['view submissions', 'view forms', 'view helpdesk tickets'],
      department: 'Operations',
    ),
    apiBaseUrl: apiBaseUrl,
    cookies: const {'gesit_session': 'cookie-1'},
    rememberSession: true,
    authenticatedAt: DateTime.parse('2026-04-21T10:00:00.000Z'),
  );
}

Map<String, dynamic> _notificationJson({
  required int id,
  required String title,
  required String message,
  required String type,
  required String link,
  bool isRead = false,
}) {
  return {
    'id': id,
    'title': title,
    'message': message,
    'type': type,
    'link': link,
    'is_read': isRead,
    'created_at': '2026-04-21T10:15:00.000Z',
  };
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
