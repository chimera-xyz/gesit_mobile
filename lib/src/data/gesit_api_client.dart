import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_runtime_config.dart';
import '../models/app_models.dart';
import '../models/session_models.dart';
import 'gesit_http_client_factory.dart';

class GesitApiException implements Exception {
  const GesitApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthenticatedApiPayload {
  const AuthenticatedApiPayload({
    required this.user,
    required this.cookies,
    this.biometricToken,
    this.biometricExpiresAt,
  });

  final AuthenticatedUser user;
  final Map<String, String> cookies;
  final String? biometricToken;
  final DateTime? biometricExpiresAt;
}

class BiometricEnrollmentPayload {
  const BiometricEnrollmentPayload({
    required this.token,
    required this.cookies,
    this.expiresAt,
    this.deviceId,
  });

  final String token;
  final Map<String, String> cookies;
  final DateTime? expiresAt;
  final String? deviceId;
}

class ApiMultipartFilePayload {
  const ApiMultipartFilePayload({
    required this.fileName,
    this.path,
    this.bytes,
    this.contentType,
  });

  final String fileName;
  final String? path;
  final List<int>? bytes;
  final String? contentType;
}

class JsonApiPayload {
  const JsonApiPayload({required this.data, required this.cookies});

  final Map<String, dynamic> data;
  final Map<String, String> cookies;
}

class BinaryApiPayload {
  const BinaryApiPayload({
    required this.bytes,
    required this.cookies,
    this.contentType,
    this.fileName,
  });

  final Uint8List bytes;
  final Map<String, String> cookies;
  final String? contentType;
  final String? fileName;
}

class GesitApiClient {
  GesitApiClient({http.Client? httpClient, bool? browserManagedCookies})
    : _httpClient = httpClient ?? createGesitHttpClient(),
      _browserManagedCookies =
          browserManagedCookies ?? usesBrowserManagedCookies;

  final http.Client _httpClient;
  final bool _browserManagedCookies;

  static const Duration _requestTimeout = Duration(seconds: 18);
  static const Duration _knowledgeAssistantTimeout = Duration(seconds: 45);
  static const Duration _streamConnectTimeout = Duration(seconds: 8);

