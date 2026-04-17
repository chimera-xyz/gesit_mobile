import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const String _authenticatedKey = 'gesit.authenticated';
  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static Future<bool> readAuthenticated() async {
    try {
      return await _prefs.getBool(_authenticatedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> writeAuthenticated(bool value) async {
    try {
      await _prefs.setBool(_authenticatedKey, value);
    } catch (_) {
      // Ignore storage failures in this UI prototype and fall back to login.
    }
  }
}
