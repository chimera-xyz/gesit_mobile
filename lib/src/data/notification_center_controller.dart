import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/app_models.dart';
import '../models/session_models.dart';
import 'app_notification_mapper.dart';
import 'app_session_controller.dart';
import 'gesit_api_client.dart';
import 'push_notification_service.dart';

class NotificationRemovalSnapshot {
  const NotificationRemovalSnapshot({
    required this.notification,
    required this.index,
  });

  final AppNotification notification;
  final int index;
}

class NotificationCenterController extends ChangeNotifier
    with WidgetsBindingObserver {
  NotificationCenterController({
    required this.sessionController,
    GesitApiClient? apiClient,
    PushNotificationService? pushNotificationService,
    Duration autoRefreshInterval = const Duration(seconds: 2),
    Duration realtimeRetryDelay = const Duration(milliseconds: 650),
    List<AppNotification>? initialNotifications,
  }) : _apiClient = apiClient ?? GesitApiClient(),
       _pushNotificationService =
           pushNotificationService ?? PushNotificationService.instance,
       _autoRefreshInterval = autoRefreshInterval,
       _realtimeRetryDelay = realtimeRetryDelay,
       _notifications = List<AppNotification>.from(
         initialNotifications ?? const <AppNotification>[],
       ) {
    WidgetsBinding.instance.addObserver(this);
    sessionController.addListener(_handleSessionChanged);
    _lastSession = sessionController.session;
  }

  final AppSessionController sessionController;
  final GesitApiClient _apiClient;
  final PushNotificationService? _pushNotificationService;
  final Duration _autoRefreshInterval;
  final Duration _realtimeRetryDelay;

  final List<AppNotification> _notifications;
  final List<AppNotification> _bannerQueue = [];
  final Map<String, AppNotification> _pushOnlyNotifications = {};
  final StreamController<AppNotification> _openRequestController =
      StreamController<AppNotification>.broadcast();

  Future<void>? _loadFuture;
  StreamSubscription<PushNotificationEnvelope>? _pushMessageSubscription;
  StreamSubscription<PushNotificationEnvelope>? _pushOpenedSubscription;
  StreamSubscription<String>? _pushTokenSubscription;
  Timer? _bannerTimer;
  Timer? _autoRefreshTimer;
  AppNotification? _activeBanner;
  AppSession? _lastSession;
  bool _disposed = false;
  bool _syncInFlight = false;
  bool _streamLoopRunning = false;
  bool _streamUnavailable = false;
  bool _pushStreamsBound = false;
  String? _registeredPushToken;
  int _lastNotificationId = 0;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  AppNotification? get activeBanner => _activeBanner;

  Stream<AppNotification> get openRequests => _openRequestController.stream;

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  bool get hasUnreadNotifications => unreadCount > 0;

  Future<void> ensureLoaded() {
    return _loadFuture ??= _bootstrap();
  }

  void startDemoFeed() {}

  AppNotification? notificationById(String id) {
    for (final notification in _notifications) {
      if (notification.id == id) {
        return notification;
      }
    }

    return _pushOnlyNotifications[id];
  }

  void receiveNotification(AppNotification notification) {
    _upsertNotification(notification, surface: true);
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );

    if (index < 0) {
      final pushOnlyNotification = _pushOnlyNotifications[id];
      if (pushOnlyNotification != null) {
        _pushOnlyNotifications[id] = pushOnlyNotification.copyWith(
          isRead: true,
        );
      }
      _removeFromBannerState(id, notify: false);
      notifyListeners();
      return;
    }

    final currentNotification = _notifications[index];
    if (currentNotification.isRead) {
      _removeFromBannerState(id, notify: true);
      return;
    }

    _notifications[index] = currentNotification.copyWith(isRead: true);
    _removeFromBannerState(id, notify: false);
    notifyListeners();

    final session = sessionController.session;
    if (session == null || !currentNotification.storesInCenter) {
      return;
    }

    try {
      final payload = await _apiClient.markNotificationRead(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        notificationId: id,
      );
      await sessionController.syncCookies(payload.cookies);
      final updatedNotification = _notificationFromResponse(
        payload.data['notification'],
      );
      if (updatedNotification != null) {
        _upsertNotification(updatedNotification, surface: false);
        notifyListeners();
      }
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await sessionController.invalidateSession(errorMessage: error.message);
      }
    } catch (_) {
      // Optimistic local state is already updated.
    }
  }

  Future<void> markAllAsRead() async {
    if (_notifications.isEmpty) {
      return;
    }

    var changed = false;
    for (var index = 0; index < _notifications.length; index++) {
      final notification = _notifications[index];
      if (notification.isRead) {
        continue;
      }

      _notifications[index] = notification.copyWith(isRead: true);
      changed = true;
    }

    _removeCenterNotificationsFromBannerState();
    if (changed) {
      notifyListeners();
    }

    final session = sessionController.session;
    if (session == null) {
      return;
    }

    try {
      final payload = await _apiClient.markAllNotificationsRead(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      await sessionController.syncCookies(payload.cookies);
      unawaited(syncLatest(surfaceNew: false));
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await sessionController.invalidateSession(errorMessage: error.message);
      }
    } catch (_) {
      // Optimistic local state is already updated.
    }
  }

  Future<NotificationRemovalSnapshot?> deleteNotification(String id) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index < 0) {
      return null;
    }

    final removedNotification = _notifications.removeAt(index);
    _removeFromBannerState(id, notify: false);
    notifyListeners();

    final session = sessionController.session;
    if (session != null && removedNotification.storesInCenter) {
      try {
        final payload = await _apiClient.deleteNotification(
          baseUrl: session.apiBaseUrl,
          cookies: session.cookies,
          notificationId: id,
        );
        await sessionController.syncCookies(payload.cookies);
      } on GesitApiException catch (error) {
        if (error.statusCode == 401) {
          await sessionController.invalidateSession(
            errorMessage: error.message,
          );
        }
      } catch (_) {
        // Keep optimistic delete.
      }
    }

    return NotificationRemovalSnapshot(
      notification: removedNotification,
      index: index,
    );
  }

  void restoreNotification(NotificationRemovalSnapshot snapshot) {
    if (_notifications.any(
      (notification) => notification.id == snapshot.notification.id,
    )) {
      return;
    }

    final insertIndex = snapshot.index.clamp(0, _notifications.length);
    _notifications.insert(insertIndex, snapshot.notification);
    notifyListeners();
  }

  Future<void> deleteAllNotifications() async {
    if (_notifications.isEmpty) {
      return;
    }

    _notifications.clear();
    _removeCenterNotificationsFromBannerState();
    notifyListeners();

    final session = sessionController.session;
    if (session == null) {
      return;
    }

    try {
      final payload = await _apiClient.deleteAllNotifications(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      await sessionController.syncCookies(payload.cookies);
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await sessionController.invalidateSession(errorMessage: error.message);
      }
    } catch (_) {
      // Keep optimistic local clear. If the backend is older, data will
      // reappear on the next sync until the server endpoint is deployed.
    }
  }

  void dismissActiveBanner() {
    if (_activeBanner == null) {
      return;
    }

    _clearActiveBanner(notify: false);
    _showNextBanner();
    notifyListeners();
  }

  Future<void> syncLatest({required bool surfaceNew}) async {
    final session = sessionController.session;
    if (session == null || _syncInFlight) {
      return;
    }

    _syncInFlight = true;
    try {
      final payload = await _apiClient.fetchNotifications(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        perPage: 50,
      );
      await sessionController.syncCookies(payload.cookies);
      _applyRemoteSnapshot(
        _notificationsFromResponse(payload.data),
        surfaceNew: surfaceNew,
      );
      notifyListeners();
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await sessionController.invalidateSession(errorMessage: error.message);
      }
    } catch (_) {
      // Foreground sync is best effort. Realtime stream and FCM are the primary
      // delivery path and polling is only a fast fallback.
    } finally {
      _syncInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _startForegroundSync();
      unawaited(syncLatest(surfaceNew: true));
      _ensureRealtimeLoop();
      unawaited(_registerCurrentPushToken());
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopForegroundSync();
    }
  }

  Future<void> _bootstrap() async {
    _bindPushStreams();
    await syncLatest(surfaceNew: false);
    _consumePendingPushOpenIntent();
    _startForegroundSync();
    _ensureRealtimeLoop();
    await _registerCurrentPushToken();
  }

  void _handleSessionChanged() {
    final session = sessionController.session;
    final previousSession = _lastSession;
    _lastSession = session;

    if (session == null) {
      _stopForegroundSync();
      if (previousSession != null) {
        unawaited(_unregisterPushToken(previousSession));
      }
      return;
    }

    if (_loadFuture == null) {
      unawaited(ensureLoaded());
      return;
    }

    _startForegroundSync();
    _ensureRealtimeLoop();
    unawaited(_registerCurrentPushToken());
  }

  void _bindPushStreams() {
    final pushNotificationService = _pushNotificationService;
    if (_pushStreamsBound || pushNotificationService == null) {
      return;
    }

    _pushStreamsBound = true;
    _pushMessageSubscription = pushNotificationService.messages.listen(
      _handleForegroundPushMessage,
    );
    _pushOpenedSubscription = pushNotificationService.openedMessages.listen(
      _handleOpenedPushMessage,
    );
    _pushTokenSubscription = pushNotificationService.tokenRefreshStream.listen(
      (_) => unawaited(_registerCurrentPushToken()),
    );
  }

  void _consumePendingPushOpenIntent() {
    final pendingMessage = _pushNotificationService?.takePendingOpenMessage();
    if (pendingMessage == null) {
      return;
    }

    _handleOpenedPushMessage(pendingMessage);
  }

  void _handleForegroundPushMessage(PushNotificationEnvelope envelope) {
    final notification = appNotificationFromPushPayload(
      envelope.data,
      fallbackTitle: envelope.title,
      fallbackMessage: envelope.body,
    );
    _upsertNotification(
      notification.copyWith(storesInCenter: notification.link != null),
      surface: true,
    );
    notifyListeners();
    unawaited(syncLatest(surfaceNew: false));
  }

  void _handleOpenedPushMessage(PushNotificationEnvelope envelope) {
    final notification = appNotificationFromPushPayload(
      envelope.data,
      fallbackTitle: envelope.title,
      fallbackMessage: envelope.body,
    );
    _upsertNotification(
      notification.copyWith(storesInCenter: notification.link != null),
      surface: false,
    );
    _openRequestController.add(notification);
    notifyListeners();
    unawaited(syncLatest(surfaceNew: false));
  }

  void _startForegroundSync() {
    if (_autoRefreshTimer != null || sessionController.session == null) {
      return;
    }

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      unawaited(syncLatest(surfaceNew: true));
    });
  }

  void _stopForegroundSync() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  void _ensureRealtimeLoop() {
    if (_streamLoopRunning ||
        _streamUnavailable ||
        sessionController.session == null ||
        _disposed) {
      return;
    }

    _streamLoopRunning = true;
    unawaited(_runRealtimeLoop());
  }

  Future<void> _runRealtimeLoop() async {
    while (!_disposed &&
        !_streamUnavailable &&
        sessionController.session != null) {
      try {
        final session = sessionController.session;
        if (session == null) {
          break;
        }

        await for (final payload in _apiClient.streamNotifications(
          baseUrl: session.apiBaseUrl,
          cookies: session.cookies,
          afterId: _lastNotificationId,
        )) {
          if (_disposed || sessionController.session == null) {
            break;
          }

          await sessionController.syncCookies(payload.cookies);
          _applyRealtimePayload(payload.data);
          notifyListeners();
        }
      } on GesitApiException catch (error) {
        if (error.statusCode == 401) {
          await sessionController.invalidateSession(
            errorMessage: error.message,
          );
          break;
        }
        if (error.statusCode == 404 || error.statusCode == 501) {
          _streamUnavailable = true;
          break;
        }
      } catch (_) {
        // Reconnect after a short delay.
      }

      if (_disposed ||
          _streamUnavailable ||
          sessionController.session == null) {
        break;
      }

      await Future<void>.delayed(_realtimeRetryDelay);
    }

    _streamLoopRunning = false;
  }

  void _applyRealtimePayload(Map<String, dynamic> payload) {
    final notifications = _notificationsFromRealtimePayload(payload);
    if (notifications.isNotEmpty) {
      for (final notification in notifications) {
        _upsertNotification(notification, surface: !notification.isRead);
      }
    }

    final lastId = (payload['last_notification_id'] as num?)?.toInt();
    if (lastId != null && lastId > _lastNotificationId) {
      _lastNotificationId = lastId;
    }
  }

  void _applyRemoteSnapshot(
    List<AppNotification> snapshot, {
    required bool surfaceNew,
  }) {
    final knownIds = _notifications
        .map((notification) => notification.id)
        .toSet();
    _notifications
      ..clear()
      ..addAll(snapshot);

    for (final notification in snapshot) {
      _pushOnlyNotifications.remove(notification.id);
      final numericId = int.tryParse(notification.id);
      if (numericId != null && numericId > _lastNotificationId) {
        _lastNotificationId = numericId;
      }

      if (surfaceNew &&
          !knownIds.contains(notification.id) &&
          !notification.isRead) {
        _enqueueBanner(notification);
      }
    }
  }

  void _upsertNotification(
    AppNotification notification, {
    required bool surface,
  }) {
    if (!notification.storesInCenter) {
      _pushOnlyNotifications[notification.id] = notification;
      if (surface) {
        _enqueueBanner(notification);
      }
      return;
    }

    final existingIndex = _notifications.indexWhere(
      (item) => item.id == notification.id,
    );

    if (existingIndex >= 0) {
      _notifications[existingIndex] = notification;
    } else {
      _notifications.insert(0, notification);
    }

    _notifications.sort((left, right) {
      return right.createdAt.compareTo(left.createdAt);
    });

    _pushOnlyNotifications.remove(notification.id);

    final numericId = int.tryParse(notification.id);
    if (numericId != null && numericId > _lastNotificationId) {
      _lastNotificationId = numericId;
    }

    if (surface && !notification.isRead) {
      _enqueueBanner(notification);
    }
  }

  void _enqueueBanner(AppNotification notification) {
    if (notification.isRead) {
      return;
    }

    if (_activeBanner?.id == notification.id) {
      return;
    }

    if (_bannerQueue.any((item) => item.id == notification.id)) {
      return;
    }

    _bannerQueue.add(notification);

    if (_activeBanner == null) {
      _showNextBanner();
    }
  }

  void _showNextBanner() {
    if (_activeBanner != null || _bannerQueue.isEmpty) {
      return;
    }

    _activeBanner = _bannerQueue.removeAt(0);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 5), dismissActiveBanner);
  }

  void _removeFromBannerState(String id, {required bool notify}) {
    _bannerQueue.removeWhere((notification) => notification.id == id);

    if (_activeBanner?.id == id) {
      final activeBanner = _activeBanner;
      if (activeBanner != null && !activeBanner.storesInCenter) {
        _pushOnlyNotifications.remove(id);
      }
      _clearActiveBanner(notify: false);
      _showNextBanner();
    }

    if (notify) {
      notifyListeners();
    }
  }

  void _removeCenterNotificationsFromBannerState() {
    _bannerQueue.removeWhere((notification) => notification.storesInCenter);

    if (_activeBanner?.storesInCenter == true) {
      _clearActiveBanner(notify: false);
      _showNextBanner();
    }
  }

  void _clearActiveBanner({required bool notify}) {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _activeBanner = null;

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _registerCurrentPushToken() async {
    final session = sessionController.session;
    final pushService = _pushNotificationService;
    final token = pushService?.currentToken?.trim();

    if (session == null ||
        pushService == null ||
        !pushService.isAvailable ||
        token == null ||
        token.isEmpty ||
        token == _registeredPushToken) {
      return;
    }

    try {
      final payload = await _apiClient.registerPushDeviceToken(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        token: token,
        platform: _platformName,
      );
      await sessionController.syncCookies(payload.cookies);
      _registeredPushToken = token;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        await sessionController.invalidateSession(errorMessage: error.message);
        return;
      }
      if (error.statusCode == 404 || error.statusCode == 501) {
        return;
      }
    } catch (_) {
      // Push registration is best effort.
    }
  }

  Future<void> _unregisterPushToken(AppSession session) async {
    final pushService = _pushNotificationService;
    final token = pushService?.currentToken?.trim();

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _apiClient.unregisterPushDeviceToken(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        token: token,
      );
      _registeredPushToken = null;
    } catch (_) {
      // Local logout is already complete. Remote cleanup can be retried later.
    }
  }

  List<AppNotification> _notificationsFromResponse(Map<String, dynamic> data) {
    final rawNotifications = data['notifications'];
    if (rawNotifications is! List) {
      return const <AppNotification>[];
    }

    return rawNotifications
        .whereType<Map>()
        .map(
          (item) =>
              appNotificationFromRemotePayload(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  List<AppNotification> _notificationsFromRealtimePayload(
    Map<String, dynamic> data,
  ) {
    final rawNotifications = data['notifications'];
    if (rawNotifications is List) {
      return rawNotifications
          .whereType<Map>()
          .map(
            (item) =>
                appNotificationFromRemotePayload(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    }

    final singleNotification = _notificationFromResponse(data['notification']);
    if (singleNotification != null) {
      return <AppNotification>[singleNotification];
    }

    final looksLikeNotification =
        data.containsKey('id') &&
        (data.containsKey('title') || data.containsKey('message'));
    if (!looksLikeNotification) {
      return const <AppNotification>[];
    }

    return <AppNotification>[appNotificationFromRemotePayload(data)];
  }

  AppNotification? _notificationFromResponse(Object? payload) {
    if (payload is Map<String, dynamic>) {
      return appNotificationFromRemotePayload(payload);
    }
    if (payload is Map) {
      return appNotificationFromRemotePayload(payload.cast<String, dynamic>());
    }

    return null;
  }

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    sessionController.removeListener(_handleSessionChanged);
    _bannerTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _pushMessageSubscription?.cancel();
    _pushOpenedSubscription?.cancel();
    _pushTokenSubscription?.cancel();
    _openRequestController.close();
    super.dispose();
  }
}