  Future<AuthenticatedApiPayload> signIn({
    required String baseUrl,
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    final response =
        await (_browserManagedCookies
                ? _httpClient.post(
                    _buildUri(baseUrl, '/api/auth/login'),
                    headers: _requestHeaders,
                    body: {
                      'email': email.trim(),
                      'password': password,
                      'remember': rememberSession ? '1' : '0',
                    },
                  )
                : _httpClient.post(
                    _buildUri(baseUrl, '/api/auth/login'),
                    headers: _jsonHeaders,
                    body: jsonEncode({
                      'email': email.trim(),
                      'password': password,
                      'remember': rememberSession,
                    }),
                  ))
            .timeout(_requestTimeout);

    return _parseAuthenticatedPayload(response);
  }

  Future<AuthenticatedApiPayload> fetchCurrentUser({
    required String baseUrl,
    required Map<String, String> cookies,
  }) async {
    final response = await _httpClient
        .get(
          _buildUri(baseUrl, '/api/user'),
          headers: _headersWithCookies(_requestHeaders, cookies),
        )
        .timeout(_requestTimeout);

    final payload = _parseAuthenticatedPayload(response);
    return AuthenticatedApiPayload(
      user: payload.user,
      cookies: _mergeCookies(cookies, payload.cookies),
      biometricToken: payload.biometricToken,
      biometricExpiresAt: payload.biometricExpiresAt,
    );
  }

  Future<BiometricEnrollmentPayload> enrollMobileBiometric({
    required String baseUrl,
    required Map<String, String> cookies,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final payload = await _postJson(
      baseUrl: baseUrl,
      path: '/api/auth/biometric-enroll',
      cookies: cookies,
      body: {
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform,
      },
    );

    final token = '${payload.data['biometric_token'] ?? ''}'.trim();
    if (token.isEmpty) {
      throw const GesitApiException(
        'Server tidak mengembalikan token fingerprint yang valid.',
      );
    }

    return BiometricEnrollmentPayload(
      token: token,
      cookies: payload.cookies,
      deviceId: '${payload.data['device_id'] ?? ''}'.trim(),
      expiresAt: DateTime.tryParse('${payload.data['expires_at'] ?? ''}'),
    );
  }

  Future<AuthenticatedApiPayload> signInWithBiometricToken({
    required String baseUrl,
    required String biometricToken,
  }) async {
    final response =
        await (_browserManagedCookies
                ? _httpClient.post(
                    _buildUri(baseUrl, '/api/auth/biometric-login'),
                    headers: _requestHeaders,
                    body: {'biometric_token': biometricToken.trim()},
                  )
                : _httpClient.post(
                    _buildUri(baseUrl, '/api/auth/biometric-login'),
                    headers: _jsonHeaders,
                    body: jsonEncode({
                      'biometric_token': biometricToken.trim(),
                    }),
                  ))
            .timeout(_requestTimeout);

    return _parseAuthenticatedPayload(response);
  }

  Future<void> signOut({
    required String baseUrl,
    required Map<String, String> cookies,
  }) async {
    final response = await _httpClient
        .post(
          _buildUri(baseUrl, '/api/auth/logout'),
          headers: _headersWithCookies(_requestHeaders, cookies),
        )
        .timeout(_requestTimeout);

    if (response.statusCode >= 400 && response.statusCode != 401) {
      throw _buildApiException(response);
    }
  }

  Future<JsonApiPayload> fetchForms({
    required String baseUrl,
    required Map<String, String> cookies,
  }) {
    return _getJson(baseUrl: baseUrl, path: '/api/forms', cookies: cookies);
  }

  Future<JsonApiPayload> fetchSubmissions({
    required String baseUrl,
    required Map<String, String> cookies,
    Map<String, String> queryParameters = const {},
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/form-submissions',
      cookies: cookies,
      queryParameters: queryParameters,
    );
  }

  Future<JsonApiPayload> fetchSubmissionDetail({
    required String baseUrl,
    required Map<String, String> cookies,
    required String submissionId,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/form-submissions/$submissionId',
      cookies: cookies,
    );
  }

  Future<BinaryApiPayload> fetchSubmissionPdfPreview({
    required String baseUrl,
    required Map<String, String> cookies,
    required String submissionId,
  }) {
    return _getBinary(
      baseUrl: baseUrl,
      path: '/api/pdf/stream/$submissionId',
      cookies: cookies,
      accept: 'application/pdf',
    );
  }

  Future<JsonApiPayload> createSubmission({
    required String baseUrl,
    required Map<String, String> cookies,
    required String formId,
    required Map<String, dynamic> formData,
    Map<String, ApiMultipartFilePayload> files = const {},
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _buildUri(baseUrl, '/api/form-submissions'),
    );
    request.headers.addAll(_headersWithCookies(_requestHeaders, cookies));
    request.fields['form_id'] = formId;
    await _appendMultipartFormData(
      request: request,
      formData: formData,
      files: files,
    );

    return _sendMultipartRequest(request, cookies: cookies);
  }

  Future<JsonApiPayload> approveSubmission({
    required String baseUrl,
    required Map<String, String> cookies,
    required String submissionId,
    String? notes,
    String? signatureId,
    Map<String, dynamic>? formData,
  }) {
    return _putJson(
      baseUrl: baseUrl,
      path: '/api/form-submissions/$submissionId/approve',
      cookies: cookies,
      body: {
        if (notes != null) 'notes': notes,
        if (signatureId != null) 'signature_id': signatureId,
        if (formData != null) 'form_data': formData,
      },
    );
  }

  Future<JsonApiPayload> rejectSubmission({
    required String baseUrl,
    required Map<String, String> cookies,
    required String submissionId,
    required String rejectionReason,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/form-submissions/$submissionId/reject',
      cookies: cookies,
      body: {'rejection_reason': rejectionReason},
    );
  }

  Future<JsonApiPayload> fetchFeed({
    required String baseUrl,
    required Map<String, String> cookies,
    int page = 1,
    int perPage = 10,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/feed',
      cookies: cookies,
      queryParameters: {'page': '$page', 'per_page': '$perPage'},
    );
  }

  Future<JsonApiPayload> fetchFeedAudienceMembers({
    required String baseUrl,
    required Map<String, String> cookies,
    String? query,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/feed/audience-members',
      cookies: cookies,
      queryParameters: query == null || query.trim().isEmpty
          ? const <String, String>{}
          : {'query': query.trim()},
    );
  }

  Future<JsonApiPayload> createFeedPost({
    required String baseUrl,
    required Map<String, String> cookies,
    required String content,
    required String visibility,
    List<String> recipientUserIds = const <String>[],
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/feed/posts',
      cookies: cookies,
      body: {
        'content': content,
        'visibility': visibility,
        if (recipientUserIds.isNotEmpty) 'recipient_user_ids': recipientUserIds,
      },
    );
  }

  Future<JsonApiPayload> fetchFeedPost({
    required String baseUrl,
    required Map<String, String> cookies,
    required String postId,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/feed/posts/$postId',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> toggleFeedPostLike({
    required String baseUrl,
    required Map<String, String> cookies,
    required String postId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/feed/posts/$postId/likes/toggle',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> createFeedComment({
    required String baseUrl,
    required Map<String, String> cookies,
    required String postId,
    required String content,
    String? parentId,
    List<String> mentionedUserIds = const <String>[],
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/feed/posts/$postId/comments',
      cookies: cookies,
      body: {
        'content': content,
        if (parentId != null && parentId.trim().isNotEmpty)
          'parent_id': parentId.trim(),
        if (mentionedUserIds.isNotEmpty) 'mentioned_user_ids': mentionedUserIds,
      },
    );
  }

  Future<JsonApiPayload> toggleFeedCommentLike({
    required String baseUrl,
    required Map<String, String> cookies,
    required String commentId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/feed/comments/$commentId/likes/toggle',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> deleteFeedPost({
    required String baseUrl,
    required Map<String, String> cookies,
    required String postId,
  }) {
    return _deleteJson(
      baseUrl: baseUrl,
      path: '/api/feed/posts/$postId',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> deleteFeedComment({
    required String baseUrl,
    required Map<String, String> cookies,
    required String commentId,
  }) {
    return _deleteJson(
      baseUrl: baseUrl,
      path: '/api/feed/comments/$commentId',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> fetchNotifications({
    required String baseUrl,
    required Map<String, String> cookies,
    int perPage = 50,
    bool unreadOnly = false,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/notifications',
      cookies: cookies,
      queryParameters: {
        'per_page': '$perPage',
        'unread_only': unreadOnly ? '1' : '0',
      },
    );
  }

  Future<JsonApiPayload> fetchUnreadNotificationFeed({
    required String baseUrl,
    required Map<String, String> cookies,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/notifications/unread-feed',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> markNotificationRead({
    required String baseUrl,
    required Map<String, String> cookies,
    required String notificationId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/notifications/$notificationId/read',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> markAllNotificationsRead({
    required String baseUrl,
    required Map<String, String> cookies,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/notifications/read-all',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> deleteNotification({
    required String baseUrl,
    required Map<String, String> cookies,
    required String notificationId,
  }) {
    return _deleteJson(
      baseUrl: baseUrl,
      path: '/api/notifications/$notificationId',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> deleteAllNotifications({
    required String baseUrl,
    required Map<String, String> cookies,
  }) {
    return _deleteJson(
      baseUrl: baseUrl,
      path: '/api/notifications',
      cookies: cookies,
    );
  }

  Stream<JsonApiPayload> streamNotifications({
    required String baseUrl,
    required Map<String, String> cookies,
    required int afterId,
  }) async* {
    final request = http.Request(
      'GET',
      _buildUri(
        baseUrl,
        '/api/notifications/stream',
        queryParameters: {'after_id': '$afterId'},
      ),
    );
    request.headers.addAll(_headersWithCookies(_streamHeaders, cookies));

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(_streamConnectTimeout);

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      final response = await http.Response.fromStream(streamedResponse);
      throw _buildApiException(response);
    }

    final streamCookies = _mergeCookies(
      cookies,
      _extractCookiesFromHeaders(streamedResponse.headers),
    );

    yield* _decodeJsonServerSentEvents(
      streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    ).map((data) => JsonApiPayload(data: data, cookies: streamCookies));
  }

  Future<JsonApiPayload> registerPushDeviceToken({
    required String baseUrl,
    required Map<String, String> cookies,
    required String token,
    required String platform,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/notifications/devices',
      cookies: cookies,
      body: {'token': token, 'platform': platform},
    );
  }

  Future<JsonApiPayload> unregisterPushDeviceToken({
    required String baseUrl,
    required Map<String, String> cookies,
    required String token,
  }) {
    return _deleteJson(
      baseUrl: baseUrl,
      path: '/api/notifications/devices',
      cookies: cookies,
      queryParameters: {'token': token},
    );
  }

  Future<JsonApiPayload> drawSignature({
    required String baseUrl,
    required Map<String, String> cookies,
    required int approvalStepId,
    required String signatureDataUrl,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/signature/draw',
      cookies: cookies,
      body: {
        'approval_step_id': approvalStepId,
        'signature_data': signatureDataUrl,
      },
    );
  }

  Future<JsonApiPayload> fetchKnowledgeHub({
    required String baseUrl,
    required Map<String, String> cookies,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/knowledge-hub',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> fetchKnowledgeConversations({
    required String baseUrl,
    required Map<String, String> cookies,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/knowledge-hub/conversations',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> fetchKnowledgeConversation({
    required String baseUrl,
    required Map<String, String> cookies,
    required String conversationId,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/knowledge-hub/conversations/$conversationId',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> askKnowledgeAssistant({
    required String baseUrl,
    required Map<String, String> cookies,
    required String question,
    String? conversationId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/knowledge-hub/ask',
      cookies: cookies,
      body: {
        'question': question,
        if (conversationId != null && conversationId.trim().isNotEmpty)
          'conversation_id': conversationId.trim(),
      },
      timeout: _knowledgeAssistantTimeout,
    );
  }

  Future<JsonApiPayload> toggleKnowledgeBookmark({
    required String baseUrl,
    required Map<String, String> cookies,
    required String entryId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/knowledge-hub/entries/$entryId/bookmark',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> runKnowledgeConversationAction({
    required String baseUrl,
    required Map<String, String> cookies,
    required String conversationId,
    required String messageId,
    required String actionKey,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/knowledge-hub/conversations/$conversationId/actions',
      cookies: cookies,
      body: {'message_id': messageId, 'action_key': actionKey},
      timeout: _knowledgeAssistantTimeout,
    );
  }

  Future<JsonApiPayload> fetchChatWorkspace({
    required String baseUrl,
    required Map<String, String> cookies,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/chat/workspace',
      cookies: cookies,
    );
  }

  Future<JsonApiPayload> syncChatWorkspace({
    required String baseUrl,
    required Map<String, String> cookies,
    required int afterEventId,
    int waitSeconds = 10,
  }) {
    return _getJson(
      baseUrl: baseUrl,
      path: '/api/chat/sync',
      cookies: cookies,
      queryParameters: {
        'after_event_id': '$afterEventId',
        'wait_seconds': '$waitSeconds',
      },
    );
  }

  Stream<JsonApiPayload> streamChatWorkspace({
    required String baseUrl,
    required Map<String, String> cookies,
    required int afterEventId,
  }) async* {
    final request = http.Request(
      'GET',
      _buildUri(
        baseUrl,
        '/api/chat/stream',
        queryParameters: {'after_event_id': '$afterEventId'},
      ),
    );
    request.headers.addAll(_headersWithCookies(_streamHeaders, cookies));

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(_streamConnectTimeout);

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      final response = await http.Response.fromStream(streamedResponse);
      throw _buildApiException(response);
    }

    final streamCookies = _mergeCookies(
      cookies,
      _extractCookiesFromHeaders(streamedResponse.headers),
    );

    yield* _decodeJsonServerSentEvents(
      streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    ).map((data) => JsonApiPayload(data: data, cookies: streamCookies));
  }

  Future<JsonApiPayload> ensureDirectConversation({
    required String baseUrl,
    required Map<String, String> cookies,
    required String participantUserId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/direct-conversations',
      cookies: cookies,
      body: {'participant_user_id': participantUserId},
    );
  }

  Future<JsonApiPayload> sendChatMessage({
    required String baseUrl,
    required Map<String, String> cookies,
    required String conversationId,
    required String text,
    String kind = 'text',
    String? clientToken,
    String? voiceNoteDuration,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/conversations/$conversationId/messages',
      cookies: cookies,
      body: {
        'kind': kind,
        'text': text,
        if (clientToken != null) 'client_token': clientToken,
        if (voiceNoteDuration != null) 'voice_note_duration': voiceNoteDuration,
      },
    );
  }

  Future<JsonApiPayload> sendChatAttachment({
    required String baseUrl,
    required Map<String, String> cookies,
    required String conversationId,
    required ApiMultipartFilePayload file,
    String caption = '',
    String? clientToken,
    String kind = 'attachment',
    String? voiceNoteDuration,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _buildUri(baseUrl, '/api/chat/conversations/$conversationId/attachments'),
    );
    request.headers.addAll(_headersWithCookies(_requestHeaders, cookies));
    request.fields['caption'] = caption;
    request.fields['kind'] = kind;
    if (clientToken != null && clientToken.trim().isNotEmpty) {
      request.fields['client_token'] = clientToken.trim();
    }
    if (voiceNoteDuration != null && voiceNoteDuration.trim().isNotEmpty) {
      request.fields['voice_note_duration'] = voiceNoteDuration.trim();
    }

    final mediaType = _parseMediaType(file.contentType);

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachment',
          file.bytes!,
          filename: file.fileName,
          contentType: mediaType,
        ),
      );
    } else if (file.path != null && file.path!.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'attachment',
          file.path!,
          filename: file.fileName,
          contentType: mediaType,
        ),
      );
    } else {
      throw const GesitApiException(
        'Lampiran tidak punya data file yang valid.',
      );
    }

    return _sendMultipartRequest(request, cookies: cookies);
  }

  Future<JsonApiPayload> markChatConversationRead({
    required String baseUrl,
    required Map<String, String> cookies,
    required String conversationId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/conversations/$conversationId/read',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> updateChatConversationPreferences({
    required String baseUrl,
    required Map<String, String> cookies,
    required String conversationId,
    bool? isPinned,
    bool? isMuted,
  }) {
    return _patchJson(
      baseUrl: baseUrl,
      path: '/api/chat/conversations/$conversationId/preferences',
      cookies: cookies,
      body: {
        if (isPinned != null) 'is_pinned': isPinned,
        if (isMuted != null) 'is_muted': isMuted,
      },
    );
  }

  Future<JsonApiPayload> startChatCall({
    required String baseUrl,
    required Map<String, String> cookies,
    required String conversationId,
    required ChatCallType type,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/conversations/$conversationId/calls',
      cookies: cookies,
      body: {'type': type.storageValue},
    );
  }

  Future<JsonApiPayload> acceptChatCall({
    required String baseUrl,
    required Map<String, String> cookies,
    required String callId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/calls/$callId/accept',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> declineChatCall({
    required String baseUrl,
    required Map<String, String> cookies,
    required String callId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/calls/$callId/decline',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> endChatCall({
    required String baseUrl,
    required Map<String, String> cookies,
    required String callId,
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/calls/$callId/end',
      cookies: cookies,
      body: const {},
    );
  }

  Future<JsonApiPayload> sendChatCallSignal({
    required String baseUrl,
    required Map<String, String> cookies,
    required String callId,
    required String type,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    return _postJson(
      baseUrl: baseUrl,
      path: '/api/chat/calls/$callId/signal',
      cookies: cookies,
      body: {'type': type, 'payload': payload},
    );
  }

  void close() {
    _httpClient.close();
  }

  Uri _buildUri(
    String baseUrl,
    String path, {
    Map<String, String> queryParameters = const {},
  }) {
    final normalizedBaseUrl = AppRuntimeConfig.normalizeBaseUrl(baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBaseUrl$normalizedPath');

    if (queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: {...uri.queryParameters, ...queryParameters},
    );
  }

  AuthenticatedApiPayload _parseAuthenticatedPayload(http.Response response) {
    final payload = _decodeResponseBody(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildApiException(response, payload: payload);
    }

    if (payload is! Map<String, dynamic>) {
      throw const GesitApiException('Respons server tidak valid.');
    }

    return AuthenticatedApiPayload(
      user: AuthenticatedUser.fromApiPayload(payload),
      cookies: _extractCookies(response),
      biometricToken: _normalizedOptionalString(payload['biometric_token']),
      biometricExpiresAt: DateTime.tryParse(
        '${payload['biometric_expires_at'] ?? ''}',
      ),
    );
  }

  String? _normalizedOptionalString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  MediaType? _parseMediaType(String? rawValue) {
    final normalized = rawValue?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    try {
      return MediaType.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  Future<JsonApiPayload> _getJson({
    required String baseUrl,
    required String path,
    required Map<String, String> cookies,
    Map<String, String> queryParameters = const {},
  }) async {
    final response = await _httpClient
        .get(
          _buildUri(baseUrl, path, queryParameters: queryParameters),
          headers: _headersWithCookies(_requestHeaders, cookies),
        )
        .timeout(_requestTimeout);

    return _parseJsonPayload(response, existingCookies: cookies);
  }

  Future<BinaryApiPayload> _getBinary({
    required String baseUrl,
    required String path,
    required Map<String, String> cookies,
    String accept = '*/*',
  }) async {
    final response = await _httpClient
        .get(
          _buildUri(baseUrl, path),
          headers: _headersWithCookies({'Accept': accept}, cookies),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildApiException(response);
    }

    return BinaryApiPayload(
      bytes: response.bodyBytes,
      cookies: _mergeCookies(cookies, _extractCookies(response)),
      contentType: response.headers['content-type'],
      fileName: _fileNameFromContentDisposition(
        response.headers['content-disposition'],
      ),
    );
  }

  Future<JsonApiPayload> _postJson({
    required String baseUrl,
    required String path,
    required Map<String, String> cookies,
    required Map<String, dynamic> body,
    Duration timeout = _requestTimeout,
  }) async {
    final response =
        await (_browserManagedCookies
                ? _httpClient.post(
                    _buildUri(baseUrl, path),
                    headers: _headersWithCookies(_requestHeaders, cookies),
                    body: _flattenFormBody(body),
                  )
                : _httpClient.post(
                    _buildUri(baseUrl, path),
                    headers: _headersWithCookies(_jsonHeaders, cookies),
                    body: jsonEncode(body),
                  ))
            .timeout(timeout);

    return _parseJsonPayload(response, existingCookies: cookies);
  }

  Future<JsonApiPayload> _putJson({
    required String baseUrl,
    required String path,
    required Map<String, String> cookies,
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient
        .put(
          _buildUri(baseUrl, path),
          headers: _headersWithCookies(_jsonHeaders, cookies),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    return _parseJsonPayload(response, existingCookies: cookies);
  }

  Future<JsonApiPayload> _patchJson({
    required String baseUrl,
    required String path,
    required Map<String, String> cookies,
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient
        .patch(
          _buildUri(baseUrl, path),
          headers: _headersWithCookies(_jsonHeaders, cookies),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    return _parseJsonPayload(response, existingCookies: cookies);
  }

  Future<JsonApiPayload> _deleteJson({
    required String baseUrl,
    required String path,
    required Map<String, String> cookies,
    Map<String, String> queryParameters = const {},
  }) async {
    final response = await _httpClient
        .delete(
          _buildUri(baseUrl, path, queryParameters: queryParameters),
          headers: _headersWithCookies(_requestHeaders, cookies),
        )
        .timeout(_requestTimeout);

    return _parseJsonPayload(response, existingCookies: cookies);
  }

  Future<JsonApiPayload> _sendMultipartRequest(
    http.MultipartRequest request, {
    required Map<String, String> cookies,
  }) async {
    final streamedResponse = await _httpClient
        .send(request)
        .timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _parseJsonPayload(response, existingCookies: cookies);
  }

  JsonApiPayload _parseJsonPayload(
    http.Response response, {
    required Map<String, String> existingCookies,
  }) {
    final payload = _decodeResponseBody(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildApiException(response, payload: payload);
    }

    if (payload is! Map<String, dynamic>) {
      throw const GesitApiException('Respons server tidak valid.');
    }

    return JsonApiPayload(
      data: payload,
      cookies: _mergeCookies(existingCookies, _extractCookies(response)),
    );
  }

  GesitApiException _buildApiException(
    http.Response response, {
    Object? payload,
  }) {
    final decodedPayload = payload ?? _decodeResponseBody(response);
    final message =
        _extractErrorMessage(decodedPayload) ??
        'Permintaan ke server gagal (${response.statusCode}).';

    return GesitApiException(message, statusCode: response.statusCode);
  }

  Object? _decodeResponseBody(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }

    final body = utf8.decode(response.bodyBytes);

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _extractErrorMessage(Object? payload) {
    if (payload is String) {
      final normalized = payload.trim();
      return normalized.isEmpty ? null : normalized;
    }

    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final directMessage = payload['message']?.toString().trim();
    if (directMessage != null && directMessage.isNotEmpty) {
      return directMessage;
    }

    final directError = payload['error']?.toString().trim();
    if (directError != null && directError.isNotEmpty) {
      return directError;
    }

    final rawMessages = payload['messages'];
    if (rawMessages is Map<String, dynamic>) {
      for (final entry in rawMessages.values) {
        if (entry is List && entry.isNotEmpty) {
          final firstMessage = entry.first.toString().trim();
          if (firstMessage.isNotEmpty) {
            return firstMessage;
          }
        }

        final singleMessage = entry?.toString().trim();
        if (singleMessage != null && singleMessage.isNotEmpty) {
          return singleMessage;
        }
      }
    }

    return null;
  }

  String? _fileNameFromContentDisposition(String? rawHeader) {
    final header = rawHeader?.trim();
    if (header == null || header.isEmpty) {
      return null;
    }

    final utf8Match = RegExp(
      "filename\\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(header);
    if (utf8Match != null) {
      final rawFileName = utf8Match.group(1);
      if (rawFileName != null && rawFileName.trim().isNotEmpty) {
        return Uri.decodeComponent(rawFileName.trim());
      }
    }

    final quotedMatch = RegExp(
      'filename="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(header);
    if (quotedMatch != null) {
      final rawFileName = quotedMatch.group(1)?.trim();
      if (rawFileName != null && rawFileName.isNotEmpty) {
        return rawFileName;
      }
    }

    final plainMatch = RegExp(
      r'filename=([^;]+)',
      caseSensitive: false,
    ).firstMatch(header);
    final rawFileName = plainMatch?.group(1)?.trim();
    return rawFileName == null || rawFileName.isEmpty ? null : rawFileName;
  }

  Map<String, String> get _requestHeaders {
    return const {'Accept': 'application/json'};
  }

  Map<String, String> get _jsonHeaders {
    return {..._requestHeaders, 'Content-Type': 'application/json'};
  }

  Map<String, String> get _streamHeaders {
    return {
      ..._requestHeaders,
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    };
  }

  Map<String, String> _flattenFormBody(Map<String, dynamic> body) {
    final flattened = <String, String>{};

    void visit(String key, Object? value) {
      if (value == null) {
        return;
      }

      if (value is Map) {
        for (final entry in value.entries) {
          final nestedKey = '$key[${entry.key}]';
          visit(nestedKey, entry.value);
        }
        return;
      }

      if (value is bool) {
        flattened[key] = value ? '1' : '0';
        return;
      }

      flattened[key] = value.toString();
    }

    for (final entry in body.entries) {
      visit(entry.key, entry.value);
    }

    return flattened;
  }

  Map<String, String> _headersWithCookies(
    Map<String, String> baseHeaders,
    Map<String, String> cookies,
  ) {
    if (_browserManagedCookies || cookies.isEmpty) {
      return baseHeaders;
    }

    return {
      ...baseHeaders,
      'Cookie': cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; '),
    };
  }

  Map<String, String> _extractCookies(http.Response response) {
    return _extractCookiesFromHeaders(response.headers);
  }

  Map<String, String> _extractCookiesFromHeaders(Map<String, String> headers) {
    if (_browserManagedCookies) {
      return const <String, String>{};
    }

    final rawSetCookieHeader = headers['set-cookie'];
    if (rawSetCookieHeader == null || rawSetCookieHeader.trim().isEmpty) {
      return const <String, String>{};
    }

    final cookies = <String, String>{};
    final cookieEntries = rawSetCookieHeader.split(
      RegExp(r',(?=\s*[A-Za-z0-9_\-]+=)'),
    );

    for (final cookieEntry in cookieEntries) {
      final trimmedEntry = cookieEntry.trim();
      if (trimmedEntry.isEmpty) {
        continue;
      }

      final firstSegment = trimmedEntry.split(';').first.trim();
      final separatorIndex = firstSegment.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final name = firstSegment.substring(0, separatorIndex).trim();
      final value = firstSegment.substring(separatorIndex + 1).trim();
      if (name.isEmpty || value.isEmpty) {
        continue;
      }

      cookies[name] = value;
    }

    return cookies;
  }

  Map<String, String> _mergeCookies(
    Map<String, String> currentCookies,
    Map<String, String> nextCookies,
  ) {
    if (nextCookies.isEmpty) {
      return Map<String, String>.from(currentCookies);
    }

    return {...currentCookies, ...nextCookies};
  }

  Future<void> _appendMultipartFormData({
    required http.MultipartRequest request,
    required Map<String, dynamic> formData,
    required Map<String, ApiMultipartFilePayload> files,
  }) async {
    formData.forEach((fieldId, value) {
      if (value == null) {
        return;
      }
    });

    for (final entry in formData.entries) {
      final fieldId = entry.key;
      final value = entry.value;

      if (value is Iterable) {
        for (final item in value) {
          final normalized = _stringifyFieldValue(item);
          if (normalized == null || normalized.isEmpty) {
            continue;
          }

          request.files.add(
            http.MultipartFile.fromString('form_data[$fieldId][]', normalized),
          );
        }

        return;
      }

      final normalized = _stringifyFieldValue(value);
      if (normalized == null) {
        return;
      }

      request.fields['form_data[$fieldId]'] = normalized;
    }

    for (final entry in files.entries) {
      final payload = entry.value;
      final fieldKey = 'form_data[${entry.key}]';

      if (payload.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldKey,
            payload.bytes!,
            filename: payload.fileName,
          ),
        );
        continue;
      }

      if (payload.path != null && payload.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            fieldKey,
            payload.path!,
            filename: payload.fileName,
          ),
        );
      }
    }
  }

  String? _stringifyFieldValue(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    if (value is num || value is bool) {
      return '$value';
    }

    return value.toString();
  }
}

Stream<Map<String, dynamic>> _decodeJsonServerSentEvents(
  Stream<String> lines,
) async* {
  String? eventName;
  String? eventId;
  final dataLines = <String>[];

  Map<String, dynamic>? decodePendingEvent() {
    if (dataLines.isEmpty) {
      return null;
    }

    final data = dataLines.join('\n').trim();
    if (data.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final payload = Map<String, dynamic>.from(decoded);
    if (eventId != null &&
        eventId!.trim().isNotEmpty &&
        !payload.containsKey('last_event_id')) {
      final parsedEventId = int.tryParse(eventId!.trim());
      if (parsedEventId != null) {
        payload['last_event_id'] = parsedEventId;
      }
    }
    if (eventName != null &&
        eventName!.trim().isNotEmpty &&
        !payload.containsKey('event')) {
      payload['event'] = eventName!.trim();
    }

    return payload;
  }

  void resetPendingEvent() {
    eventName = null;
    eventId = null;
    dataLines.clear();
  }

  await for (final rawLine in lines) {
    final line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;

    if (line.isEmpty) {
      final payload = decodePendingEvent();
      if (payload != null) {
        yield payload;
      }
      resetPendingEvent();
      continue;
    }

    if (line.startsWith(':')) {
      continue;
    }

    final separatorIndex = line.indexOf(':');
    final field = separatorIndex == -1
        ? line
        : line.substring(0, separatorIndex);
    var value = separatorIndex == -1 ? '' : line.substring(separatorIndex + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }

    switch (field) {
      case 'event':
        eventName = value;
      case 'id':
        eventId = value;
      case 'data':
        dataLines.add(value);
    }
  }

  final payload = decodePendingEvent();
  if (payload != null) {
    yield payload;
  }
}
