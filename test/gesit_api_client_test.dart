import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'browser managed chat signal requests use form fields to avoid extra preflight',
    () async {
      late http.Request capturedRequest;

      final client = GesitApiClient(
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return _jsonResponse({'ok': true});
        }),
        browserManagedCookies: true,
      );

      await client.sendChatCallSignal(
        baseUrl: 'http://127.0.0.1:8000',
        cookies: const {},
        callId: 'call-1',
        type: 'media_state',
        payload: const {
          'mic_enabled': false,
          'camera_enabled': true,
          'call_type': 'voice',
        },
      );

      final bodyFields = Uri.splitQueryString(capturedRequest.body);

      expect(
        capturedRequest.headers['content-type'],
        contains('application/x-www-form-urlencoded'),
      );
      expect(bodyFields['type'], 'media_state');
      expect(bodyFields['payload[mic_enabled]'], '0');
      expect(bodyFields['payload[camera_enabled]'], '1');
      expect(bodyFields['payload[call_type]'], 'voice');
    },
  );
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
