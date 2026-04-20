import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredBiometricToken {
  const StoredBiometricToken({
    required this.token,
    required this.baseUrl,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  final String token;
  final String baseUrl;
  final String deviceId;
  final String deviceName;
  final String platform;
}

class BiometricTokenStore {
  BiometricTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'gesit.biometric.token';
  static const String _baseUrlKey = 'gesit.biometric.base_url';
  static const String _deviceIdKey = 'gesit.biometric.device_id';
  static const String _deviceNameKey = 'gesit.biometric.device_name';
  static const String _platformKey = 'gesit.biometric.platform';

  final FlutterSecureStorage _storage;

  Future<StoredBiometricToken?> readToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final baseUrl = await _storage.read(key: _baseUrlKey);
      final deviceId = await _storage.read(key: _deviceIdKey);
      final deviceName = await _storage.read(key: _deviceNameKey);
      final platform = await _storage.read(key: _platformKey);

      if ([token, baseUrl, deviceId, deviceName, platform].any(_isBlank)) {
        return null;
      }

      return StoredBiometricToken(
        token: token!.trim(),
        baseUrl: baseUrl!.trim(),
        deviceId: deviceId!.trim(),
        deviceName: deviceName!.trim(),
        platform: platform!.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeToken({
    required String token,
    required String baseUrl,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    await _storage.write(key: _tokenKey, value: token.trim());
    await _storage.write(key: _baseUrlKey, value: baseUrl.trim());
    await _storage.write(key: _deviceIdKey, value: deviceId.trim());
    await _storage.write(key: _deviceNameKey, value: deviceName.trim());
    await _storage.write(key: _platformKey, value: platform.trim());
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _baseUrlKey);
    await _storage.delete(key: _deviceNameKey);
    await _storage.delete(key: _platformKey);
  }

  Future<String> readOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (!_isBlank(existing)) {
      return existing!.trim();
    }

    final nextValue = _generateDeviceId();
    await _storage.write(key: _deviceIdKey, value: nextValue);
    return nextValue;
  }

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
