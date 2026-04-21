import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_runtime_config.dart';
import 'app_session_controller.dart';
import 'gesit_api_client.dart';

class KnowledgeWorkspaceController extends ChangeNotifier {
  KnowledgeWorkspaceController({
    required AppSessionController sessionController,
    GesitApiClient? apiClient,
  }) : _sessionController = sessionController,
       _apiClient = apiClient ?? GesitApiClient();

  static const List<String> fallbackSuggestedQuestions = [
    'Ringkas SOP approval pengadaan',
    'Bagaimana proses akses S21+ user baru?',
    'Dokumen apa yang dibutuhkan vendor onboarding?',
    'Buat checklist helpdesk kritikal',
  ];

  final AppSessionController _sessionController;
  final GesitApiClient _apiClient;

  bool _isLoading = false;
  bool _isConversationLoading = false;
  bool _isAsking = false;
  bool _isRunningAction = false;
  bool _loaded = false;
  String? _errorMessage;
  String? _lastFailedQuestion;
  String? _assistantLoadingMessage;
  String? _activeConversationId;
  List<KnowledgeHubSpace> _spaces = const <KnowledgeHubSpace>[];
  List<KnowledgeHubDocument> _documents = const <KnowledgeHubDocument>[];
  List<KnowledgeConversationSummary> _conversations =
      const <KnowledgeConversationSummary>[];
  List<KnowledgeAssistantMessage> _messages =
      const <KnowledgeAssistantMessage>[];
  List<String> _suggestedQuestions = fallbackSuggestedQuestions;

