import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_runtime_config.dart';
import 'gesit_http_client_factory.dart';
import 'internet_access_probe.dart';

enum ConnectionIssue { none, offline, serverUnavailable }

typedef InternetProbe = Future<bool> Function(Duration timeout);
typedef BackendProbe = Future<bool> Function(String baseUrl, Duration timeout);

class ConnectionStatusController extends ChangeNotifier {
  ConnectionStatusController({
    http.Client? httpClient,
    InternetProbe? internetProbe,
    BackendProbe? backendProbe,
    Duration checkInterval = const Duration(seconds: 30),
    Duration degradedCheckInterval = const Duration(seconds: 8),
    Duration backendTimeout = const Duration(seconds: 5),
    Duration internetTimeout = const Duration(seconds: 4),
  }) : _httpClient = httpClient ?? createGesitHttpClient(),
       _ownsHttpClient = httpClient == null,
       _internetProbe =
           internetProbe ?? ((timeout) => hasInternetAccess(timeout: timeout)),
       _backendProbe = backendProbe,
       _healthyCheckInterval = checkInterval,
       _degradedCheckInterval = degradedCheckInterval,
       _backendTimeout = backendTimeout,
       _internetTimeout = internetTimeout;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final InternetProbe _internetProbe;
  final BackendProbe? _backendProbe;
  final Duration _healthyCheckInterval;
  final Duration _degradedCheckInterval;
  final Duration _backendTimeout;
  final Duration _internetTimeout;

  Timer? _timer;
  Future<ConnectionIssue>? _activeCheck;
  String? _baseUrl;
  int _generation = 0;
  bool _monitoring = false;
  bool _disposed = false;
  bool _isChecking = false;
  ConnectionIssue _issue = ConnectionIssue.none;
  DateTime? _lastCheckedAt;

  ConnectionIssue get issue => _issue;

  bool get hasIssue => _issue != ConnectionIssue.none;

  bool get isChecking => _isChecking;

  DateTime? get lastCheckedAt => _lastCheckedAt;

  void start(String baseUrl) {
    final normalizedBaseUrl = AppRuntimeConfig.normalizeBaseUrl(baseUrl);
    if (_monitoring && _baseUrl == normalizedBaseUrl) {
      return;
    }

    _baseUrl = normalizedBaseUrl;
    _monitoring = true;
    _generation += 1;
    _issue = ConnectionIssue.none;
    _lastCheckedAt = null;
    _timer?.cancel();
    _notifyListenersSafely();
    unawaited(checkNow());
  }

  void stop() {
    _generation += 1;
    _monitoring = false;
    _baseUrl = null;
    _timer?.cancel();
    _timer = null;
    _activeCheck = null;
    _isChecking = false;
    _issue = ConnectionIssue.none;
    _lastCheckedAt = null;
    _notifyListenersSafely();
  }

  Future<ConnectionIssue> checkNow() {
    if (!_monitoring || _baseUrl == null) {
      return Future.value(ConnectionIssue.none);
    }

    final inFlight = _activeCheck;
    if (inFlight != null) {
      return inFlight;
    }

    _timer?.cancel();
    _timer = null;
    final check = _runCheck(_baseUrl!, _generation);
    _activeCheck = check;
    return check;
  }

  Future<ConnectionIssue> _runCheck(String baseUrl, int generation) async {
    _isChecking = true;
    _notifyListenersSafely();

    try {
      final backendReachable = await _canReachBackend(baseUrl);
      final nextIssue = backendReachable
          ? ConnectionIssue.none
          : await _classifyUnreachableBackend();

      if (!_isCurrentGeneration(generation)) {
        return ConnectionIssue.none;
      }

      _issue = nextIssue;
      _lastCheckedAt = DateTime.now();
      return nextIssue;
    } finally {
      if (_isCurrentGeneration(generation)) {
        _isChecking = false;
        _activeCheck = null;
        _scheduleNextCheck();
        _notifyListenersSafely();
      }
    }
  }

  Future<bool> _canReachBackend(String baseUrl) async {
    final customProbe = _backendProbe;
    if (customProbe != null) {
      return customProbe(baseUrl, _backendTimeout);
    }

    try {
      final response = await _httpClient
          .get(
            _buildHealthUri(baseUrl),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_backendTimeout);

      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<ConnectionIssue> _classifyUnreachableBackend() async {
    final internetReachable = await _internetProbe(_internetTimeout);
    return internetReachable
        ? ConnectionIssue.serverUnavailable
        : ConnectionIssue.offline;
  }

  Uri _buildHealthUri(String baseUrl) {
    final normalizedBaseUrl = AppRuntimeConfig.normalizeBaseUrl(baseUrl);
    return Uri.parse('$normalizedBaseUrl/api/health').replace(
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch.toString()},
    );
  }

  bool _isCurrentGeneration(int generation) {
    return !_disposed && _monitoring && generation == _generation;
  }

  void _scheduleNextCheck() {
    if (!_monitoring || _disposed) {
      return;
    }

    _timer?.cancel();
    final interval = hasIssue ? _degradedCheckInterval : _healthyCheckInterval;
    _timer = Timer(interval, () => unawaited(checkNow()));
  }

  void _notifyListenersSafely() {
    if (_disposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    super.dispose();
  }
}
