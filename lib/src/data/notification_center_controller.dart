import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import 'demo_data.dart';

class NotificationRemovalSnapshot {
  const NotificationRemovalSnapshot({
    required this.notification,
    required this.index,
  });

  final AppNotification notification;
  final int index;
}

class NotificationCenterController extends ChangeNotifier {
  NotificationCenterController({
    List<AppNotification>? initialNotifications,
    List<ScheduledNotification>? scheduledNotifications,
  }) : _notifications = List<AppNotification>.from(
         initialNotifications ?? DemoData.seedNotifications(),
       ),
       _scheduledNotifications = List<ScheduledNotification>.from(
         scheduledNotifications ?? DemoData.seedIncomingNotifications(),
       );

  final List<AppNotification> _notifications;
  final List<ScheduledNotification> _scheduledNotifications;
  final List<AppNotification> _bannerQueue = [];
  final List<Timer> _incomingTimers = [];
  final Map<String, AppNotification> _pushOnlyNotifications = {};

  AppNotification? _activeBanner;
  Timer? _bannerTimer;
  bool _demoFeedStarted = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  AppNotification? get activeBanner => _activeBanner;

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  bool get hasUnreadNotifications => unreadCount > 0;

  AppNotification? notificationById(String id) {
    for (final notification in _notifications) {
      if (notification.id == id) {
        return notification;
      }
    }

    return _pushOnlyNotifications[id];
  }

  void startDemoFeed() {
    if (_demoFeedStarted) {
      return;
    }

    _demoFeedStarted = true;

    for (final scheduledNotification in _scheduledNotifications) {
      _incomingTimers.add(
        Timer(scheduledNotification.delay, () {
          receiveNotification(scheduledNotification.materialize());
        }),
      );
    }
  }

  void receiveNotification(AppNotification notification) {
    if (notification.storesInCenter) {
      _notifications.removeWhere((item) => item.id == notification.id);
      _notifications.insert(0, notification);
      _pushOnlyNotifications.remove(notification.id);
    } else {
      _pushOnlyNotifications[notification.id] = notification;
    }

    _enqueueBanner(notification);
    notifyListeners();
  }

  void markAsRead(String id) {
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

    if (_notifications[index].isRead) {
      _removeFromBannerState(id, notify: false);
      return;
    }

    _notifications[index] = _notifications[index].copyWith(isRead: true);
    _removeFromBannerState(id, notify: false);
    notifyListeners();
  }

  void markAllAsRead() {
    if (_notifications.isEmpty) {
      return;
    }

    var changed = false;
    final hadTransientUi =
        _activeBanner?.storesInCenter == true ||
        _bannerQueue.any((notification) => notification.storesInCenter);

    for (var index = 0; index < _notifications.length; index++) {
      final notification = _notifications[index];
      if (notification.isRead) {
        continue;
      }

      _notifications[index] = notification.copyWith(isRead: true);
      changed = true;
    }

    _removeCenterNotificationsFromBannerState();

    if (changed || hadTransientUi) {
      notifyListeners();
    }
  }

  NotificationRemovalSnapshot? deleteNotification(String id) {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index < 0) {
      return null;
    }

    final removedNotification = _notifications.removeAt(index);
    _removeFromBannerState(id, notify: false);
    notifyListeners();

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

  void deleteAllNotifications() {
    if (_notifications.isEmpty) {
      return;
    }

    _notifications.clear();
    _removeCenterNotificationsFromBannerState();
    notifyListeners();
  }

  void dismissActiveBanner() {
    if (_activeBanner == null) {
      return;
    }

    _clearActiveBanner(notify: false);
    _showNextBanner();
    notifyListeners();
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

  @override
  void dispose() {
    _bannerTimer?.cancel();

    for (final timer in _incomingTimers) {
      timer.cancel();
    }

    super.dispose();
  }
}