  bool get isLoading => _isLoading;
  bool get isConversationLoading => _isConversationLoading;
  bool get isAsking => _isAsking;
  bool get isRunningAction => _isRunningAction;
  bool get isAssistantBusy => _isAsking || _isRunningAction;
  String get assistantLoadingMessage =>
      _assistantLoadingMessage ?? 'Asisten sedang mengetik...';
  bool get loaded => _loaded;
  String? get errorMessage => _errorMessage;
  bool get canRetryLastQuestion =>
      _lastFailedQuestion != null &&
      !_isAsking &&
      _lastFailedQuestion!.isNotEmpty;
  String? get activeConversationId => _activeConversationId;
  List<KnowledgeHubSpace> get spaces => _spaces;
  List<KnowledgeHubDocument> get documents => _documents;
  List<KnowledgeConversationSummary> get conversations => _conversations;
  List<KnowledgeAssistantMessage> get messages => _messages;
  List<String> get suggestedQuestions => _suggestedQuestions;

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _isLoading) {
      return;
    }

    await refresh();
  }

  Future<void> refresh() async {
    final session = _sessionController.session;
    if (session == null) {
      return;
    }

    if (!session.user.canAccessKnowledgeHub) {
      _spaces = const <KnowledgeHubSpace>[];
      _documents = const <KnowledgeHubDocument>[];
      _conversations = const <KnowledgeConversationSummary>[];
      _messages = const <KnowledgeAssistantMessage>[];
      _loaded = true;
      _errorMessage = 'Akun ini belum punya akses Knowledge Hub.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var latestCookies = session.cookies;
      final hubPayload = await _apiClient.fetchKnowledgeHub(
        baseUrl: session.apiBaseUrl,
        cookies: latestCookies,
      );
      latestCookies = hubPayload.cookies;

      final conversationsPayload = await _apiClient.fetchKnowledgeConversations(
        baseUrl: session.apiBaseUrl,
        cookies: latestCookies,
      );
      latestCookies = conversationsPayload.cookies;
      await _sessionController.syncCookies(latestCookies);

      _applyHubPayload(hubPayload.data, baseUrl: session.apiBaseUrl);
      _applyConversationsPayload(conversationsPayload.data);
      _loaded = true;
      _errorMessage = null;
    } on GesitApiException catch (error) {
      await _handleApiException(error);
    } on TimeoutException {
      _errorMessage = 'Knowledge Hub terlalu lama merespons.';
    } catch (_) {
      _errorMessage = 'Knowledge Hub belum bisa dimuat dari server.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startNewConversation() {
    _activeConversationId = null;
    _messages = const <KnowledgeAssistantMessage>[];
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> openConversation(String conversationId) async {
    final session = _sessionController.session;
    if (session == null || conversationId.trim().isEmpty) {
      return;
    }

    _activeConversationId = conversationId.trim();
    _isConversationLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = await _apiClient.fetchKnowledgeConversation(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId.trim(),
      );
      await _sessionController.syncCookies(payload.cookies);

      final conversation = KnowledgeConversationSummary.fromJson(
        _asMap(payload.data['conversation']),
      );
      _replaceConversation(conversation);
      _messages = _asList(payload.data['messages'])
          .map((message) => KnowledgeAssistantMessage.fromJson(_asMap(message)))
          .where((message) => message.text.trim().isNotEmpty)
          .toList(growable: false);
      _activeConversationId = conversation.id;
      _errorMessage = null;
    } on GesitApiException catch (error) {
      await _handleApiException(error);
    } on TimeoutException {
      _errorMessage = 'Riwayat obrolan terlalu lama dimuat.';
    } catch (_) {
      _errorMessage = 'Riwayat obrolan belum bisa dimuat.';
    } finally {
      _isConversationLoading = false;
      notifyListeners();
    }
  }

  Future<void> ask(String question) async {
    final normalizedQuestion = question.trim();
    if (_shouldAnswerPendingTicketAction(normalizedQuestion)) {
      _messages = List<KnowledgeAssistantMessage>.unmodifiable([
        ..._messages,
        KnowledgeAssistantMessage.localUser(normalizedQuestion),
        const KnowledgeAssistantMessage.localAssistant(
          'Belum. Ticket baru benar-benar dibuat setelah Anda menekan tombol "Buat ticket ke Tim IT" pada jawaban asisten sebelumnya.',
        ),
      ]);
      _errorMessage = null;
      notifyListeners();
      return;
    }

    await _submitQuestion(question);
  }

  Future<void> retryLastQuestion() async {
    final question = _lastFailedQuestion;
    if (question == null || question.trim().isEmpty) {
      return;
    }

    await _submitQuestion(question, reuseLastUserMessage: true);
  }

  bool _shouldAnswerPendingTicketAction(String question) {
    if (question.isEmpty || isAssistantBusy) {
      return false;
    }

    final normalized = _normalizeIntentText(question);
    final mentionsTicket =
        normalized.contains('ticket') || normalized.contains('tiket');
    final asksTicketStatus =
        mentionsTicket &&
        (normalized.contains('dibuat') ||
            normalized.contains('sudah') ||
            normalized.contains('udah') ||
            normalized.contains('nomor') ||
            normalized.contains('mana'));
    if (!asksTicketStatus) {
      return false;
    }

    return _messages.any((message) {
      if (message.isUser) {
        return false;
      }

      return message.actions.any((action) {
        final haystack = _normalizeIntentText('${action.key} ${action.label}');
        return haystack.contains('ticket') ||
            haystack.contains('tiket') ||
            haystack.contains('contact it');
      });
    });
  }

  Future<void> _submitQuestion(
    String question, {
    bool reuseLastUserMessage = false,
  }) async {
    final session = _sessionController.session;
    final normalizedQuestion = question.trim();
    if (session == null || normalizedQuestion.isEmpty || isAssistantBusy) {
      return;
    }

    final conversationId = _activeConversationId;
    final currentMessages = List<KnowledgeAssistantMessage>.from(_messages);
    final canReuseLastUserMessage =
        reuseLastUserMessage &&
        currentMessages.isNotEmpty &&
        currentMessages.last.isUser &&
        currentMessages.last.text.trim() == normalizedQuestion;
    final baseMessages = canReuseLastUserMessage
        ? currentMessages.sublist(0, currentMessages.length - 1)
        : currentMessages;
    final optimisticUserMessage = canReuseLastUserMessage
        ? currentMessages.last
        : KnowledgeAssistantMessage.localUser(normalizedQuestion);

    _messages = List<KnowledgeAssistantMessage>.unmodifiable([
      ...baseMessages,
      optimisticUserMessage,
    ]);
    _isAsking = true;
    _assistantLoadingMessage = 'Asisten sedang mengetik...';
    _errorMessage = null;
    _lastFailedQuestion = null;
    notifyListeners();

    try {
      final payload = await _apiClient.askKnowledgeAssistant(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        question: normalizedQuestion,
        conversationId: conversationId,
      );
      await _sessionController.syncCookies(payload.cookies);

      final conversation = KnowledgeConversationSummary.fromJson(
        _asMap(payload.data['conversation']),
      );
      _replaceConversation(conversation);
      _activeConversationId = conversation.id;

      final userMessage =
          KnowledgeAssistantMessage.tryFromJson(
            _asMap(payload.data['user_message']),
          ) ??
          optimisticUserMessage;
      final assistantMessage =
          KnowledgeAssistantMessage.tryFromJson(
            _asMap(payload.data['assistant_message']),
          ) ??
          KnowledgeAssistantMessage.localAssistant(
            _normalizedString(payload.data['answer']) ??
                'Asisten belum mengembalikan jawaban.',
            sources: _asList(payload.data['sources'])
                .map(
                  (source) => KnowledgeAssistantSource.fromJson(_asMap(source)),
                )
                .toList(growable: false),
          );

      _messages = List<KnowledgeAssistantMessage>.unmodifiable([
        ...baseMessages,
        userMessage,
        assistantMessage,
      ]);
      _errorMessage = null;
      _lastFailedQuestion = null;
    } on GesitApiException catch (error) {
      await _handleApiException(error);
      if (error.statusCode != 401) {
        _lastFailedQuestion = normalizedQuestion;
        _messages = List<KnowledgeAssistantMessage>.unmodifiable([
          ...baseMessages,
          optimisticUserMessage,
        ]);
      }
    } on TimeoutException {
      _lastFailedQuestion = normalizedQuestion;
      _errorMessage =
          'Asisten belum menerima jawaban dari server. Coba lagi tanpa mengetik ulang.';
      _messages = List<KnowledgeAssistantMessage>.unmodifiable([
        ...baseMessages,
        optimisticUserMessage,
      ]);
    } catch (_) {
      _lastFailedQuestion = normalizedQuestion;
      _errorMessage = 'Asisten belum bisa memproses pertanyaan.';
      _messages = List<KnowledgeAssistantMessage>.unmodifiable([
        ...baseMessages,
        optimisticUserMessage,
      ]);
    } finally {
      _isAsking = false;
      _assistantLoadingMessage = null;
      notifyListeners();
    }
  }

  Future<void> runMessageAction({
    required KnowledgeAssistantMessage message,
    required KnowledgeConversationAction action,
  }) async {
    final session = _sessionController.session;
    final conversationId = _activeConversationId;
    if (session == null ||
        conversationId == null ||
        message.id.trim().isEmpty ||
        action.key.trim().isEmpty ||
        isAssistantBusy) {
      return;
    }

    _isRunningAction = true;
    _assistantLoadingMessage = 'Menjalankan aksi...';
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = await _apiClient.runKnowledgeConversationAction(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        conversationId: conversationId,
        messageId: message.id,
        actionKey: action.key,
      );
      await _sessionController.syncCookies(payload.cookies);

      final conversation = KnowledgeConversationSummary.fromJson(
        _asMap(payload.data['conversation']),
      );
      _replaceConversation(conversation);
      _activeConversationId = conversation.id;

      final updatedMessage = KnowledgeAssistantMessage.tryFromJson(
        _asMap(payload.data['updated_message']),
      );
      final userMessage = KnowledgeAssistantMessage.tryFromJson(
        _asMap(payload.data['user_message']),
      );
      final assistantMessage = KnowledgeAssistantMessage.tryFromJson(
        _asMap(payload.data['assistant_message']),
      );

      final nextMessages = _messages
          .map((item) {
            if (updatedMessage != null && item.id == updatedMessage.id) {
              return updatedMessage;
            }
            return item;
          })
          .toList(growable: true);
      if (userMessage != null) {
        nextMessages.add(userMessage);
      }
      if (assistantMessage != null) {
        nextMessages.add(assistantMessage);
      }

      _messages = List<KnowledgeAssistantMessage>.unmodifiable(nextMessages);
      _errorMessage = null;
    } on GesitApiException catch (error) {
      await _handleApiException(error);
    } on TimeoutException {
      _errorMessage =
          'Aksi belum mendapat jawaban dari server. Coba lagi sebentar.';
    } catch (_) {
      _errorMessage = 'Aksi percakapan belum bisa dijalankan.';
    } finally {
      _isRunningAction = false;
      _assistantLoadingMessage = null;
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(String documentId) async {
    final session = _sessionController.session;
    if (session == null || documentId.trim().isEmpty) {
      return;
    }

    final index = _documents.indexWhere(
      (document) => document.id == documentId,
    );
    if (index < 0) {
      return;
    }

    final originalDocument = _documents[index];
    final optimisticDocument = originalDocument.copyWith(
      isBookmarked: !originalDocument.isBookmarked,
    );
    _replaceDocumentAt(index, optimisticDocument);
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = await _apiClient.toggleKnowledgeBookmark(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        entryId: documentId,
      );
      await _sessionController.syncCookies(payload.cookies);

      final isBookmarked = payload.data['bookmarked'] == true;
      _replaceDocumentAt(
        index,
        originalDocument.copyWith(isBookmarked: isBookmarked),
      );
    } on GesitApiException catch (error) {
      _replaceDocumentAt(index, originalDocument);
      await _handleApiException(error);
    } on TimeoutException {
      _replaceDocumentAt(index, originalDocument);
      _errorMessage = 'Bookmark terlalu lama diperbarui.';
    } catch (_) {
      _replaceDocumentAt(index, originalDocument);
      _errorMessage = 'Bookmark belum bisa diperbarui.';
    } finally {
      notifyListeners();
    }
  }

  void _applyHubPayload(
    Map<String, dynamic> payload, {
    required String baseUrl,
  }) {
    _spaces = _asList(payload['spaces'])
        .map((space) => KnowledgeHubSpace.fromJson(_asMap(space)))
        .where((space) => space.id.isNotEmpty)
        .toList(growable: false);
    _documents = _asList(payload['entries'])
        .map((entry) => KnowledgeHubDocument.fromJson(_asMap(entry), baseUrl))
        .where((document) => document.id.isNotEmpty)
        .toList(growable: false);

    final suggestedQuestions = _asList(payload['suggested_questions'])
        .map(_normalizedString)
        .whereType<String>()
        .where((question) => question.isNotEmpty)
        .take(4)
        .toList(growable: false);
    _suggestedQuestions = suggestedQuestions.isEmpty
        ? fallbackSuggestedQuestions
        : suggestedQuestions;
  }

  void _applyConversationsPayload(Map<String, dynamic> payload) {
    final conversations = _asList(payload['conversations'])
        .map(
          (conversation) =>
              KnowledgeConversationSummary.fromJson(_asMap(conversation)),
        )
        .where((conversation) => conversation.id.isNotEmpty)
        .toList(growable: false);
    conversations.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );
    _conversations = conversations;

    final activeId = _activeConversationId;
    if (activeId != null &&
        !_conversations.any((conversation) => conversation.id == activeId)) {
      _activeConversationId = null;
      _messages = const <KnowledgeAssistantMessage>[];
    }
  }

  void _replaceConversation(KnowledgeConversationSummary conversation) {
    if (conversation.id.isEmpty) {
      return;
    }

    final conversations = List<KnowledgeConversationSummary>.from(
      _conversations,
    );
    final index = conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index >= 0) {
      conversations[index] = conversation;
    } else {
      conversations.insert(0, conversation);
    }
    conversations.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );
    _conversations = List<KnowledgeConversationSummary>.unmodifiable(
      conversations,
    );
  }

  void _replaceDocumentAt(int index, KnowledgeHubDocument document) {
    final documents = List<KnowledgeHubDocument>.from(_documents);
    documents[index] = document;
    _documents = List<KnowledgeHubDocument>.unmodifiable(documents);
  }

  Future<void> _handleApiException(GesitApiException error) async {
    if (error.statusCode == 401) {
      _spaces = const <KnowledgeHubSpace>[];
      _documents = const <KnowledgeHubDocument>[];
      _conversations = const <KnowledgeConversationSummary>[];
      _messages = const <KnowledgeAssistantMessage>[];
      _activeConversationId = null;
      _errorMessage = 'Sesi login berakhir. Silakan masuk lagi.';
      await _sessionController.invalidateSession(errorMessage: _errorMessage);
      return;
    }

    _errorMessage = error.message;
  }
}

