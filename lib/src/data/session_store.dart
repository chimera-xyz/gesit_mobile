import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_models.dart';

class SessionStore {
  const SessionStore._();

  static const String _sessionKey = 'gesit.session.snapshot';
  static const String _apiBaseUrlKey = 'gesit.api.base_url';
  static const String _rememberSessionKey = 'gesit.auth.remember';
  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static Future<AppSession?> readSession() async {
    try {
      final rawValue = await _prefs.getString(_sessionKey);
      if (rawValue == null || rawValue.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return AppSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeSession(AppSession session) async {
    try {
      await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (_) {
      // Ignore storage failures and let the app fall back to sign-in.
    }
  }

  static Future<void> clearSession({bool keepApiBaseUrl = false}) async {
    try {
      await _prefs.remove(_sessionKey);

      if (!keepApiBaseUrl) {
        await _prefs.remove(_apiBaseUrlKey);
      }
    } catch (_) {
      // Ignore storage failures in the mobile shell prototype.
    }
  }

  static Future<String?> readApiBaseUrl() async {
    try {
      final value = await _prefs.getString(_apiBaseUrlKey);
      return value?.trim().isEmpty == true ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeApiBaseUrl(String value) async {
    try {
      await _prefs.setString(_apiBaseUrlKey, value.trim());
    } catch (_) {
      // Ignore storage failures in development mode.
    }
  }

  static Future<bool> readRememberSession() async {
    try {
      return await _prefs.getBool(_rememberSessionKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> writeRememberSession(bool value) async {
    try {
      await _prefs.setBool(_rememberSessionKey, value);
    } catch (_) {
      // Ignore storage failures in development mode.
    }
  }
}
