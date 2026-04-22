import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/notification_center_controller.dart';
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
              return _jsonResponse({'message': 'Not found'}, statusCode: 404);
            }

            return _jsonResponse({'message': 'Not found'}, statusCode: 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(controller.notifications, hasLength(1));
      expect(controller.notifications.single.id, '42');
      expect(controller.notifications.single.link, '/submissions/42');
      expect(controller.unreadCount, 1);
    });

    test(
      'realtime stream inserts new notifications and surfaces banner',
      () async {
        var streamServed = false;

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
                    ),
                  ],
                  'unread_count': 1,
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
        );
        addTearDown(controller.dispose);

        await controller.ensureLoaded();
        await pumpEventQueue(times: 4);

        expect(controller.notifications.first.id, '11');
        expect(controller.notifications.first.message, contains('In Progress'));
        expect(controller.activeBanner?.id, '11');
      },
    );
  });
}

AppSession _buildSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'test-user',
      name: 'Raihan Carjasti',
      email: 'raihan@example.com',
      roles: ['Employee'],
      permissions: ['view submissions', 'view forms', 'view helpdesk tickets'],
      department: 'Operations',
    ),
    apiBaseUrl: 'http://127.0.0.1:8000',
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
}) {
  return {
    'id': id,
    'title': title,
    'message': message,
    'type': type,
    'link': link,
    'is_read': false,
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