class KnowledgeHubSpace {
  const KnowledgeHubSpace({
    required this.id,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.kind,
    required this.entryCount,
    required this.folders,
  });

  final String id;
  final String name;
  final String description;
  final String iconKey;
  final String kind;
  final int entryCount;
  final List<KnowledgeHubFolder> folders;

  factory KnowledgeHubSpace.fromJson(Map<String, dynamic> json) {
    final id = _normalizedString(json['id']) ?? '';
    return KnowledgeHubSpace(
      id: id,
      name: _normalizedString(json['name']) ?? 'Knowledge Space',
      description: _normalizedString(json['description']) ?? '',
      iconKey: _normalizedString(json['icon']) ?? 'folder',
      kind: _normalizedString(json['kind']) ?? '',
      entryCount: _intValue(json['entry_count']),
      folders: _asList(json['sections'])
          .map((section) => KnowledgeHubFolder.fromJson(_asMap(section), id))
          .where((folder) => folder.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class KnowledgeHubFolder {
  const KnowledgeHubFolder({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.description,
    required this.entryCount,
  });

  final String id;
  final String spaceId;
  final String name;
  final String description;
  final int entryCount;

  factory KnowledgeHubFolder.fromJson(
    Map<String, dynamic> json,
    String fallbackSpaceId,
  ) {
    return KnowledgeHubFolder(
      id: _normalizedString(json['id']) ?? '',
      spaceId: _normalizedString(json['knowledge_space_id']) ?? fallbackSpaceId,
      name: _normalizedString(json['name']) ?? 'Folder',
      description: _normalizedString(json['description']) ?? '',
      entryCount: _intValue(json['entry_count']),
    );
  }
}

class KnowledgeHubDocument {
  const KnowledgeHubDocument({
    required this.id,
    required this.spaceId,
    required this.folderId,
    required this.title,
    required this.summary,
    required this.body,
    required this.type,
    required this.typeLabel,
    required this.sourceKindLabel,
    required this.pathLabel,
    required this.ownerLabel,
    required this.updatedAt,
    required this.isBookmarked,
    this.spaceName,
    this.folderName,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
    this.sourceLink,
    this.effectiveDateLabel,
    this.versionLabel,
  });

  final String id;
  final String spaceId;
  final String folderId;
  final String title;
  final String summary;
  final String body;
  final String type;
  final String typeLabel;
  final String sourceKindLabel;
  final String pathLabel;
  final String ownerLabel;
  final DateTime updatedAt;
  final bool isBookmarked;
  final String? spaceName;
  final String? folderName;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final String? sourceLink;
  final String? effectiveDateLabel;
  final String? versionLabel;

  factory KnowledgeHubDocument.fromJson(
    Map<String, dynamic> json,
    String baseUrl,
  ) {
    return KnowledgeHubDocument(
      id: _normalizedString(json['id']) ?? '',
      spaceId: _normalizedString(json['space_id']) ?? '',
      folderId: _normalizedString(json['section_id']) ?? '',
      title: _normalizedString(json['title']) ?? 'Dokumen Knowledge',
      summary: _normalizedString(json['summary']) ?? '',
      body: _normalizedString(json['body']) ?? '',
      type: _normalizedString(json['type']) ?? '',
      typeLabel: _normalizedString(json['type_label']) ?? 'Dokumen',
      sourceKindLabel:
          _normalizedString(json['source_kind_label']) ?? 'Knowledge',
      pathLabel: _normalizedString(json['path_label']) ?? '',
      ownerLabel: _normalizedString(json['owner_name']) ?? '-',
      updatedAt: _dateValue(json['updated_at']),
      isBookmarked: json['is_bookmarked'] == true,
      spaceName: _normalizedString(json['space_name']),
      folderName: _normalizedString(json['section_name']),
      attachmentUrl: _absoluteUrl(baseUrl, json['attachment_url']),
      attachmentName: _normalizedString(json['attachment_name']),
      attachmentMime: _normalizedString(json['attachment_mime']),
      sourceLink: _absoluteUrl(baseUrl, json['source_link']),
      effectiveDateLabel: _normalizedString(json['effective_date_label']),
      versionLabel: _normalizedString(json['version_label']),
    );
  }

  KnowledgeHubDocument copyWith({bool? isBookmarked}) {
    return KnowledgeHubDocument(
      id: id,
      spaceId: spaceId,
      folderId: folderId,
      title: title,
      summary: summary,
      body: body,
      type: type,
      typeLabel: typeLabel,
      sourceKindLabel: sourceKindLabel,
      pathLabel: pathLabel,
      ownerLabel: ownerLabel,
      updatedAt: updatedAt,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      spaceName: spaceName,
      folderName: folderName,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentMime: attachmentMime,
      sourceLink: sourceLink,
      effectiveDateLabel: effectiveDateLabel,
      versionLabel: versionLabel,
    );
  }
}

class KnowledgeConversationSummary {
  const KnowledgeConversationSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
    required this.messageCount,
  });

  final String id;
  final String title;
  final String preview;
  final DateTime updatedAt;
  final int messageCount;

  factory KnowledgeConversationSummary.fromJson(Map<String, dynamic> json) {
    final updatedAt = _dateValue(json['last_message_at'] ?? json['updated_at']);
    return KnowledgeConversationSummary(
      id: _normalizedString(json['id']) ?? '',
      title: _normalizedString(json['title']) ?? 'Obrolan Knowledge',
      preview: _normalizedString(json['preview']) ?? '',
      updatedAt: updatedAt,
      messageCount: _intValue(json['message_count']),
    );
  }
}

class KnowledgeAssistantMessage {
  const KnowledgeAssistantMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.sourceClosing,
    this.sources = const <KnowledgeAssistantSource>[],
    this.actions = const <KnowledgeConversationAction>[],
  });

