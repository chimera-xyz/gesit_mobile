import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/session_store.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSessionController', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test(
      'bootstrap restores an existing browser-managed session snapshot',
      () async {
        await SessionStore.writeApiBaseUrl('http://localhost:8000');
        await SessionStore.writeRememberSession(true);

        final controller = AppSessionController(
          apiClient: GesitApiClient(
            browserManagedCookies: true,
            httpClient: MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.toString(), 'http://localhost:8000/api/user');
              expect(request.headers['accept'], 'application/json');
              expect(request.headers.containsKey('x-requested-with'), isFalse);

              return _jsonResponse({
                'user': {
                  'id': 'user-1',
                  'name': 'Raihan Carjasti',
                  'email': 'raihan@example.com',
                },
                'roles': ['IT Staff'],
                'permissions': ['view submissions'],
              });
            }),
          ),
          browserManagedCookies: true,
        );
        addTearDown(controller.dispose);

        await controller.bootstrap();

        expect(controller.status, AppSessionStatus.authenticated);
        expect(controller.session?.apiBaseUrl, 'http://localhost:8000');
        expect(controller.session?.user.email, 'raihan@example.com');
        expect(controller.session?.rememberSession, isTrue);
        expect(await SessionStore.readSession(), isNotNull);
      },
    );

    test(
      'signOut clears local session before remote logout completes',
      () async {
        final logoutRequested = Completer<void>();
        final releaseLogout = Completer<void>();

        final controller = AppSessionController(
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              expect(request.method, 'POST');
              expect(
                request.url.toString(),
                'http://localhost:8000/api/auth/logout',
              );
              if (!logoutRequested.isCompleted) {
                logoutRequested.complete();
              }
              await releaseLogout.future;
              return http.Response('', 204);
            }),
          ),
        );
        addTearDown(controller.dispose);

        await SessionStore.writeRememberSession(true);
        await controller.syncSession(
          AppSession(
            user: const AuthenticatedUser(
              id: 'user-1',
              name: 'Raihan Carjasti',
              email: 'raihan@example.com',
              roles: ['IT Staff'],
              permissions: ['view submissions'],
            ),
            apiBaseUrl: 'http://localhost:8000',
            cookies: const {'laravel_session': 'cookie'},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 30),
          ),
          notify: false,
        );

        await controller.signOut();

        expect(controller.status, AppSessionStatus.unauthenticated);
        expect(controller.session, isNull);
        expect(controller.isBusy, isFalse);
        expect(controller.rememberSession, isFalse);
        expect(await SessionStore.readSession(), isNull);
        expect(await SessionStore.readRememberSession(), isFalse);

        await logoutRequested.future;
        releaseLogout.complete();
      },
    );
  });

  group('GesitApiClient', () {
    test(
      'uses form-encoded auth requests for browser-managed cookies',
      () async {
        final client = GesitApiClient(
          browserManagedCookies: true,
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.toString(),
              'http://localhost:8000/api/auth/login',
            );
            expect(
              request.headers['content-type'],
              startsWith('application/x-www-form-urlencoded'),
            );
            expect(request.headers.containsKey('x-requested-with'), isFalse);
            expect(request.bodyFields, {
              'email': 'raihan@example.com',
              'password': 'super-secret',
              'remember': '1',
            });

            return _jsonResponse({
              'user': {
                'id': 'user-1',
                'name': 'Raihan Carjasti',
                'email': 'raihan@example.com',
              },
              'roles': ['IT Staff'],
              'permissions': ['view submissions'],
            });
          }),
        );
        addTearDown(client.close);

        final payload = await client.signIn(
          baseUrl: 'http://localhost:8000',
          email: 'raihan@example.com',
          password: 'super-secret',
          rememberSession: true,
        );

        expect(payload.user.email, 'raihan@example.com');
      },
    );

    test('keeps JSON auth requests for non-browser clients', () async {
      final client = GesitApiClient(
        browserManagedCookies: false,
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {
            'email': 'raihan@example.com',
            'password': 'super-secret',
            'remember': false,
          });

          return _jsonResponse({
            'user': {
              'id': 'user-1',
              'name': 'Raihan Carjasti',
              'email': 'raihan@example.com',
            },
            'roles': ['IT Staff'],
            'permissions': ['view submissions'],
          });
        }),
      );
      addTearDown(client.close);

      final payload = await client.signIn(
        baseUrl: 'http://localhost:8000',
        email: 'raihan@example.com',
        password: 'super-secret',
        rememberSession: false,
      );

      expect(payload.user.email, 'raihan@example.com');
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
