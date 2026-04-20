class CallRuntimeConfig {
  const CallRuntimeConfig._();

  // Development override: fill TURN credentials here once the relay server is
  // available. Keeping this centralized avoids editing multiple call files.
  static const Map<String, String> debugTurnOverride = <String, String>{};

  static const List<String> defaultStunUrls = <String>[
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ];

  static List<Map<String, dynamic>> get iceServers {
    final servers = <Map<String, dynamic>>[
      <String, dynamic>{'urls': List<String>.from(defaultStunUrls)},
    ];
    final rawTurnUrls = debugTurnOverride['urls']?.trim();
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
      if ((debugTurnOverride['username'] ?? '').trim().isNotEmpty)
        'username': debugTurnOverride['username']!.trim(),
      if ((debugTurnOverride['credential'] ?? '').trim().isNotEmpty)
        'credential': debugTurnOverride['credential']!.trim(),
    });

    return List<Map<String, dynamic>>.unmodifiable(servers);
  }

  static int get activeCallSyncWaitSeconds => 2;
}
