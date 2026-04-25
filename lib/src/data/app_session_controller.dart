import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../config/app_runtime_config.dart';
import '../models/session_models.dart';
import 'gesit_api_client.dart';
import 'gesit_http_client_factory.dart';
import 'session_store.dart';

enum AppSessionStatus { bootstrapping, authenticated, unauthenticated }

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required GesitApiClient apiClient,
    bool? browserManagedCookies,
  }) : _apiClient = apiClient,
       _browserManagedCookies =
           browserManagedCookies ?? usesBrowserManagedCookies;

  final GesitApiClient _apiClient;
  final bool _browserManagedCookies;

  AppSessionStatus _status = AppSessionStatus.bootstrapping;
  AppSession? _session;
  bool _busy = false;
  String? _errorMessage;
  String _apiBaseUrlDraft = AppRuntimeConfig.defaultApiBaseUrl;
  bool _rememberSession = true;
  bool _notifyScheduled = false;
  bool _disposed = false;

  AppSessionStatus get status => _status;

  AppSession? get session => _session;

  bool get isBusy => _busy;

  bool get isAuthenticated => _status == AppSessionStatus.authenticated;

  bool get isBootstrapping => _status == AppSessionStatus.bootstrapping;

  String? get errorMessage => _errorMessage;

  String get apiBaseUrlDraft => _apiBaseUrlDraft;

  bool get rememberSession => _rememberSession;

  Future<void> bootstrap() async {
    _status = AppSessionStatus.bootstrapping;
    _notifyListenersSafely();

    final persistedApiBaseUrl = await SessionStore.readApiBaseUrl();
    _apiBaseUrlDraft = AppRuntimeConfig.normalizePersistedBaseUrl(
      persistedApiBaseUrl,
    );
    if (persistedApiBaseUrl != null &&
        AppRuntimeConfig.normalizeBaseUrl(persistedApiBaseUrl) !=
            _apiBaseUrlDraft) {
      await SessionStore.writeApiBaseUrl(_apiBaseUrlDraft);
    }
    _rememberSession = await SessionStore.readRememberSession();

    final storedSession = await SessionStore.readSession();
    if (!_rememberSession) {
      await SessionStore.clearSession(keepApiBaseUrl: true);
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _notifyListenersSafely();
      return;
    }

    if (storedSession == null && !_browserManagedCookies) {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _notifyListenersSafely();
      return;
    }

    final normalizedBaseUrl = AppRuntimeConfig.normalizePersistedBaseUrl(
      storedSession?.apiBaseUrl ?? _apiBaseUrlDraft,
    );
    if (_apiBaseUrlDraft != normalizedBaseUrl) {
      _apiBaseUrlDraft = normalizedBaseUrl;
      await SessionStore.writeApiBaseUrl(_apiBaseUrlDraft);
    }

    try {
      final currentUser = await _apiClient.fetchCurrentUser(
        baseUrl: normalizedBaseUrl,
        cookies: storedSession?.cookies ?? const {},
      );
      _session =
          (storedSession ??
                  AppSession(
                    user: currentUser.user,
                    apiBaseUrl: normalizedBaseUrl,
                    cookies: const {},
                    rememberSession: _rememberSession,
                    authenticatedAt: DateTime.now(),
                  ))
              .copyWith(
                user: currentUser.user,
                cookies: currentUser.cookies,
                apiBaseUrl: normalizedBaseUrl,
                authenticatedAt: DateTime.now(),
              );
      await SessionStore.writeSession(_session!);
      _status = AppSessionStatus.authenticated;
      _errorMessage = null;
    } catch (_) {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      await SessionStore.clearSession(keepApiBaseUrl: true);
    }

    _notifyListenersSafely();
  }

  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberSession,
    String? baseUrl,
  }) async {
    _busy = true;
    _errorMessage = null;
    _rememberSession = rememberSession;
    _apiBaseUrlDraft = AppRuntimeConfig.normalizeBaseUrl(
      baseUrl ?? _apiBaseUrlDraft,
    );
    _notifyListenersSafely();

    try {
      await SessionStore.writeApiBaseUrl(_apiBaseUrlDraft);
      await SessionStore.writeRememberSession(rememberSession);

      final authPayload = await _apiClient.signIn(
        baseUrl: _apiBaseUrlDraft,
        email: email,
        password: password,
        rememberSession: rememberSession,
      );

      _session = AppSession(
        user: authPayload.user,
        apiBaseUrl: _apiBaseUrlDraft,
        cookies: authPayload.cookies,
        rememberSession: rememberSession,
        authenticatedAt: DateTime.now(),
      );
      _status = AppSessionStatus.authenticated;

      if (rememberSession) {
        await SessionStore.writeSession(_session!);
      } else {
        await SessionStore.clearSession(keepApiBaseUrl: true);
      }
    } on TimeoutException {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _errorMessage = 'Server terlalu lama merespons. Coba lagi.';
    } on GesitApiException catch (exception) {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _errorMessage = exception.message;
    } catch (_) {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _errorMessage = 'Koneksi ke server gagal. Periksa alamat API Anda.';
    } finally {
      _busy = false;
      _notifyListenersSafely();
    }
  }

  Future<AuthenticatedApiPayload?> signInWithBiometricToken({
    required String biometricToken,
    String? baseUrl,
  }) async {
    _busy = true;
    _errorMessage = null;
    _rememberSession = true;
    _apiBaseUrlDraft = AppRuntimeConfig.normalizeBaseUrl(
      baseUrl ?? _apiBaseUrlDraft,
    );
    _notifyListenersSafely();

    try {
      await SessionStore.writeApiBaseUrl(_apiBaseUrlDraft);
      await SessionStore.writeRememberSession(true);

      final authPayload = await _apiClient.signInWithBiometricToken(
        baseUrl: _apiBaseUrlDraft,
        biometricToken: biometricToken,
      );

      _session = AppSession(
        user: authPayload.user,
        apiBaseUrl: _apiBaseUrlDraft,
        cookies: authPayload.cookies,
        rememberSession: true,
        authenticatedAt: DateTime.now(),
      );
      _status = AppSessionStatus.authenticated;
      await SessionStore.writeSession(_session!);
      return authPayload;
    } on TimeoutException {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _errorMessage = 'Verifikasi fingerprint terlalu lama. Coba lagi.';
    } on GesitApiException catch (exception) {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _errorMessage = exception.message;
    } catch (_) {
      _session = null;
      _status = AppSessionStatus.unauthenticated;
      _errorMessage = 'Login fingerprint gagal. Periksa koneksi Anda.';
    } finally {
      _busy = false;
      _notifyListenersSafely();
    }

    return null;
  }

  Future<BiometricEnrollmentPayload> enrollMobileBiometric({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final currentSession = _session;
    if (currentSession == null) {
      throw const GesitApiException(
        'Sesi login belum tersedia untuk mengaktifkan fingerprint.',
      );
    }

    final payload = await _apiClient.enrollMobileBiometric(
      baseUrl: currentSession.apiBaseUrl,
      cookies: currentSession.cookies,
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
    );
    await syncCookies(payload.cookies);
    return payload;
  }

  Future<void> signOut() async {
    final currentSession = _session;
    _busy = true;
    _notifyListenersSafely();

    _session = null;
    _status = AppSessionStatus.unauthenticated;
    _errorMessage = null;
    _busy = false;
    _rememberSession = false;
    await SessionStore.writeRememberSession(false);
    await SessionStore.clearSession(keepApiBaseUrl: true);
    _notifyListenersSafely();

    if (currentSession != null) {
      unawaited(
        _attemptRemoteSignOut(
          baseUrl: currentSession.apiBaseUrl,
          cookies: currentSession.cookies,
        ),
      );
    }
  }

  Future<void> _attemptRemoteSignOut({
    required String baseUrl,
    required Map<String, String> cookies,
  }) async {
    try {
      await _apiClient.signOut(baseUrl: baseUrl, cookies: cookies);
    } catch (_) {
      // Local logout has already completed.
    }
  }

  Future<void> updateApiBaseUrl(String value) async {
    _apiBaseUrlDraft = AppRuntimeConfig.normalizeBaseUrl(value);
    await SessionStore.writeApiBaseUrl(_apiBaseUrlDraft);
    _notifyListenersSafely();
  }

  Future<void> syncSession(AppSession session, {bool notify = true}) async {
    _session = session;
    _status = AppSessionStatus.authenticated;
    _errorMessage = null;

    if (session.rememberSession) {
      await SessionStore.writeSession(session);
    }

    if (notify) {
      _notifyListenersSafely();
    }
  }

  Future<void> syncCookies(
    Map<String, String> cookies, {
    bool notify = false,
  }) async {
    final currentSession = _session;
    if (currentSession == null || cookies.isEmpty) {
      return;
    }

    await syncSession(
      currentSession.copyWith(
        cookies: cookies,
        authenticatedAt: DateTime.now(),
      ),
      notify: notify,
    );
  }

  Future<void> invalidateSession({String? errorMessage}) async {
    _session = null;
    _status = AppSessionStatus.unauthenticated;
    _busy = false;
    _rememberSession = false;
    _errorMessage = errorMessage;
    await SessionStore.writeRememberSession(false);
    await SessionStore.clearSession(keepApiBaseUrl: true);
    _notifyListenersSafely();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _notifyListenersSafely();
  }

  void _notifyListenersSafely() {
    if (_disposed) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer =
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;
    if (!shouldDefer) {
      notifyListeners();
      return;
    }

    if (_notifyScheduled) {
      return;
    }

    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) {
        return;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _apiClient.close();
    super.dispose();
  }
}
