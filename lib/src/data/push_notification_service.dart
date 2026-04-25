import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'local_notification_service.dart';
import 'push_notification_models.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const Duration _initialMessageTimeout = Duration(seconds: 4);
  static const Duration _tokenRequestTimeout = Duration(seconds: 8);
  static const Duration _tokenRetryDelay = Duration(seconds: 12);
  static const int _maxTokenRefreshAttempts = 10;

  final StreamController<PushNotificationEnvelope> _messageController =
      StreamController<PushNotificationEnvelope>.broadcast();
  final StreamController<PushNotificationEnvelope> _openedMessageController =
      StreamController<PushNotificationEnvelope>.broadcast();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  StreamSubscription<PushNotificationEnvelope>? _localOpenSubscription;
  PushNotificationEnvelope? _pendingOpenMessage;
  String? _currentToken;
  Timer? _tokenRetryTimer;
  int _tokenRefreshAttempts = 0;
  bool _backgroundHandlerRegistered = false;
  bool _bootstrapped = false;
  bool _available = false;

  bool get isAvailable => _available;

  String? get currentToken => _currentToken;

  Stream<PushNotificationEnvelope> get messages => _messageController.stream;

  Stream<PushNotificationEnvelope> get openedMessages =>
      _openedMessageController.stream;

  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  void registerBackgroundHandler() {
    if (_backgroundHandlerRegistered || !_supportsFirebaseMessaging) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }

    _bootstrapped = true;

    if (!_supportsFirebaseMessaging) {
      return;
    }

    try {
      registerBackgroundHandler();
      await LocalNotificationService.instance.bootstrap();
      await _ensureFirebaseInitialized();

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _available = settings.authorizationStatus != AuthorizationStatus.denied;

      if (!_available) {
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        _tokenRefreshAttempts = 0;
        _cancelTokenRetry();
        _tokenRefreshController.add(token);
      });
      unawaited(refreshToken());

      FirebaseMessaging.onMessage.listen((message) {
        final envelope = _toEnvelope(message);
        _messageController.add(envelope);
        unawaited(LocalNotificationService.instance.playForegroundAlert());
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleOpenedEnvelope(_toEnvelope(message));
      });

      _localOpenSubscription = LocalNotificationService.instance.openedMessages
          .listen((message) {
            _handleOpenedEnvelope(message);
          });

      final pendingLocalMessage = LocalNotificationService.instance
          .takePendingOpenMessage();
      if (pendingLocalMessage != null) {
        _handleOpenedEnvelope(pendingLocalMessage);
      }

      final initialMessage = await messaging.getInitialMessage().timeout(
        _initialMessageTimeout,
        onTimeout: () => null,
      );
      if (initialMessage != null) {
        _handleOpenedEnvelope(_toEnvelope(initialMessage));
      }
    } catch (error, stackTrace) {
      _available = false;
      debugPrint('Push bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  PushNotificationEnvelope? takePendingOpenMessage() {
    final message = _pendingOpenMessage;
    _pendingOpenMessage = null;
    return message;
  }

  PushNotificationEnvelope _toEnvelope(RemoteMessage message) {
    return PushNotificationEnvelope(
      data: Map<String, String>.from(message.data),
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  void _handleOpenedEnvelope(PushNotificationEnvelope envelope) {
    if (_openedMessageController.hasListener) {
      _openedMessageController.add(envelope);
      return;
    }

    _pendingOpenMessage = envelope;
  }

  Future<void> refreshToken() async {
    if (!_supportsFirebaseMessaging || !_bootstrapped) {
      return;
    }

    try {
      await _ensureFirebaseInitialized();
      final messaging = FirebaseMessaging.instance;
      await _refreshCurrentToken(messaging);
    } catch (error, stackTrace) {
      debugPrint('Push token refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _refreshCurrentToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken().timeout(
        _tokenRequestTimeout,
        onTimeout: () => null,
      );
      if (token == null || token.trim().isEmpty) {
        _scheduleTokenRetry();
        return;
      }

      _currentToken = token;
      _tokenRefreshAttempts = 0;
      _cancelTokenRetry();
      _tokenRefreshController.add(token);
    } catch (error, stackTrace) {
      _scheduleTokenRetry();
      debugPrint('Push token fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _scheduleTokenRetry() {
    if (_currentToken != null && _currentToken!.trim().isNotEmpty) {
      return;
    }
    if (_tokenRetryTimer != null ||
        _tokenRefreshAttempts >= _maxTokenRefreshAttempts) {
      return;
    }

    _tokenRefreshAttempts += 1;
    _tokenRetryTimer = Timer(_tokenRetryDelay, () {
      _tokenRetryTimer = null;
      unawaited(refreshToken());
    });
  }

  void _cancelTokenRetry() {
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = null;
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    await Firebase.initializeApp();
  }

  bool get _supportsFirebaseMessaging {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> dispose() async {
    _cancelTokenRetry();
    await _localOpenSubscription?.cancel();
    await LocalNotificationService.instance.dispose();
    await _messageController.close();
    await _openedMessageController.close();
    await _tokenRefreshController.close();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    if (defaultTargetPlatform == TargetPlatform.android &&
        message.notification != null) {
      return;
    }

    await LocalNotificationService.instance.showRemoteMessageNotification(
      message,
    );
  } catch (_) {
    // Firebase is optional during local development and unsupported platforms.
  }
}
