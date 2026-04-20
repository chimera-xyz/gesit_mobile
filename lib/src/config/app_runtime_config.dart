import 'package:flutter/foundation.dart';

class AppRuntimeConfig {
  const AppRuntimeConfig._();

  // Development override: change this one line when the mobile app needs a
  // different backend address, for example `http://192.168.1.10:8000`.
  static const String _debugApiBaseUrlOverride = '';

  static const String _rawDefaultApiBaseUrl = String.fromEnvironment(
    'GESIT_API_BASE_URL',
    defaultValue: '',
  );

  static bool get hasExplicitApiBaseUrlOverride =>
      _rawDefaultApiBaseUrl.trim().isNotEmpty;

  static String get defaultApiBaseUrl {
    final fromEnvironment = _rawDefaultApiBaseUrl.trim();
    if (fromEnvironment.isNotEmpty) {
      return normalizeBaseUrl(fromEnvironment);
    }

    final fromDebugOverride = _debugApiBaseUrlOverride.trim();
    if (kDebugMode && fromDebugOverride.isNotEmpty) {
      return normalizeBaseUrl(fromDebugOverride);
    }

    if (kIsWeb) {
      if (kDebugMode) {
        return 'http://localhost:8000';
      }

      final currentHost = Uri.base.host.trim();
      final normalizedHost = currentHost.isEmpty ? 'localhost' : currentHost;
      final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
      return '$scheme://$normalizedHost:8000';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static String normalizeBaseUrl(String? rawValue) {
    final fallback = defaultApiBaseUrl;
    final candidate = (rawValue ?? '').trim().isEmpty
        ? fallback
        : rawValue!.trim();
    final withScheme =
        candidate.startsWith('http://') || candidate.startsWith('https://')
        ? candidate
        : 'http://$candidate';

    final normalized = withScheme.replaceFirst(RegExp(r'/+$'), '');
    return _normalizeWebLoopbackBaseUrl(normalized);
  }

  static String normalizePersistedBaseUrl(String? rawValue) {
    final normalized = normalizeBaseUrl(rawValue);
    if (!_shouldMigrateLegacyWebDebugBaseUrl(normalized)) {
      return normalized;
    }

    return defaultApiBaseUrl;
  }

  static String resolveHostedUrl(String baseUrl, String rawValue) {
    final candidate = rawValue.trim();
    if (candidate.isEmpty) {
      return candidate;
    }

    final normalizedBaseUrl = normalizeBaseUrl(baseUrl);
    final baseUri = Uri.tryParse(normalizedBaseUrl);
    final targetUri = Uri.tryParse(candidate);
    if (baseUri == null || targetUri == null) {
      return candidate;
    }

    if (!targetUri.hasScheme) {
      return baseUri.resolveUri(targetUri).toString();
    }

    final baseHost = baseUri.host.toLowerCase();
    final targetHost = targetUri.host.toLowerCase();
    if (_isLoopbackHost(baseHost) && _isLoopbackHost(targetHost)) {
      return targetUri
          .replace(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : targetUri.port,
          )
          .toString();
    }

    return candidate;
  }

  static String _normalizeWebLoopbackBaseUrl(String value) {
    if (!kIsWeb) {
      return value;
    }

    final currentHost = Uri.base.host.trim().toLowerCase();
    if (!_isLoopbackHost(currentHost)) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !_isLoopbackHost(uri.host.toLowerCase())) {
      return value;
    }

    if (uri.host.toLowerCase() == currentHost) {
      return value;
    }

    return uri.replace(host: currentHost).toString();
  }

  static bool _shouldMigrateLegacyWebDebugBaseUrl(String normalized) {
    if (!kIsWeb || !kDebugMode || hasExplicitApiBaseUrlOverride) {
      return false;
    }

    final legacyValue = _legacyWebDebugDefaultApiBaseUrl;
    if (legacyValue == null) {
      return false;
    }

    return normalized == legacyValue;
  }

  static String? get _legacyWebDebugDefaultApiBaseUrl {
    final currentHost = Uri.base.host.trim();
    final normalizedHost = currentHost.isEmpty ? 'localhost' : currentHost;
    if (_isLoopbackHost(normalizedHost.toLowerCase())) {
      return null;
    }

    final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
    return '$scheme://$normalizedHost:8000';
  }

  static bool _isLoopbackHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '[::1]';
  }
}
