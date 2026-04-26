import 'package:flutter/foundation.dart';

class AppRuntimeConfig {
  const AppRuntimeConfig._();

  static const String _officeLanApiBaseUrl = 'http://192.168.1.3:8000';
  static const String _previousOfficeLanApiBaseUrl = 'http://192.168.1.24:8000';
  static const String _legacyOfficeLanApiBaseUrl = 'http://192.168.81.6:8000';

  // Development override: change this one line when the mobile app needs a
  // different backend address, for example `http://192.168.1.10:8000`.
  static const String _debugApiBaseUrlOverride = '';

  static const String _rawDefaultApiBaseUrl = String.fromEnvironment(
    'GESIT_API_BASE_URL',
    defaultValue: '',
  );
  static const String _rawLongLivedRequestsOverride = String.fromEnvironment(
    'GESIT_ENABLE_LONG_LIVED_REQUESTS',
    defaultValue: '',
  );

  static bool get hasExplicitApiBaseUrlOverride =>
      _rawDefaultApiBaseUrl.trim().isNotEmpty;

  static String get defaultApiBaseUrl {
    final fromEnvironment = _rawDefaultApiBaseUrl.trim();
    if (fromEnvironment.isNotEmpty) {
      return _normalizeExplicitBaseUrl(fromEnvironment);
    }

    final fromDebugOverride = _debugApiBaseUrlOverride.trim();
    if (kDebugMode && fromDebugOverride.isNotEmpty) {
      return _normalizeExplicitBaseUrl(fromDebugOverride);
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

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return _officeLanApiBaseUrl;
    }

    return 'http://127.0.0.1:8000';
  }

  static String normalizeBaseUrl(String? rawValue) {
    final rawCandidate = (rawValue ?? '').trim();
    if (rawCandidate.isEmpty) {
      return defaultApiBaseUrl;
    }

    return _normalizeExplicitBaseUrl(rawCandidate);
  }

  static String _normalizeExplicitBaseUrl(String rawValue) {
    final candidate = rawValue.trim();
    final withScheme =
        candidate.startsWith('http://') || candidate.startsWith('https://')
        ? candidate
        : 'http://$candidate';

    final normalized = withScheme.replaceFirst(RegExp(r'/+$'), '');
    return _normalizeWebLoopbackBaseUrl(normalized);
  }

  static String normalizePersistedBaseUrl(String? rawValue) {
    final normalized = normalizeBaseUrl(rawValue);
    if (!_shouldMigrateLegacyPersistedBaseUrl(normalized)) {
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

  static bool supportsLongLivedRequests(String? rawBaseUrl) {
    final override = _longLivedRequestsOverride;
    if (override != null) {
      return override;
    }

    final normalized = normalizeBaseUrl(rawBaseUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return true;
    }

    final host = uri.host.trim().toLowerCase();
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final looksLikeLocalDevServer =
        uri.scheme == 'http' &&
        port == 8000 &&
        (_isLoopbackHost(host) ||
            _isPrivateIpv4Host(host) ||
            host.endsWith('.local'));

    return !looksLikeLocalDevServer;
  }

  static bool prefersShortPolling(String? rawBaseUrl) {
    return !supportsLongLivedRequests(rawBaseUrl);
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

  static bool _shouldMigrateLegacyPersistedBaseUrl(String normalized) {
    if (_shouldMigrateLegacyWebDebugBaseUrl(normalized)) {
      return true;
    }

    if ((normalized == _previousOfficeLanApiBaseUrl ||
            normalized == _legacyOfficeLanApiBaseUrl) &&
        defaultApiBaseUrl != normalized) {
      return true;
    }

    final normalizedUri = Uri.tryParse(normalized);
    final defaultUri = Uri.tryParse(defaultApiBaseUrl);
    if (normalizedUri == null || defaultUri == null) {
      return false;
    }

    final normalizedHost = normalizedUri.host.trim().toLowerCase();
    final defaultHost = defaultUri.host.trim().toLowerCase();
    if (!_isLocalOnlyHost(normalizedHost) || _isLocalOnlyHost(defaultHost)) {
      return false;
    }

    return normalizedUri.scheme != defaultUri.scheme ||
        normalizedHost != defaultHost ||
        normalizedUri.port != defaultUri.port;
  }

  static bool _isLoopbackHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '[::1]';
  }

  static bool _isLocalOnlyHost(String host) {
    return _isLoopbackHost(host) || host == '0.0.0.0' || host == '10.0.2.2';
  }

  static bool _isPrivateIpv4Host(String host) {
    final octets = host.split('.');
    if (octets.length != 4) {
      return false;
    }

    final numbers = <int>[];
    for (final octet in octets) {
      final value = int.tryParse(octet);
      if (value == null || value < 0 || value > 255) {
        return false;
      }

      numbers.add(value);
    }

    if (numbers[0] == 10) {
      return true;
    }

    if (numbers[0] == 172 && numbers[1] >= 16 && numbers[1] <= 31) {
      return true;
    }

    return numbers[0] == 192 && numbers[1] == 168;
  }

  static bool? get _longLivedRequestsOverride {
    final normalized = _rawLongLivedRequestsOverride.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on') {
      return true;
    }

    if (normalized == '0' ||
        normalized == 'false' ||
        normalized == 'no' ||
        normalized == 'off') {
      return false;
    }

    return null;
  }
}