  const KnowledgeAssistantMessage.localAssistant(
    String text, {
    List<KnowledgeAssistantSource> sources = const <KnowledgeAssistantSource>[],
    List<KnowledgeConversationAction> actions =
        const <KnowledgeConversationAction>[],
  }) : this(
         id: 'local-assistant',
         text: text,
         isUser: false,
         sources: sources,
         actions: actions,
       );

  factory KnowledgeAssistantMessage.localUser(String text) {
    return KnowledgeAssistantMessage(
      id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isUser: true,
    );
  }

  final String id;
  final String text;
  final bool isUser;
  final String? sourceClosing;
  final List<KnowledgeAssistantSource> sources;
  final List<KnowledgeConversationAction> actions;

  static KnowledgeAssistantMessage? tryFromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return null;
    }
    return KnowledgeAssistantMessage.fromJson(json);
  }

  factory KnowledgeAssistantMessage.fromJson(Map<String, dynamic> json) {
    final sources = _asList(json['sources'])
        .map((source) => KnowledgeAssistantSource.fromJson(_asMap(source)))
        .where((source) => source.title.isNotEmpty)
        .toList(growable: false);
    final actions = _asList(json['actions'])
        .map((action) => KnowledgeConversationAction.fromJson(_asMap(action)))
        .where((action) => action.key.isNotEmpty && action.label.isNotEmpty)
        .toList(growable: false);
    final rawContent = _normalizedString(json['content']) ?? '';
    final sourceIntro = _normalizedString(json['source_intro']);
    final sourceClosing = _normalizedString(json['source_closing']);
    final isUser = (_normalizedString(json['role']) ?? '') == 'user';
    final cleanContent = rawContent.replaceAll('[[DOCUMENT_CARDS]]', '').trim();

    return KnowledgeAssistantMessage(
      id: _normalizedString(json['id']) ?? '',
      text: sources.isNotEmpty ? (sourceIntro ?? cleanContent) : cleanContent,
      isUser: isUser,
      sourceClosing: sources.isEmpty ? null : sourceClosing,
      sources: sources,
      actions: actions,
    );
  }
}

