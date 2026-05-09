import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppLinkController extends ChangeNotifier {
  AppLinkController();

  static const MethodChannel _channel = MethodChannel('gesit/deep_links');

  String? _pendingLink;
  bool _bootstrapped = false;

  String? get pendingLink => _pendingLink;

  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments?.toString().trim();
        if (link != null && link.isNotEmpty) {
          setPendingLink(link);
        }
      }
    });

    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.trim().isNotEmpty) {
        setPendingLink(initialLink.trim());
      }
    } catch (_) {
      // Deep links are Android-only for now. Fail silently on other platforms.
    }
  }

  void setPendingLink(String link) {
    final normalized = link.trim();
    if (normalized.isEmpty) {
      return;
    }

    _pendingLink = normalized;
    notifyListeners();
  }

  void consume(String link) {
    if (_pendingLink == link) {
      _pendingLink = null;
      notifyListeners();
    }
  }
}
