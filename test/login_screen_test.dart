import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/device_biometric_service.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/screens/login_screen.dart';
import 'package:gesit_app/src/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'keeps the divider and help CTA visible when fingerprint is unavailable',
    (tester) async {
      final sessionController = AppSessionController(
        apiClient: GesitApiClient(httpClient: http.Client()),
      );
      addTearDown(sessionController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LoginScreen(
            sessionController: sessionController,
            deviceBiometricService: _FakeDeviceBiometricService(
              isSupportedResult: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('atau'), findsOneWidget);
      expect(find.text('Butuh Bantuan Akses'), findsOneWidget);
      expect(find.text('Masuk dengan Fingerprint'), findsNothing);
      expect(find.text('Alamat API'), findsNothing);
    },
  );

  testWidgets('shows fingerprint CTA when Android biometrics are supported', (
    tester,
  ) async {
    final sessionController = AppSessionController(
      apiClient: GesitApiClient(httpClient: http.Client()),
    );
    addTearDown(sessionController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LoginScreen(
          sessionController: sessionController,
          deviceBiometricService: _FakeDeviceBiometricService(
            isSupportedResult: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('atau'), findsOneWidget);
    expect(find.text('Masuk dengan Fingerprint'), findsOneWidget);
    expect(find.text('Butuh Bantuan Akses'), findsOneWidget);
  });

  testWidgets('validates login fields before posting to auth API', (
    tester,
  ) async {
    var authRequestCount = 0;
    final sessionController = AppSessionController(
      apiClient: GesitApiClient(
        httpClient: MockClient((request) async {
          authRequestCount += 1;
          return http.Response('Unexpected auth request', 500);
        }),
      ),
    );
    addTearDown(sessionController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LoginScreen(
          sessionController: sessionController,
          deviceBiometricService: _FakeDeviceBiometricService(
            isSupportedResult: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk ke Workspace'));
    await tester.pump();

    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(authRequestCount, 0);
  });
}

class _FakeDeviceBiometricService extends DeviceBiometricService {
  _FakeDeviceBiometricService({required this.isSupportedResult});

  final bool isSupportedResult;

  @override
  bool get supportsBiometricLoginUi => true;

  @override
  String get platformValue => 'android';

  @override
  String get defaultDeviceName => 'GESIT Android';

  @override
  Future<bool> isSupported() async => isSupportedResult;

  @override
  Future<bool> authenticate({required String localizedReason}) async => false;
}
