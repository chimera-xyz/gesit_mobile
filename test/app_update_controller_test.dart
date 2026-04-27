import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/config/app_runtime_config.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/app_update_controller.dart';
import 'package:gesit_app/src/data/app_update_file_store_types.dart';
import 'package:gesit_app/src/data/app_update_models.dart';
import 'package:gesit_app/src/data/app_update_platform_service.dart';
import 'package:gesit_app/src/data/app_update_service.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateController', () {
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

    test('bootstrap exposes required update from backend', () async {
      final service = _FakeAppUpdateService(
        result: AppUpdateCheckResult(
          availability: AppUpdateAvailability.requiredUpdate,
          currentBuild: const InstalledAppBuild(
            versionName: '1.0.0',
            versionCode: 1,
            packageName: 'com.yuliesekuritas.gesit',
          ),
          release: const AppUpdateRelease(
            id: 10,
            platform: 'android',
            channel: 'production',
            versionName: '1.1.0',
            versionCode: 2,
            minimumSupportedVersionCode: 2,
            apkFileName: 'gesit-v2.apk',
            fileSize: 120,
            sha256: 'abc',
            downloadUrl: 'https://example.com/releases/10.apk',
          ),
        ),
      );
      final controller = AppUpdateController(
        sessionController: sessionController,
        updateService: service,
        platformService: _FakePlatformService(),
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.isRequired, isTrue);
      expect(controller.shouldShowPrompt, isTrue);
      expect(controller.release?.versionCode, 2);
      expect(controller.currentBuild?.versionCode, 1);
      expect(
        service.lastCheckedBaseUrl,
        AppRuntimeConfig.normalizePersistedBaseUrl(_buildSession().apiBaseUrl),
      );
    });

    test('beginUpdate asks for permission before downloading APK', () async {
      final service = _FakeAppUpdateService(
        result: AppUpdateCheckResult(
          availability: AppUpdateAvailability.requiredUpdate,
          currentBuild: const InstalledAppBuild(
            versionName: '1.0.0',
            versionCode: 1,
            packageName: 'com.yuliesekuritas.gesit',
          ),
          release: const AppUpdateRelease(
            id: 11,
            platform: 'android',
            channel: 'production',
            versionName: '1.2.0',
            versionCode: 3,
            minimumSupportedVersionCode: 3,
            apkFileName: 'gesit-v3.apk',
            fileSize: 120,
            sha256: 'abc',
            downloadUrl: 'https://example.com/releases/11.apk',
          ),
        ),
      );

      final platform = _FakePlatformService(canInstallPackages: false);
      final controller = AppUpdateController(
        sessionController: sessionController,
        updateService: service,
        platformService: platform,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();
      await controller.beginUpdate();

      expect(controller.needsInstallPermission, isTrue);
      expect(service.downloadInvocations, 0);
      expect(platform.installInvocations, 0);
    });

    test(
      'optional update can be dismissed even when release minimum is high',
      () async {
        final controller = AppUpdateController(
          sessionController: sessionController,
          updateService: _FakeAppUpdateService(
            result: AppUpdateCheckResult(
              availability: AppUpdateAvailability.optionalUpdate,
              currentBuild: const InstalledAppBuild(
                versionName: '1.0.0',
                versionCode: 1,
                packageName: 'com.yuliesekuritas.gesit',
              ),
              release: const AppUpdateRelease(
                id: 12,
                platform: 'android',
                channel: 'production',
                versionName: '1.3.0',
                versionCode: 4,
                minimumSupportedVersionCode: 4,
                apkFileName: 'gesit-v4.apk',
                fileSize: 120,
                sha256: 'abc',
                downloadUrl: 'https://example.com/releases/12.apk',
              ),
            ),
          ),
          platformService: _FakePlatformService(),
        );
        addTearDown(controller.dispose);

        await controller.bootstrap();

        expect(controller.isOptional, isTrue);
        expect(controller.isRequired, isFalse);
        expect(controller.shouldShowPrompt, isTrue);

        controller.dismissOptionalUpdate();

        expect(controller.shouldShowPrompt, isFalse);
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
      permissions: ['view submissions'],
      department: 'Operations',
    ),
    apiBaseUrl: 'http://127.0.0.1:8000',
    cookies: const {'gesit_session': 'cookie-1'},
    rememberSession: true,
    authenticatedAt: DateTime.parse('2026-04-22T10:00:00.000Z'),
  );
}

class _FakeAppUpdateService extends AppUpdateService {
  _FakeAppUpdateService({required this.result}) : super();

  final AppUpdateCheckResult result;
  int downloadInvocations = 0;
  String? lastCheckedBaseUrl;

  @override
  Future<AppUpdateCheckResult> checkForUpdate({required String baseUrl}) async {
    lastCheckedBaseUrl = baseUrl;
    return result;
  }

  @override
  Future<AppUpdateDownloadArtifact> downloadRelease(
    AppUpdateRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    downloadInvocations += 1;
    onProgress(1);
    return const AppUpdateDownloadArtifact(
      filePath: '/tmp/gesit.apk',
      fileSize: 120,
      sha256: 'abc',
    );
  }

  @override
  void dispose() {}
}

class _FakePlatformService implements AppUpdatePlatformService {
  _FakePlatformService({this.canInstallPackages = true});

  final bool canInstallPackages;
  int installInvocations = 0;

  @override
  Future<bool> canRequestPackageInstalls() async => canInstallPackages;

  @override
  Future<void> installApk(String filePath) async {
    installInvocations += 1;
  }

  @override
  Future<void> openUnknownAppSourcesSettings() async {}
}
