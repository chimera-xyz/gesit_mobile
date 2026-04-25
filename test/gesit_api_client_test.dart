import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('chat workspace stream decodes SSE payloads', () async {
    late http.Request capturedRequest;

    final client = GesitApiClient(
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          ': connected\n'
          'event: workspace\n'
          'id: 8\n'
          'data: {"has_changes":true,\n'
          'data: "workspace":{"last_event_id":8},"events":[]}\n'
          '\n'
          'data: {"has_changes":false,"last_event_id":9}\n'
          '\n',
          200,
          headers: {
            'content-type': 'text/event-stream',
            'set-cookie': 'gesit_session=new-session; Path=/; HttpOnly',
          },
        );
      }),
      browserManagedCookies: false,
    );

    final payloads = await client
        .streamChatWorkspace(
          baseUrl: 'http://127.0.0.1:8000',
          cookies: const {'gesit_session': 'old-session'},
          afterEventId: 7,
        )
        .toList();

    expect(capturedRequest.url.path, '/api/chat/stream');
    expect(capturedRequest.url.queryParameters['after_event_id'], '7');
    expect(capturedRequest.headers['accept'], 'text/event-stream');
    expect(capturedRequest.headers['cache-control'], 'no-cache');
    expect(capturedRequest.headers['cookie'], contains('old-session'));

    expect(payloads, hasLength(2));
    expect(payloads.first.data['last_event_id'], 8);
    expect(payloads.first.data['event'], 'workspace');
    expect(payloads.first.cookies['gesit_session'], 'new-session');
    expect(payloads.last.data['has_changes'], isFalse);
    expect(payloads.last.data['last_event_id'], 9);
  });

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

  test(
    'browser managed knowledge assistant requests use form fields',
    () async {
      late http.Request capturedRequest;

      final client = GesitApiClient(
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return _jsonResponse({
            'conversation': {'id': 7, 'title': 'Approval'},
            'user_message': {
              'id': 20,
              'role': 'user',
              'content': 'Ringkas SOP',
            },
            'assistant_message': {
              'id': 21,
              'role': 'assistant',
              'content': 'Siap.',
            },
          });
        }),
        browserManagedCookies: true,
      );

      await client.askKnowledgeAssistant(
        baseUrl: 'http://127.0.0.1:8000',
        cookies: const {},
        question: 'Ringkas SOP',
        conversationId: '7',
      );

      final bodyFields = Uri.splitQueryString(capturedRequest.body);

      expect(capturedRequest.url.path, '/api/knowledge-hub/ask');
      expect(
        capturedRequest.headers['content-type'],
        contains('application/x-www-form-urlencoded'),
      );
      expect(bodyFields['question'], 'Ringkas SOP');
      expect(bodyFields['conversation_id'], '7');
    },
  );

  test('browser managed knowledge action requests use form fields', () async {
    late http.Request capturedRequest;

    final client = GesitApiClient(
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          'conversation': {'id': 7, 'title': 'Approval'},
          'updated_message': {'id': 21, 'role': 'assistant', 'content': 'OK'},
          'user_message': {'id': 22, 'role': 'user', 'content': 'Buat ticket'},
          'assistant_message': {
            'id': 23,
            'role': 'assistant',
            'content': 'Ticket dibuat.',
          },
        });
      }),
      browserManagedCookies: true,
    );

    await client.runKnowledgeConversationAction(
      baseUrl: 'http://127.0.0.1:8000',
      cookies: const {},
      conversationId: '7',
      messageId: '21',
      actionKey: 's21plus_contact_it',
    );

    final bodyFields = Uri.splitQueryString(capturedRequest.body);

    expect(
      capturedRequest.url.path,
      '/api/knowledge-hub/conversations/7/actions',
    );
    expect(
      capturedRequest.headers['content-type'],
      contains('application/x-www-form-urlencoded'),
    );
    expect(bodyFields['message_id'], '21');
    expect(bodyFields['action_key'], 's21plus_contact_it');
  });

  test('submission PDF preview fetches bytes with session cookies', () async {
    late http.Request capturedRequest;
    final client = GesitApiClient(
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response.bytes(
          [0x25, 0x50, 0x44, 0x46],
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-disposition': 'inline; filename="GESIT_42.pdf"',
            'set-cookie': 'gesit_session=fresh-cookie; Path=/; HttpOnly',
          },
        );
      }),
      browserManagedCookies: false,
    );

    final payload = await client.fetchSubmissionPdfPreview(
      baseUrl: 'http://127.0.0.1:8000',
      cookies: const {'gesit_session': 'old-cookie'},
      submissionId: '42',
    );

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/api/pdf/stream/42');
    expect(capturedRequest.headers['accept'], 'application/pdf');
    expect(capturedRequest.headers['cookie'], contains('old-cookie'));
    expect(payload.bytes, [0x25, 0x50, 0x44, 0x46]);
    expect(payload.contentType, 'application/pdf');
    expect(payload.fileName, 'GESIT_42.pdf');
    expect(payload.cookies['gesit_session'], 'fresh-cookie');
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
