import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'push_notification_models.dart';

const String _generalChannelId = 'gesit.general.high_priority.v4';
const String _generalChannelName = 'GESIT Alerts';
const String _generalChannelDescription =
    'Notifikasi prioritas tinggi untuk aktivitas GESIT.';

const String _callChannelId = 'gesit.calls.incoming.v4';
const String _callChannelName = 'GESIT Calls';
const String _callChannelDescription =
    'Notifikasi panggilan masuk GESIT dengan tampilan penuh.';

const String _androidNotificationSoundName = 'yulie_sekuritas_notifikasi_v2';
const MethodChannel _notificationAudioChannel = MethodChannel(
  'gesit/notification_audio',
);
const List<String> _foregroundAlertAssetPaths = <String>[
  'assets/audio/yulie_sekuritas_notifikasi_v2.wav',
  'assets/audio/yulie_sekuritas_notifikasi.mp3',
];

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<PushNotificationEnvelope> _openedMessageController =
      StreamController<PushNotificationEnvelope>.broadcast();
  final AudioPlayer _foregroundAlertPlayer = AudioPlayer();

  bool _bootstrapped = false;
  bool _pluginInitialized = false;
  String? _foregroundAlertPreparedAssetPath;
  PushNotificationEnvelope? _pendingOpenMessage;

  Stream<PushNotificationEnvelope> get openedMessages =>
      _openedMessageController.stream;

  PushNotificationEnvelope? takePendingOpenMessage() {
    final message = _pendingOpenMessage;
    _pendingOpenMessage = null;
    return message;
  }

  Future<void> bootstrap() async {
    if (_bootstrapped || !_supportsLocalNotifications) {
      return;
    }

    _bootstrapped = true;
    await _initializePlugin(requestAndroidPermission: true);

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) {
      return;
    }

    final envelope = PushNotificationEnvelope.fromPayload(
      launchDetails?.notificationResponse?.payload,
    );
    if (envelope != null) {
      _pendingOpenMessage = envelope;
    }
  }

  Future<void> playForegroundAlert() async {
    if (!_supportsLocalNotifications) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _notificationAudioChannel.invokeMethod<void>(
          'playForegroundAlert',
        );
        return;
      } catch (error) {
        debugPrint('Native foreground notification sound failed: $error');
      }
    }

    await _playForegroundAssetAlert();
  }

  Future<void> _playForegroundAssetAlert() async {
    for (final assetPath in _foregroundAlertAssetPaths) {
      final played = await _tryPlayForegroundAsset(assetPath);
      if (played) {
        return;
      }
    }

    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (error) {
      debugPrint('Foreground notification sound failed: $error');
    }
  }

  Future<bool> _tryPlayForegroundAsset(String assetPath) async {
    try {
      if (_foregroundAlertPreparedAssetPath != assetPath) {
        await _foregroundAlertPlayer.setAsset(assetPath);
        _foregroundAlertPreparedAssetPath = assetPath;
      }

      await _foregroundAlertPlayer.seek(Duration.zero);
      await _foregroundAlertPlayer.play();
      return true;
    } catch (error) {
      debugPrint('Foreground notification asset failed ($assetPath): $error');
      if (_foregroundAlertPreparedAssetPath == assetPath) {
        _foregroundAlertPreparedAssetPath = null;
      }
      return false;
    }
  }

  Future<void> showRemoteMessageNotification(RemoteMessage message) async {
    if (!_supportsLocalNotifications) {
      return;
    }

    await _initializePlugin();
    await _showEnvelope(_envelopeFromRemoteMessage(message));
  }

  Future<void> dispose() async {
    await _openedMessageController.close();
    await _foregroundAlertPlayer.dispose();
  }

  Future<void> _initializePlugin({
    bool requestAndroidPermission = false,
  }) async {
    if (_pluginInitialized || !_supportsLocalNotifications) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (requestAndroidPermission) {
      try {
        await androidPlugin?.requestNotificationsPermission();
      } catch (error) {
        debugPrint('Android notification permission request failed: $error');
      }
    }
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _generalChannelId,
        _generalChannelName,
        description: _generalChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound(
          _androidNotificationSoundName,
        ),
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _callChannelId,
        _callChannelName,
        description: _callChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        sound: RawResourceAndroidNotificationSound(
          _androidNotificationSoundName,
        ),
      ),
    );

    _pluginInitialized = true;
  }

  Future<void> _showEnvelope(PushNotificationEnvelope envelope) async {
    final title = normalizedPushString(
      envelope.title ?? envelope.data['title'],
    );
    final body = normalizedPushString(
      envelope.body ?? envelope.data['message'],
    );
    if (title == null && body == null) {
      return;
    }

    await _plugin.show(
      _notificationIdFor(envelope),
      title ?? 'GESIT',
      body ?? 'Ada notifikasi baru untuk Anda.',
      NotificationDetails(
        android: _androidDetailsFor(envelope, body),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: envelope.toPayload(),
    );
  }

  AndroidNotificationDetails _androidDetailsFor(
    PushNotificationEnvelope envelope,
    String? body,
  ) {
    final isCall = envelope.isCall;

    return AndroidNotificationDetails(
      isCall ? _callChannelId : _generalChannelId,
      isCall ? _callChannelName : _generalChannelName,
      channelDescription: isCall
          ? _callChannelDescription
          : _generalChannelDescription,
      category: isCall
          ? AndroidNotificationCategory.call
          : AndroidNotificationCategory.message,
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
      audioAttributesUsage: isCall
          ? AudioAttributesUsage.notificationRingtone
          : AudioAttributesUsage.notification,
      sound: const RawResourceAndroidNotificationSound(
        _androidNotificationSoundName,
      ),
      autoCancel: !isCall,
      ongoing: isCall,
      fullScreenIntent: isCall,
      timeoutAfter: isCall ? 25000 : null,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body ?? 'Ada notifikasi baru untuk Anda.',
      ),
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final envelope = PushNotificationEnvelope.fromPayload(response.payload);
    if (envelope == null) {
      return;
    }

    if (_openedMessageController.hasListener) {
      _openedMessageController.add(envelope);
      return;
    }

    _pendingOpenMessage = envelope;
  }

  int _notificationIdFor(PushNotificationEnvelope envelope) {
    final seed =
        envelope.notificationId ??
        envelope.link ??
        envelope.title ??
        envelope.body ??
        DateTime.now().microsecondsSinceEpoch.toString();

    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash;
  }

  PushNotificationEnvelope _envelopeFromRemoteMessage(RemoteMessage message) {
    return PushNotificationEnvelope(
      data: Map<String, String>.from(message.data),
      title: normalizedPushString(message.notification?.title),
      body: normalizedPushString(message.notification?.body),
    );
  }

  bool get _supportsLocalNotifications {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
