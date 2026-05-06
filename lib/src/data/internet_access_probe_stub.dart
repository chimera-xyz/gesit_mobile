import 'dart:async';

import 'package:http/http.dart' as http;

const _internetProbeUrls = <String>[
  'https://www.gstatic.com/generate_204',
  'https://www.cloudflare.com/cdn-cgi/trace',
];

Future<bool> hasInternetAccess({
  Duration timeout = const Duration(seconds: 4),
}) async {
  for (final rawUrl in _internetProbeUrls) {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(rawUrl), headers: const {'Cache-Control': 'no-cache'})
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return true;
      }
    } catch (_) {
      // Try the next public endpoint before deciding the device is offline.
    } finally {
      client.close();
    }
  }

  return false;
}