class KnowledgeConversationAction {
  const KnowledgeConversationAction({
    required this.key,
    required this.label,
    required this.variant,
  });

  final String key;
  final String label;
  final String variant;

  bool get isPrimary => variant != 'secondary';

  factory KnowledgeConversationAction.fromJson(Map<String, dynamic> json) {
    return KnowledgeConversationAction(
      key: _normalizedString(json['key']) ?? '',
      label: _normalizedString(json['label']) ?? '',
      variant: _normalizedString(json['variant']) ?? 'primary',
    );
  }
}

class KnowledgeAssistantSource {
  const KnowledgeAssistantSource({
    required this.title,
    required this.subtitle,
    this.documentId,
  });

  final String title;
  final String subtitle;
  final String? documentId;

  factory KnowledgeAssistantSource.fromJson(Map<String, dynamic> json) {
    final pathLabel = _normalizedString(json['path_label']);
    final typeLabel = _normalizedString(json['type_label']);
    final subtitleParts = <String>[
      if (pathLabel != null) pathLabel,
      if (typeLabel != null) typeLabel,
    ];

    return KnowledgeAssistantSource(
      title: _normalizedString(json['title']) ?? '',
      subtitle: subtitleParts.isEmpty
          ? 'Knowledge source'
          : subtitleParts.join(' · '),
      documentId:
          _normalizedString(json['id']) ??
          _normalizedString(json['entry_id']) ??
          _normalizedString(json['document_id']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }

  return <String, dynamic>{};
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return value;
  }

  return const <Object?>[];
}

String? _normalizedString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse('${value ?? ''}') ?? 0;
}

DateTime _dateValue(Object? value) {
  return DateTime.tryParse('${value ?? ''}') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _normalizeIntentText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+]+'), ' ').trim();
}

String? _absoluteUrl(String baseUrl, Object? value) {
  final normalized = _normalizedString(value);
  if (normalized == null) {
    return null;
  }

  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.hasScheme) {
    return normalized;
  }

  try {
    return Uri.parse(
      AppRuntimeConfig.normalizeBaseUrl(baseUrl),
    ).resolve(normalized).toString();
  } catch (_) {
    return normalized;
  }
}
