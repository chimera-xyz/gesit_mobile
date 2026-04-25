class CallRuntimeConfig {
  const CallRuntimeConfig._();

  // Development override: fill TURN credentials here once the relay server is
  // available. Keeping this centralized avoids editing multiple call files.
  static const Map<String, String> debugTurnOverride = <String, String>{};
  static const String _turnUrlsFromEnvironment = String.fromEnvironment(
    'GESIT_TURN_URLS',
  );
  static const String _turnUsernameFromEnvironment = String.fromEnvironment(
    'GESIT_TURN_USERNAME',
  );
  static const String _turnCredentialFromEnvironment = String.fromEnvironment(
    'GESIT_TURN_CREDENTIAL',
  );

  static const List<String> defaultStunUrls = <String>[
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ];

  static List<Map<String, dynamic>> get iceServers {
    final servers = <Map<String, dynamic>>[
      <String, dynamic>{'urls': List<String>.from(defaultStunUrls)},
    ];
    final rawTurnUrls =
        _normalizedValue(debugTurnOverride['urls']) ??
        _normalizedValue(_turnUrlsFromEnvironment);
    if (rawTurnUrls == null || rawTurnUrls.isEmpty) {
      return List<Map<String, dynamic>>.unmodifiable(servers);
    }

    final urls = rawTurnUrls
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      return List<Map<String, dynamic>>.unmodifiable(servers);
    }

    servers.add(<String, dynamic>{
      'urls': urls.length == 1 ? urls.first : urls,
      if ((_normalizedValue(debugTurnOverride['username']) ??
              _normalizedValue(_turnUsernameFromEnvironment)) !=
          null)
        'username':
            _normalizedValue(debugTurnOverride['username']) ??
            _normalizedValue(_turnUsernameFromEnvironment),
      if ((_normalizedValue(debugTurnOverride['credential']) ??
              _normalizedValue(_turnCredentialFromEnvironment)) !=
          null)
        'credential':
            _normalizedValue(debugTurnOverride['credential']) ??
            _normalizedValue(_turnCredentialFromEnvironment),
    });

    return List<Map<String, dynamic>>.unmodifiable(servers);
  }

  static int get activeCallSyncWaitSeconds => 1;

  static bool get chatRealtimeStreamEnabled => true;

  static Duration get chatRealtimeStreamRetryDelay =>
      const Duration(milliseconds: 450);

  static Duration get chatShortPollingInterval =>
      const Duration(milliseconds: 1500);

  static Duration get activeCallShortPollingInterval =>
      const Duration(milliseconds: 700);
}

String? _normalizedValue(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}
