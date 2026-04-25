import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_runtime_config.dart';
import 'app_session_controller.dart';
import 'app_update_models.dart';
import 'app_update_platform_service.dart';
import 'app_update_service.dart';
import 'session_store.dart';

enum AppUpdateActionState { idle, checking, permissionRequired, downloading }

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required AppSessionController sessionController,
    AppUpdateService? updateService,
    AppUpdatePlatformService? platformService,
  }) : _sessionController = sessionController,
       _updateService = updateService ?? AppUpdateService(),
       _platformService =
           platformService ?? MethodChannelAppUpdatePlatformService() {
    _observedBaseUrl = sessionController.apiBaseUrlDraft;
    sessionController.addListener(_handleSessionControllerChanged);
  }

  final AppSessionController _sessionController;
  final AppUpdateService _updateService;
  final AppUpdatePlatformService _platformService;

  InstalledAppBuild? _currentBuild;
  AppUpdateRelease? _release;
  AppUpdateAvailability _availability = AppUpdateAvailability.unavailable;
  AppUpdateActionState _actionState = AppUpdateActionState.idle;
  String? _errorMessage;
  String? _statusMessage;
  bool _bootstrapping = false;
  bool _initialCheckCompleted = false;
  bool _disposed = false;
  double _downloadProgress = 0;
  int? _dismissedOptionalVersionCode;
  String? _observedBaseUrl;
  DateTime? _lastCheckedAt;
  Timer? _recheckDebounce;

  InstalledAppBuild? get currentBuild => _currentBuild;

  AppUpdateRelease? get release => _release;

  AppUpdateAvailability get availability => _availability;

  AppUpdateActionState get actionState => _actionState;

  String? get errorMessage => _errorMessage;

  String? get statusMessage => _statusMessage;

  double get downloadProgress => _downloadProgress;

  bool get isBootstrapping => _bootstrapping && !_initialCheckCompleted;

  bool get isBusy =>
      _actionState == AppUpdateActionState.checking ||
      _actionState == AppUpdateActionState.downloading;

  bool get isDownloading => _actionState == AppUpdateActionState.downloading;

  bool get needsInstallPermission =>
      _actionState == AppUpdateActionState.permissionRequired;

  bool get isRequired => _availability == AppUpdateAvailability.requiredUpdate;

  bool get isOptional => _availability == AppUpdateAvailability.optionalUpdate;

  bool get isSupported => _supportsSelfHostedAndroidUpdate;

  bool get shouldShowPrompt {
    if (!isSupported || _release == null) {
      return false;
    }

    if (isRequired) {
      return true;
    }

    if (needsInstallPermission || isDownloading) {
      return true;
    }

    if (isOptional) {
      return _dismissedOptionalVersionCode != _release?.versionCode;
    }

    return false;
  }

  Future<void> bootstrap() async {
    if (_bootstrapping || _initialCheckCompleted) {
      return;
    }

    _bootstrapping = true;
    notifyListeners();

    try {
      await checkForUpdates();
    } finally {
      _bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> checkForUpdates({String? baseUrlOverride}) async {
    if (!isSupported) {
      _availability = AppUpdateAvailability.unsupported;
      _actionState = AppUpdateActionState.idle;
      _errorMessage = null;
      _statusMessage = null;
      _initialCheckCompleted = true;
      notifyListeners();
      return;
    }

    _actionState = AppUpdateActionState.checking;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final baseUrl = AppRuntimeConfig.normalizePersistedBaseUrl(
        baseUrlOverride ?? await SessionStore.readApiBaseUrl(),
      );
      _observedBaseUrl = baseUrl;

      final result = await _updateService.checkForUpdate(baseUrl: baseUrl);
      final previousOptionalVersion = _release?.versionCode;

      _currentBuild = result.currentBuild;
      _release = result.release;
      _availability = result.availability;
      _actionState = AppUpdateActionState.idle;
      _downloadProgress = 0;
      _lastCheckedAt = DateTime.now();

      if (_release?.versionCode != previousOptionalVersion) {
        _dismissedOptionalVersionCode = null;
      }
    } on AppUpdateException catch (error) {
      _availability = AppUpdateAvailability.unavailable;
      _actionState = AppUpdateActionState.idle;
      _errorMessage = error.message;
    } catch (_) {
      _availability = AppUpdateAvailability.unavailable;
      _actionState = AppUpdateActionState.idle;
      _errorMessage = 'Pemeriksaan versi aplikasi gagal.';
    } finally {
      _initialCheckCompleted = true;
      notifyListeners();
    }
  }

  Future<void> refreshIfStale({bool force = false}) async {
    if (!isSupported || isBusy) {
      return;
    }

    if (!force &&
        _lastCheckedAt != null &&
        DateTime.now().difference(_lastCheckedAt!) <
            const Duration(minutes: 5)) {
      return;
    }

    await checkForUpdates(baseUrlOverride: _observedBaseUrl);
  }

  Future<void> beginUpdate() async {
    final currentRelease = _release;
    if (currentRelease == null || !isSupported || isDownloading) {
      return;
    }

    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    final permissionGranted = await _platformService
        .canRequestPackageInstalls();
    if (!permissionGranted) {
      _actionState = AppUpdateActionState.permissionRequired;
      _statusMessage =
          'Android perlu izin instalasi dari sumber internal GESIT sebelum APK bisa dipasang.';
      notifyListeners();
      return;
    }

    _actionState = AppUpdateActionState.downloading;
    _downloadProgress = 0;
    notifyListeners();

    try {
      final artifact = await _updateService.downloadRelease(
        currentRelease,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      _statusMessage =
          'APK selesai diunduh. Android installer akan dibuka untuk melanjutkan pembaruan.';
      notifyListeners();

      await _platformService.installApk(artifact.filePath);
      _actionState = AppUpdateActionState.idle;
      _statusMessage =
          'Installer pembaruan sudah dibuka. Selesaikan instalasi lalu buka kembali GESIT.';
    } on AppUpdateException catch (error) {
      _actionState = AppUpdateActionState.idle;
      _errorMessage = error.message;
    } on PlatformException catch (error) {
      _actionState = AppUpdateActionState.idle;
      debugPrint('App update installer failed: ${error.code} ${error.message}');
      _errorMessage =
          'Installer Android gagal dibuka: ${error.message ?? error.code}.';
    } catch (error) {
      _actionState = AppUpdateActionState.idle;
      debugPrint('App update failed: $error');
      _errorMessage =
          'APK gagal diproses. Coba lagi dan pastikan koneksi ke server pembaruan stabil.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> openUnknownAppSourcesSettings() async {
    _errorMessage = null;
    _statusMessage =
        'Buka izin "Install unknown apps" untuk GESIT, lalu kembali dan tekan Update Sekarang.';
    notifyListeners();

    try {
      await _platformService.openUnknownAppSourcesSettings();
    } catch (_) {
      _errorMessage =
          'Pengaturan izin instalasi tidak bisa dibuka dari perangkat ini.';
      notifyListeners();
    }
  }

  void dismissOptionalUpdate() {
    if (!isOptional || _release == null) {
      return;
    }

    _dismissedOptionalVersionCode = _release!.versionCode;
    notifyListeners();
  }

  void _handleSessionControllerChanged() {
    final normalized = AppRuntimeConfig.normalizeBaseUrl(
      _sessionController.apiBaseUrlDraft,
    );
    if (normalized == _observedBaseUrl) {
      return;
    }

    _observedBaseUrl = normalized;
    if (!_initialCheckCompleted || isBusy) {
      return;
    }

    _recheckDebounce?.cancel();
    _recheckDebounce = Timer(const Duration(milliseconds: 350), () {
      if (_disposed) {
        return;
      }
      unawaited(checkForUpdates(baseUrlOverride: normalized));
    });
  }

  bool get _supportsSelfHostedAndroidUpdate {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  void dispose() {
    _disposed = true;
    _recheckDebounce?.cancel();
    _sessionController.removeListener(_handleSessionControllerChanged);
    _updateService.dispose();
    super.dispose();
  }
}
