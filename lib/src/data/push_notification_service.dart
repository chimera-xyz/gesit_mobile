import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationEnvelope {
  const PushNotificationEnvelope({required this.data, this.title, this.body});

  final Map<String, String> data;
  final String? title;
  final String? body;
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final StreamController<PushNotificationEnvelope> _messageController =
      StreamController<PushNotificationEnvelope>.broadcast();
  final StreamController<PushNotificationEnvelope> _openedMessageController =
      StreamController<PushNotificationEnvelope>.broadcast();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  PushNotificationEnvelope? _pendingOpenMessage;
  String? _currentToken;
  bool _bootstrapped = false;
  bool _available = false;

  bool get isAvailable => _available;

  String? get currentToken => _currentToken;

  Stream<PushNotificationEnvelope> get messages => _messageController.stream;

  Stream<PushNotificationEnvelope> get openedMessages =>
      _openedMessageController.stream;

  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }

    _bootstrapped = true;

    if (!_supportsFirebaseMessaging) {
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

      _currentToken = await messaging.getToken();

      messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        _tokenRefreshController.add(token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        _messageController.add(_toEnvelope(message));
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _openedMessageController.add(_toEnvelope(message));
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _pendingOpenMessage = _toEnvelope(initialMessage);
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

  bool get _supportsFirebaseMessaging {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> dispose() async {
    await _messageController.close();
    await _openedMessageController.close();
    await _tokenRefreshController.close();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase is optional during local development and unsupported platforms.
  }
}
