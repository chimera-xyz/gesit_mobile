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

  test(
    'browser managed meeting creation serializes arrays as form fields',
    () async {
      late http.Request capturedRequest;

      final client = GesitApiClient(
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return _jsonResponse({
            'meeting': {'id': 4},
          }, statusCode: 201);
        }),
        browserManagedCookies: true,
      );

      await client.createMeeting(
        baseUrl: 'http://127.0.0.1:8000',
        cookies: const {},
        title: 'Daily IT',
        agenda: 'Sync kerja harian',
        participantUserIds: const ['10', '11'],
        cohostUserIds: const ['11'],
        settings: const {
          'waiting_room_enabled': false,
          'record_by_default': true,
          'allow_participant_screen_share': true,
          'chat_enabled': true,
          'polls_enabled': false,
        },
      );

      final bodyFields = Uri.splitQueryString(capturedRequest.body);

      expect(capturedRequest.url.path, '/api/meetings');
      expect(
        capturedRequest.headers['content-type'],
        contains('application/x-www-form-urlencoded'),
      );
      expect(bodyFields['title'], 'Daily IT');
      expect(bodyFields['agenda'], 'Sync kerja harian');
      expect(bodyFields['participant_user_ids[0]'], '10');
      expect(bodyFields['participant_user_ids[1]'], '11');
      expect(bodyFields['cohost_user_ids[0]'], '11');
      expect(bodyFields['settings[waiting_room_enabled]'], '0');
      expect(bodyFields['settings[record_by_default]'], '1');
      expect(bodyFields['settings[polls_enabled]'], '0');
    },
  );

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

  test(
    'create submission sends procurement items as nested multipart fields',
    () async {
      late http.Request capturedRequest;

      final client = GesitApiClient(
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return _jsonResponse({
            'success': true,
            'submission': {'id': 42},
          }, statusCode: 201);
        }),
        browserManagedCookies: false,
      );

      await client.createSubmission(
        baseUrl: 'http://127.0.0.1:8000',
        cookies: const {'gesit_session': 'old-cookie'},
        formId: '7',
        formData: const {
          'item_type': 'Hardware',
          'items': [
            {
              'description': 'SSD 512GB',
              'quantity': 1,
              'unit_price': 1800000,
              'specifications': 'NVMe Gen 4 untuk workstation.',
            },
          ],
        },
      );

      final body = utf8.decode(capturedRequest.bodyBytes);

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/form-submissions');
      expect(capturedRequest.headers['cookie'], contains('old-cookie'));
      expect(body, contains('name="form_id"'));
      expect(body, contains('7'));
      expect(body, contains('name="form_data[items][0][description]"'));
      expect(body, contains('SSD 512GB'));
      expect(body, contains('name="form_data[items][0][quantity]"'));
      expect(body, contains('1'));
      expect(body, contains('name="form_data[items][0][unit_price]"'));
      expect(body, contains('1800000'));
      expect(body, contains('name="form_data[items][0][specifications]"'));
      expect(body, contains('NVMe Gen 4 untuk workstation.'));
    },
  );

  test(
    'create submission serializes grouped attachments as multipart files',
    () async {
      late http.Request capturedRequest;

      final client = GesitApiClient(
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return _jsonResponse({
            'success': true,
            'submission': {'id': 42},
          }, statusCode: 201);
        }),
        browserManagedCookies: false,
      );

      await client.createSubmission(
        baseUrl: 'http://127.0.0.1:8000',
        cookies: const {'gesit_session': 'old-cookie'},
        formId: '7',
        formData: const {'amount': 350000},
        fileGroups: const {
          'receipt_attachment': [
            ApiMultipartFilePayload(
              fileName: 'kwitansi.pdf',
              bytes: [37, 80, 68, 70],
              contentType: 'application/pdf',
            ),
            ApiMultipartFilePayload(
              fileName: 'struk.jpg',
              bytes: [255, 216, 255, 217],
              contentType: 'image/jpeg',
            ),
          ],
        },
      );

      final body = latin1.decode(capturedRequest.bodyBytes).toLowerCase();

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/form-submissions');
      expect(body, contains('name="form_data[receipt_attachment][0]"'));
      expect(body, contains('filename="kwitansi.pdf"'));
      expect(body, contains('content-type: application/pdf'));
      expect(body, contains('name="form_data[receipt_attachment][1]"'));
      expect(body, contains('filename="struk.jpg"'));
      expect(body, contains('content-type: image/jpeg'));
    },
  );

  test('create leave request posts date-only JSON payload', () async {
    late http.Request capturedRequest;

    final client = GesitApiClient(
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          'success': true,
          'request': {'id': 9},
        }, statusCode: 201);
      }),
      browserManagedCookies: false,
    );

    await client.createLeaveRequest(
      baseUrl: 'http://127.0.0.1:8000',
      cookies: const {'gesit_session': 'old-cookie'},
      leaveTypeId: '1',
      replacementUserId: '22',
      startDate: DateTime(2026, 8, 14, 9),
      endDate: DateTime(2026, 8, 17, 18),
      reason: 'Extend long weekend Hari Kemerdekaan.',
      requesterSignatureDataUrl: 'data:image/png;base64,abc123',
      delegationNotes: 'Catatan ke tim operasional.',
    );

    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/leaves/requests');
    expect(capturedRequest.headers['cookie'], contains('old-cookie'));
    expect(body['leave_type_id'], '1');
    expect(body['replacement_user_id'], '22');
    expect(body['start_date'], '2026-08-14');
    expect(body['end_date'], '2026-08-17');
    expect(body['reason'], 'Extend long weekend Hari Kemerdekaan.');
    expect(body['requester_signature_data'], 'data:image/png;base64,abc123');
    expect(body['delegation_notes'], 'Catatan ke tim operasional.');
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
