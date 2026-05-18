import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/home_banner_controller.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeBannerController', () {
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

    test('ensureLoaded hydrates active home banners', () async {
      late http.Request capturedRequest;

      final controller = HomeBannerController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return _jsonResponse({
              'banners': [
                {
                  'id': '1',
                  'title': 'Selamat Datang di GESIT',
                  'subtitle': 'Internal workspace',
                  'image_url': '/images/home-banners/gesit-welcome.png',
                  'action_type': 'none',
                  'sort_order': 1,
                },
                {
                  'id': '2',
                  'title': 'Satu Workspace',
                  'image_url': 'https://gesit.test/banner.png',
                  'action_type': 'forms',
                  'sort_order': 2,
                },
              ],
            });
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(capturedRequest.url.path, '/api/mobile/home-banners');
      expect(capturedRequest.headers['cookie'], contains('laravel_session'));
      expect(controller.banners, hasLength(2));
      expect(controller.banners.first.title, 'Selamat Datang di GESIT');
      expect(
        controller.banners.first.resolvedImageUrl('http://localhost:8000'),
        'http://localhost:8000/images/home-banners/gesit-welcome.png',
      );
      expect(controller.banners.last.hasAction, isTrue);
    });

    test('empty response keeps home banner layout hidden', () async {
      final controller = HomeBannerController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            return _jsonResponse({'banners': []});
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(controller.banners, isEmpty);
      expect(controller.loaded, isTrue);
      expect(controller.error, isNull);
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
    authenticatedAt: DateTime(2026, 5, 16, 8, 30),
  );
}

http.Response _jsonResponse(
  Map<String, dynamic> payload, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(payload),
    statusCode,
    headers: {
      'content-type': 'application/json',
      'set-cookie': 'laravel_session=fresh-cookie; Path=/; HttpOnly',
    },
  );
}
