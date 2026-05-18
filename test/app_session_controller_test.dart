import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/config/app_runtime_config.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/session_store.dart';
import 'package:gesit_app/src/data/server_endpoint_resolver.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final migratedApiBaseUrl = AppRuntimeConfig.defaultApiBaseUrl;

  group('AppSessionController', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test(
      'bootstrap migrates an existing browser-managed session snapshot off loopback',
      () async {
        await SessionStore.writeApiBaseUrl('http://localhost:8000');
        await SessionStore.writeRememberSession(true);
        await SessionStore.writeSession(
          AppSession(
            user: const AuthenticatedUser(
              id: 'user-1',
              name: 'Raihan Carjasti',
              email: 'raihan@example.com',
              roles: ['IT Staff'],
              permissions: ['view submissions'],
            ),
            apiBaseUrl: 'http://localhost:8000',
            cookies: const {},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 30),
          ),
        );

        final controller = AppSessionController(
          apiClient: GesitApiClient(
            browserManagedCookies: true,
            httpClient: MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.toString(), '$migratedApiBaseUrl/api/user');
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
          endpointResolver: _reachableEndpointResolver(),
        );
        addTearDown(controller.dispose);

        await controller.bootstrap();

        expect(controller.status, AppSessionStatus.authenticated);
        expect(controller.session?.apiBaseUrl, migratedApiBaseUrl);
        expect(controller.session?.user.email, 'raihan@example.com');
        expect(controller.session?.rememberSession, isTrue);
        expect(await SessionStore.readApiBaseUrl(), migratedApiBaseUrl);
        expect(
          (await SessionStore.readSession())?.apiBaseUrl,
          migratedApiBaseUrl,
        );
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
          endpointResolver: _reachableEndpointResolver(),
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

    test(
      'bootstrap keeps a stored session when the backend cannot be reached',
      () async {
        final storedSession = AppSession(
          user: const AuthenticatedUser(
            id: 'user-1',
            name: 'Raihan Carjasti',
            email: 'raihan@example.com',
            roles: ['IT Staff'],
            permissions: ['view submissions'],
          ),
          apiBaseUrl: 'http://localhost:8000',
          cookies: const {'gesit_session': 'stored-session'},
          rememberSession: true,
          authenticatedAt: DateTime(2026, 4, 19, 8, 30),
        );
        await SessionStore.writeRememberSession(true);
        await SessionStore.writeSession(storedSession);

        final controller = AppSessionController(
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              throw TimeoutException('backend timeout');
            }),
          ),
          endpointResolver: _reachableEndpointResolver(),
        );
        addTearDown(controller.dispose);

        await controller.bootstrap();

        expect(controller.status, AppSessionStatus.authenticated);
        expect(controller.session?.user.email, 'raihan@example.com');
        expect(controller.session?.cookies['gesit_session'], 'stored-session');
        expect(await SessionStore.readSession(), isNotNull);
      },
    );

    test(
      'bootstrap keeps a stored session without prompting when endpoint discovery fails',
      () async {
        await SessionStore.writeRememberSession(true);
        await SessionStore.writeSession(
          AppSession(
            user: const AuthenticatedUser(
              id: 'user-1',
              name: 'Raihan Carjasti',
              email: 'raihan@example.com',
              roles: ['IT Staff'],
              permissions: ['view submissions'],
            ),
            apiBaseUrl: 'http://localhost:8000',
            cookies: const {'gesit_session': 'stored-session'},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 30),
          ),
        );

        final controller = AppSessionController(
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              fail('bootstrap should not fetch the user before reconnecting');
            }),
          ),
          endpointResolver: ServerEndpointResolver(
            probe: (baseUrl, timeout) async => false,
          ),
        );
        addTearDown(controller.dispose);

        await controller.bootstrap();

        expect(controller.status, AppSessionStatus.authenticated);
        expect(controller.session?.cookies['gesit_session'], 'stored-session');
      },
    );

    test(
      'stale unauthorized responses cannot invalidate a newer session',
      () async {
        final controller = AppSessionController(
          apiClient: GesitApiClient(),
          endpointResolver: _reachableEndpointResolver(),
        );
        addTearDown(controller.dispose);

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
            cookies: const {'gesit_session': 'old-session'},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 30),
          ),
          notify: false,
        );
        final staleSession = controller.session!;

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
            cookies: const {'gesit_session': 'new-session'},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 31),
          ),
          notify: false,
        );

        await controller.invalidateSession(
          errorMessage: 'Unauthenticated.',
          expectedSession: staleSession,
        );

        expect(controller.status, AppSessionStatus.authenticated);
        expect(controller.session?.cookies['gesit_session'], 'new-session');
        expect(controller.errorMessage, isNull);
      },
    );

    test(
      'current unauthorized responses expose a friendly session message',
      () async {
        final controller = AppSessionController(
          apiClient: GesitApiClient(),
          endpointResolver: _reachableEndpointResolver(),
        );
        addTearDown(controller.dispose);

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
            cookies: const {'gesit_session': 'current-session'},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 30),
          ),
          notify: false,
        );

        await controller.invalidateSession(
          errorMessage: 'Unauthenticated.',
          expectedSession: controller.session,
        );

        expect(controller.status, AppSessionStatus.unauthenticated);
        expect(
          controller.errorMessage,
          'Sesi login berakhir. Silakan masuk lagi.',
        );
      },
    );

    test(
      'bootstrap clears a stored session when the server rejects it',
      () async {
        await SessionStore.writeRememberSession(true);
        await SessionStore.writeSession(
          AppSession(
            user: const AuthenticatedUser(
              id: 'user-1',
              name: 'Raihan Carjasti',
              email: 'raihan@example.com',
              roles: ['IT Staff'],
              permissions: ['view submissions'],
            ),
            apiBaseUrl: 'http://localhost:8000',
            cookies: const {'gesit_session': 'expired-session'},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 30),
          ),
        );

        final controller = AppSessionController(
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              return _jsonResponse({
                'message': 'Unauthenticated.',
              }, statusCode: 401);
            }),
          ),
          endpointResolver: _reachableEndpointResolver(),
        );
        addTearDown(controller.dispose);

        await controller.bootstrap();

        expect(controller.status, AppSessionStatus.unauthenticated);
        expect(controller.session, isNull);
        expect(await SessionStore.readSession(), isNull);
      },
    );

    test(
      'bootstrap migrates the legacy Tailscale API route to the configured endpoint',
      () async {
        final probes = <String>[];
        await SessionStore.writeRememberSession(true);
        await SessionStore.writeSession(
          AppSession(
            user: const AuthenticatedUser(
              id: 'user-1',
              name: 'Raihan Carjasti',
              email: 'raihan@example.com',
              roles: ['IT Staff'],
              permissions: ['view submissions'],
            ),
            apiBaseUrl: 'http://100.64.7.96:8000',
            cookies: const {'gesit_session': 'stored-session'},
            rememberSession: true,
            authenticatedAt: DateTime(2026, 4, 19, 8, 30),
          ),
        );

        final controller = AppSessionController(
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              expect(
                request.url.toString(),
                '${AppRuntimeConfig.defaultApiBaseUrl}/api/user',
              );
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
          endpointResolver: ServerEndpointResolver(
            probe: (baseUrl, timeout) async {
              probes.add(baseUrl);
              return baseUrl == AppRuntimeConfig.defaultApiBaseUrl;
            },
          ),
        );
        addTearDown(controller.dispose);

        await controller.bootstrap();

        expect(controller.status, AppSessionStatus.authenticated);
        expect(
          controller.session?.apiBaseUrl,
          AppRuntimeConfig.defaultApiBaseUrl,
        );
        expect(probes, [AppRuntimeConfig.defaultApiBaseUrl]);
      },
    );

    test(
      'signIn returns a connection error when the configured endpoint is unreachable',
      () async {
        final controller = AppSessionController(
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              fail('sign in should not run before a server is resolved');
            }),
          ),
          endpointResolver: ServerEndpointResolver(
            probe: (baseUrl, timeout) async => false,
          ),
        );
        addTearDown(controller.dispose);

        await controller.signIn(
          email: 'raihan@example.com',
          password: 'super-secret',
          rememberSession: true,
        );

        expect(controller.status, AppSessionStatus.unauthenticated);
        expect(
          controller.errorMessage,
          'GESIT belum bisa terhubung ke server. Periksa alamat API atau jaringan Anda.',
        );
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

ServerEndpointResolver _reachableEndpointResolver() {
  return ServerEndpointResolver(probe: (baseUrl, timeout) async => true);
}
