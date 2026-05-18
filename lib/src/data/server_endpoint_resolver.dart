import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_runtime_config.dart';
import 'gesit_http_client_factory.dart';

class ServerEndpointCandidate {
  const ServerEndpointCandidate({
    required this.id,
    required this.baseUrl,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String baseUrl;
  final String title;
  final String subtitle;
}

typedef ServerEndpointProbe =
    Future<bool> Function(String baseUrl, Duration timeout);

class ServerEndpointResolver {
  ServerEndpointResolver({
    http.Client? httpClient,
    ServerEndpointProbe? probe,
    Duration probeTimeout = const Duration(milliseconds: 1800),
  }) : _httpClient = httpClient ?? createGesitHttpClient(),
       _ownsHttpClient = httpClient == null,
       _probe = probe,
       _probeTimeout = probeTimeout;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final ServerEndpointProbe? _probe;
  final Duration _probeTimeout;

  static ServerEndpointCandidate get defaultCandidate =>
      ServerEndpointCandidate(
        id: 'default',
        baseUrl: AppRuntimeConfig.defaultApiBaseUrl,
        title: 'Server GESIT',
        subtitle: 'Endpoint API yang dikonfigurasi',
      );

  Future<ServerEndpointCandidate?> resolve({String? preferredBaseUrl}) async {
    final candidate = _candidateFor(preferredBaseUrl);
    if (await canReach(candidate.baseUrl)) {
      return candidate;
    }

    return null;
  }

  Future<bool> canReach(String baseUrl) async {
    final probe = _probe;
    if (probe != null) {
      return probe(AppRuntimeConfig.normalizeBaseUrl(baseUrl), _probeTimeout);
    }

    try {
      final normalizedBaseUrl = AppRuntimeConfig.normalizeBaseUrl(baseUrl);
      final response = await _httpClient
          .get(
            Uri.parse('$normalizedBaseUrl/api/health').replace(
              queryParameters: {
                '_': DateTime.now().millisecondsSinceEpoch.toString(),
              },
            ),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_probeTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return false;
      }

      return decoded['status'] == 'ok' && decoded['service'] == 'gesit';
    } catch (_) {
      return false;
    }
  }

  ServerEndpointCandidate _candidateFor(String? preferredBaseUrl) {
    final rawValue = preferredBaseUrl?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return defaultCandidate;
    }

    final normalized = AppRuntimeConfig.normalizePersistedBaseUrl(rawValue);
    if (normalized == defaultCandidate.baseUrl) {
      return defaultCandidate;
    }

    return ServerEndpointCandidate(
      id: 'saved',
      baseUrl: normalized,
      title: 'Jalur terakhir',
      subtitle: 'Koneksi yang terakhir berhasil',
    );
  }

  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
