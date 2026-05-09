import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_session_controller.dart';
import '../data/gesit_api_client.dart';
import '../data/knowledge_workspace_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import 'knowledge_document_preview_screen.dart';

class KnowledgeWorkspaceScreen extends StatefulWidget {
  const KnowledgeWorkspaceScreen({
    super.key,
    required this.sessionController,
    this.openDocuments = false,
    this.initialShareToken,
  });

  final AppSessionController sessionController;
  final bool openDocuments;
  final String? initialShareToken;

  @override
  State<KnowledgeWorkspaceScreen> createState() =>
      _KnowledgeWorkspaceScreenState();
}

enum _KnowledgeWorkspaceView { assistant, documents }

enum _DocumentHubFilter { all, folders, files, bookmarked }

enum _FileActionMenuItem {
  preview,
  download,
  share,
  rename,
  move,
  details,
  favorite,
  delete,
}

class _KnowledgeWorkspaceScreenState extends State<KnowledgeWorkspaceScreen> {
  static const MethodChannel _shareChannel = MethodChannel('gesit/share');

  static const List<_AssistantPrompt> _prompts = [
    _AssistantPrompt(
      title: 'Ringkas SOP approval pengadaan',
      prompt: 'Ringkas SOP approval pengadaan',
      icon: Icons.fact_check_rounded,
    ),
    _AssistantPrompt(
      title: 'Bagaimana proses akses S21+ user baru?',
      prompt: 'Bagaimana proses akses S21+ user baru?',
      icon: Icons.lock_open_rounded,
    ),
    _AssistantPrompt(
      title: 'Dokumen apa yang dibutuhkan vendor onboarding?',
      prompt: 'Dokumen apa yang dibutuhkan vendor onboarding?',
      icon: Icons.folder_copy_rounded,
    ),
    _AssistantPrompt(
      title: 'Buat checklist helpdesk kritikal',
      prompt: 'Buat checklist helpdesk kritikal',
      icon: Icons.support_agent_rounded,
    ),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _documentSearchController =
      TextEditingController();

  late final KnowledgeWorkspaceController _controller;

  late _KnowledgeWorkspaceView _currentView;
  _DocumentHubFilter _documentFilter = _DocumentHubFilter.all;
  String? _selectedSpaceId;
  String? _selectedFolderId;
  bool _handledInitialShareToken = false;

  @override
  void initState() {
    super.initState();
    _currentView = widget.openDocuments
        ? _KnowledgeWorkspaceView.documents
        : _KnowledgeWorkspaceView.assistant;
    _controller = KnowledgeWorkspaceController(
      sessionController: widget.sessionController,
    )..addListener(_handleControllerChanged);
    _composerController.addListener(_refreshState);
    _documentSearchController.addListener(_refreshState);
    unawaited(_controller.ensureLoaded());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _composerController
      ..removeListener(_refreshState)
      ..dispose();
    _composerFocusNode.dispose();
    _chatScrollController.dispose();
    _documentSearchController
      ..removeListener(_refreshState)
      ..dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
    _openInitialShareIfNeeded();
    if (_currentView == _KnowledgeWorkspaceView.assistant &&
        (_messages.isNotEmpty || _isResponding)) {
      _scrollToBottom();
    }
  }

  void _refreshState() {
    if (mounted) {
      setState(() {});
    }
  }

  List<_AssistantPrompt> get _assistantPrompts {
    final suggestedQuestions = _controller.suggestedQuestions;
    if (suggestedQuestions.isEmpty ||
        identical(
          suggestedQuestions,
          KnowledgeWorkspaceController.fallbackSuggestedQuestions,
        )) {
      return _prompts;
    }

    return suggestedQuestions
        .map(
          (question) => _AssistantPrompt(
            title: question,
            prompt: question,
            icon: _promptIconFor(question),
          ),
        )
        .toList(growable: false);
  }

  List<_KnowledgeSpace> get _spaces =>
      _controller.spaces.map(_adaptSpace).toList(growable: false);

  List<_KnowledgeDocumentFile> get _documents =>
      _controller.documents.map(_adaptDocument).toList(growable: false);

  List<_KnowledgeConversation> get _conversationHistory =>
      _controller.conversations.map(_adaptConversation).toList(growable: false);

  bool get _isResponding => _controller.isAssistantBusy;

  String? get _activeConversationId => _controller.activeConversationId;

  List<_AssistantMessage> get _messages =>
      _controller.messages.map(_adaptAssistantMessage).toList(growable: false);

  List<_KnowledgeConversation> get _sortedConversations {
    final conversations = List<_KnowledgeConversation>.from(
      _conversationHistory,
    );
    conversations.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );
    return conversations;
  }

  _KnowledgeSpace? get _selectedSpace {
    final spaceId = _selectedSpaceId;
    if (spaceId == null) {
      return null;
    }

    for (final space in _spaces) {
      if (space.id == spaceId) {
        return space;
      }
    }

    return null;
  }

  _KnowledgeFolder? get _selectedFolder {
    final folderId = _selectedFolderId;
    final space = _selectedSpace;
    if (folderId == null || space == null) {
      return null;
    }

    for (final folder in space.folders) {
      if (folder.id == folderId) {
        return folder;
      }
    }

    return null;
  }

  String get _documentQuery =>
      _documentSearchController.text.trim().toLowerCase();

  List<_KnowledgeFolder> get _visibleFolders {
    if (_documentFilter == _DocumentHubFilter.files ||
        _documentFilter == _DocumentHubFilter.bookmarked ||
        _selectedFolderId != null ||
        _selectedSpaceId == null) {
      return const [];
    }

    final folders = _selectedSpace?.folders ?? const <_KnowledgeFolder>[];

    return folders.where((folder) {
      if (_documentQuery.isEmpty) {
        return true;
      }

      final space = _findSpaceById(folder.spaceId);
      final haystack = [
        folder.name,
        space?.name ?? '',
        ..._documentsForFolder(folder.id).map((file) => file.title),
      ].join(' ').toLowerCase();

      return haystack.contains(_documentQuery);
    }).toList();
  }

  List<_KnowledgeSpace> get _visibleSpaces {
    if (_selectedSpaceId != null ||
        _documentFilter == _DocumentHubFilter.files ||
        _documentFilter == _DocumentHubFilter.bookmarked) {
      return const [];
    }

    return _spaces.where((space) {
      if (_documentQuery.isEmpty) {
        return true;
      }

      final haystack = [
        space.name,
        space.description,
        ...space.folders.map((folder) => folder.name),
        ..._documents
            .where((file) => file.spaceId == space.id)
            .map((file) => file.title),
      ].join(' ').toLowerCase();

      return haystack.contains(_documentQuery);
    }).toList();
  }

  List<_KnowledgeDocumentFile> get _visibleFiles {
    final files = _documents.where((file) {
      final matchesQuery = _documentMatchesQuery(file);
      final matchesLocation = _matchesSelectedDirectory(file);
      final matchesFilter = switch (_documentFilter) {
        _DocumentHubFilter.all => true,
        _DocumentHubFilter.folders => false,
        _DocumentHubFilter.files => true,
        _DocumentHubFilter.bookmarked => file.isBookmarked,
      };

      return matchesQuery && matchesLocation && matchesFilter;
    }).toList();

    files.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return files;
  }

  List<_KnowledgeDocumentFile> get _recentFiles {
    final files = _documents.where((file) {
      final matchesQuery =
          _documentQuery.isEmpty || _documentMatchesQuery(file);
      final matchesFilter = switch (_documentFilter) {
        _DocumentHubFilter.all => true,
        _DocumentHubFilter.folders => false,
        _DocumentHubFilter.files => true,
        _DocumentHubFilter.bookmarked => file.isBookmarked,
      };

      return matchesQuery && matchesFilter;
    }).toList();

    files.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return files.take(6).toList();
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _switchWorkspace(_KnowledgeWorkspaceView view) {
    setState(() {
      _currentView = view;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _returnToMainMenu() {
    final isDrawerOpen = _scaffoldKey.currentState?.isDrawerOpen ?? false;
    if (isDrawerOpen) {
      Navigator.of(context).pop();
    }

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    });
  }

  void _startNewChat() {
    setState(() {
      _composerController.clear();
      _currentView = _KnowledgeWorkspaceView.assistant;
    });
    _controller.startNewConversation();
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _openConversation(String conversationId) {
    setState(() {
      _currentView = _KnowledgeWorkspaceView.assistant;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    unawaited(_controller.openConversation(conversationId));
    _scrollToBottom();
  }

  void _sendMessage([String? seededPrompt]) {
    final value = (seededPrompt ?? _composerController.text).trim();
    if (value.isEmpty || _isResponding) {
      return;
    }

    setState(() {
      _composerController.clear();
    });

    unawaited(_controller.ask(value));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients ||
          _chatScrollController.positions.isEmpty) {
        return;
      }

      final targetPosition = _chatScrollController.positions.last;
      _chatScrollController.animateTo(
        targetPosition.maxScrollExtent + 180,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleComposerAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label siap disambungkan ke workflow berikutnya.'),
      ),
    );
  }

  void _jumpToSource(_AssistantSource source) {
    final documentId = source.documentId;
    if (documentId == null) {
      return;
    }

    final file = _findDocumentById(documentId);
    if (file == null) {
      return;
    }

    setState(() {
      _currentView = _KnowledgeWorkspaceView.documents;
      _selectedSpaceId = file.spaceId;
      _selectedFolderId = _findFolderById(file.folderId)?.id;
      _documentFilter = _DocumentHubFilter.all;
    });
    _showFileProperties(file);
  }

  void _goToDocumentRoot() {
    setState(() {
      _selectedSpaceId = null;
      _selectedFolderId = null;
    });
  }

  void _selectSpace(String spaceId) {
    setState(() {
      _selectedSpaceId = spaceId;
      _selectedFolderId = null;
    });
  }

  void _selectFolder(String folderId) {
    final folder = _findFolderById(folderId);
    if (folder == null) {
      return;
    }

    setState(() {
      _selectedSpaceId = folder.spaceId;
      _selectedFolderId = folder.id;
    });
  }

  void _toggleBookmark(String fileId) {
    unawaited(_controller.toggleBookmark(fileId));
  }

  void _runMessageAction(_AssistantMessage message, _AssistantAction action) {
    final sourceMessage = message.sourceMessage;
    if (sourceMessage == null) {
      return;
    }

    unawaited(
      _controller.runMessageAction(
        message: sourceMessage,
        action: action.sourceAction,
      ),
    );
  }

  Future<void> _handleFileTap(_KnowledgeDocumentFile file) async {
    final document = _findSourceDocumentById(file.id);
    if (document == null) {
      await _showFileProperties(file);
      return;
    }

    _openDocumentPreview(document);
  }

  void _openDocumentPreview(KnowledgeHubDocument document) {
    pushBrandedRoute(
      context,
      KnowledgeDocumentPreviewScreen(
        document: document,
        controller: _controller,
      ),
    );
  }

  KnowledgeHubDocument? _findSourceDocumentById(String fileId) {
    for (final document in _controller.documents) {
      if (document.id == fileId) {
        return document;
      }
    }
    return null;
  }

  Future<void> _openInitialShareIfNeeded() async {
    final token = widget.initialShareToken?.trim();
    if (_handledInitialShareToken ||
        token == null ||
        token.isEmpty ||
        !_controller.loaded) {
      return;
    }

    _handledInitialShareToken = true;

    try {
      final document = await _controller.resolveShareToken(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _currentView = _KnowledgeWorkspaceView.documents;
        _selectedSpaceId = document.spaceId;
        _selectedFolderId = document.folderId;
      });
      _openDocumentPreview(document);
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _shareFile(_KnowledgeDocumentFile file) async {
    try {
      final share = await _controller.createShareLink(file.id);
      if (!mounted) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: share.shareUrl));
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _ShareLinkSheet(
          title: file.title,
          shareUrl: share.shareUrl,
          onNativeShare: () => _shareNative(file.title, share.shareUrl),
        ),
      );
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _shareNative(String title, String shareUrl) async {
    try {
      await _shareChannel.invokeMethod<void>('shareText', {
        'subject': title,
        'text': shareUrl,
      });
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link sudah disalin.')));
    }
  }

  Future<void> _downloadFile(_KnowledgeDocumentFile file) async {
    try {
      final document = _findSourceDocumentById(file.id);
      final safeName = _safeDocumentFileName(
        document?.attachmentName ?? file.title,
      );
      final bytes = document?.attachmentUrl == null && document != null
          ? utf8.encode(document.body)
          : (await _controller.downloadDocument(file.id)).bytes;
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDirectory = Directory('${directory.path}/gesit_downloads');
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }
      final target = File('${downloadsDirectory.path}/$safeName');
      await target.writeAsBytes(bytes, flush: true);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File tersimpan: ${target.path}')));
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download dokumen belum berhasil.')),
      );
    }
  }

  Future<void> _renameFile(_KnowledgeDocumentFile file) async {
    final controller = TextEditingController(text: file.title);
    final nextTitle = await _showSingleInputSheet(
      title: 'Rename dokumen',
      label: 'Nama dokumen',
      controller: controller,
      submitLabel: 'Simpan',
    );
    controller.dispose();
    if (nextTitle == null || nextTitle.trim().isEmpty) {
      return;
    }

    try {
      await _controller.updateDocument(
        documentId: file.id,
        title: nextTitle.trim(),
      );
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _moveFile(_KnowledgeDocumentFile file) async {
    final targets = _moveTargets;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Belum ada folder tujuan.')));
      return;
    }

    final target = await showModalBottomSheet<_MoveTarget>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MoveDocumentSheet(targets: targets),
    );
    if (target == null || target.sectionId == file.folderId) {
      return;
    }

    try {
      await _controller.updateDocument(
        documentId: file.id,
        sectionId: target.sectionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedSpaceId = target.spaceId;
        _selectedFolderId = target.isRoot ? null : target.sectionId;
      });
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteFile(_KnowledgeDocumentFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus dokumen?'),
        content: Text('Dokumen "${file.title}" akan dihapus dari hub.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _controller.deleteDocument(file.id);
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showCreateFolderSheet() async {
    final space = _selectedSpace;
    if (space == null) {
      _showDocumentHubSnack('Pilih divisi atau folder tujuan dulu.');
      return;
    }
    if (_selectedFolderId != null) {
      _showDocumentHubSnack('Folder baru dibuat dari level divisi.');
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showModalBottomSheet<_FolderDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateFolderSheet(
        nameController: nameController,
        descriptionController: descriptionController,
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (result == null) {
      return;
    }

    try {
      final folder = await _controller.createFolder(
        spaceId: space.id,
        name: result.name,
        description: result.description,
      );
      if (!mounted || folder == null) {
        return;
      }
      setState(() {
        _selectedSpaceId = folder.spaceId;
        _selectedFolderId = folder.id;
      });
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showUploadDocumentSheet() async {
    final space = _selectedSpace;
    if (space == null) {
      _showDocumentHubSnack('Pilih divisi atau folder tujuan dulu.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(withData: false);
    final pickedFile = picked?.files.single;
    if (pickedFile == null || !mounted) {
      return;
    }

    final titleController = TextEditingController(
      text: _titleFromPickedFile(pickedFile.name),
    );
    final summaryController = TextEditingController();
    final draft = await showModalBottomSheet<_UploadDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UploadDocumentSheet(
        fileName: pickedFile.name,
        titleController: titleController,
        summaryController: summaryController,
      ),
    );
    titleController.dispose();
    summaryController.dispose();
    if (draft == null) {
      return;
    }

    try {
      await _controller.uploadDocument(
        spaceId: space.id,
        sectionId: _selectedFolderId ?? space.defaultSectionId,
        title: draft.title,
        summary: draft.summary,
        type: 'form',
        attachment: ApiMultipartFilePayload(
          fileName: pickedFile.name,
          path: pickedFile.path,
          contentType: lookupMimeType(pickedFile.name),
        ),
      );
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showCreateDocumentSheet() async {
    final space = _selectedSpace;
    if (space == null) {
      _showDocumentHubSnack('Pilih divisi atau folder tujuan dulu.');
      return;
    }

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final draft = await showModalBottomSheet<_DocumentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateDocumentSheet(
        titleController: titleController,
        bodyController: bodyController,
      ),
    );
    titleController.dispose();
    bodyController.dispose();
    if (draft == null) {
      return;
    }

    try {
      await _controller.uploadDocument(
        spaceId: space.id,
        sectionId: _selectedFolderId ?? space.defaultSectionId,
        title: draft.title,
        body: draft.body,
        type: 'form',
      );
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<String?> _showSingleInputSheet({
    required String title,
    required String label,
    required TextEditingController controller,
    required String submitLabel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SingleInputSheet(
        title: title,
        label: label,
        controller: controller,
        submitLabel: submitLabel,
      ),
    );
  }

  List<_MoveTarget> get _moveTargets {
    final targets = <_MoveTarget>[];
    for (final space in _spaces) {
      final defaultSectionId = space.defaultSectionId;
      if (defaultSectionId != null && defaultSectionId.isNotEmpty) {
        targets.add(
          _MoveTarget(
            sectionId: defaultSectionId,
            spaceId: space.id,
            label: '${space.name} / Root',
            isRoot: true,
          ),
        );
      }
      for (final folder in space.folders) {
        targets.add(
          _MoveTarget(
            sectionId: folder.id,
            spaceId: space.id,
            label: '${space.name} / ${folder.name}',
            isRoot: false,
          ),
        );
      }
    }
    return targets;
  }

  void _showDocumentHubSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCreateMenuSheet() async {
    final action = await showModalBottomSheet<_CreateMenuAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateMenuSheet(),
    );

    switch (action) {
      case _CreateMenuAction.folder:
        await _showCreateFolderSheet();
      case _CreateMenuAction.document:
        await _showCreateDocumentSheet();
      case null:
        return;
    }
  }

  Future<void> _showUploadMenuSheet() async {
    final action = await showModalBottomSheet<_UploadMenuAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _UploadMenuSheet(),
    );

    switch (action) {
      case _UploadMenuAction.document:
      case _UploadMenuAction.file:
        await _showUploadDocumentSheet();
      case null:
        return;
    }
  }

  Future<void> _showFileProperties(_KnowledgeDocumentFile file) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        file.title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailInfoRow(label: 'Type', value: file.typeLabel),
                _DetailInfoRow(label: 'Format', value: file.sizeLabel),
                _DetailInfoRow(
                  label: 'Terakhir diakses',
                  value: file.lastAccessedLabel,
                ),
                if (file.attachmentName != null)
                  _DetailInfoRow(
                    label: 'Lampiran',
                    value: file.attachmentName!,
                  ),
                _DetailInfoRow(
                  label: 'Favorit',
                  value: file.isBookmarked ? 'Ya' : 'Tidak',
                ),
                const SizedBox(height: 8),
                Text(
                  'Overview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  file.previewText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _documentMatchesQuery(_KnowledgeDocumentFile file) {
    if (_documentQuery.isEmpty) {
      return true;
    }

    final space = _findSpaceById(file.spaceId);
    final folder = _findFolderById(file.folderId);
    final haystack = [
      file.title,
      file.summary,
      file.typeLabel,
      file.ownerLabel,
      space?.name ?? '',
      folder?.name ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(_documentQuery);
  }

  bool _matchesSelectedDirectory(_KnowledgeDocumentFile file) {
    if (_selectedFolderId != null) {
      return file.folderId == _selectedFolderId;
    }
    if (_selectedSpaceId != null) {
      return file.spaceId == _selectedSpaceId;
    }
    return true;
  }

  List<_KnowledgeDocumentFile> _documentsForFolder(String folderId) {
    return _documents.where((file) => file.folderId == folderId).toList();
  }

  _KnowledgeDocumentFile? _findDocumentById(String fileId) {
    for (final file in _documents) {
      if (file.id == fileId) {
        return file;
      }
    }
    return null;
  }

  _KnowledgeSpace? _findSpaceById(String spaceId) {
    for (final space in _spaces) {
      if (space.id == spaceId) {
        return space;
      }
    }
    return null;
  }

  _KnowledgeFolder? _findFolderById(String folderId) {
    for (final space in _spaces) {
      for (final folder in space.folders) {
        if (folder.id == folderId) {
          return folder;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawerScrimColor: const Color(0x66111418),
      drawer: _WorkspaceDrawer(
        currentView: _currentView,
        conversations: _sortedConversations,
        activeConversationId: _activeConversationId,
        onOpenAssistant: () =>
            _switchWorkspace(_KnowledgeWorkspaceView.assistant),
        onOpenDocuments: () =>
            _switchWorkspace(_KnowledgeWorkspaceView.documents),
        onStartNewChat: _startNewChat,
        onOpenConversation: _openConversation,
      ),
      body: GesitBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _currentView == _KnowledgeWorkspaceView.assistant
                ? _buildAssistantView()
                : _buildDocumentsView(),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantView() {
    final canSend =
        _composerController.text.trim().isNotEmpty && !_isResponding;

    return Column(
      key: const ValueKey('assistant-workspace'),
      children: [
        _WorkspaceTopBar(
          title: 'AI Assistant',
          subtitle: 'Knowledge internal GESIT',
          onMenuTap: _openDrawer,
          onReturnTap: _returnToMainMenu,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _messages.isEmpty
                ? _controller.isLoading && !_controller.loaded
                      ? const _AssistantLoadingState(
                          key: ValueKey('assistant-loading'),
                        )
                      : _AssistantEmptyState(
                          key: const ValueKey('assistant-empty'),
                          prompts: _assistantPrompts,
                          onPromptTap: _sendMessage,
                        )
                : ListView.separated(
                    key: ValueKey(
                      'assistant-${_activeConversationId ?? 'draft'}',
                    ),
                    controller: _chatScrollController,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _AssistantTypingCard(
                          label: _controller.assistantLoadingMessage,
                        );
                      }

                      return _AssistantThreadItem(
                        message: _messages[index],
                        onSourceTap: _jumpToSource,
                        actionsEnabled: !_isResponding,
                        onActionTap: _runMessageAction,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemCount: _messages.length + (_isResponding ? 1 : 0),
                  ),
          ),
        ),
        if (_controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _KnowledgeInlineError(
              message: _controller.errorMessage!,
              actionLabel: _controller.canRetryLastQuestion
                  ? 'Coba lagi'
                  : 'Muat ulang',
              onRetry: _controller.canRetryLastQuestion
                  ? () => unawaited(_controller.retryLastQuestion())
                  : () => unawaited(_controller.refresh()),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AssistantComposerIconButton(
                icon: Icons.add_rounded,
                onTap: () => _handleComposerAction('Attachment'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AssistantComposerField(
                  controller: _composerController,
                  focusNode: _composerFocusNode,
                ),
              ),
              const SizedBox(width: 10),
              _AssistantComposerSendButton(
                enabled: canSend,
                onTap: canSend
                    ? _sendMessage
                    : () => _handleComposerAction('Voice input'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsView() {
    return Column(
      key: const ValueKey('documents-workspace'),
      children: [
        _WorkspaceTopBar(
          title: 'Smart Document Hub',
          onMenuTap: _openDrawer,
          onReturnTap: _returnToMainMenu,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _documentSearchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari folder, file, atau divisi',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _documentSearchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _documentSearchController.clear(),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _DocumentFilterPill(
                label: 'Semua',
                selected: _documentFilter == _DocumentHubFilter.all,
                onTap: () =>
                    setState(() => _documentFilter = _DocumentHubFilter.all),
              ),
              const SizedBox(width: 10),
              _DocumentFilterPill(
                label: 'Folder',
                selected: _documentFilter == _DocumentHubFilter.folders,
                onTap: () => setState(
                  () => _documentFilter = _DocumentHubFilter.folders,
                ),
              ),
              const SizedBox(width: 10),
              _DocumentFilterPill(
                label: 'File',
                selected: _documentFilter == _DocumentHubFilter.files,
                onTap: () =>
                    setState(() => _documentFilter = _DocumentHubFilter.files),
              ),
              const SizedBox(width: 10),
              _DocumentFilterPill(
                label: 'Bookmark',
                selected: _documentFilter == _DocumentHubFilter.bookmarked,
                onTap: () => setState(
                  () => _documentFilter = _DocumentHubFilter.bookmarked,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showCreateMenuSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Buat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _showUploadMenuSheet,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Upload'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _controller.isLoading && !_controller.loaded
              ? const _DocumentLoadingState()
              : ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if (_controller.errorMessage != null) ...[
                      _KnowledgeInlineError(
                        message: _controller.errorMessage!,
                        onRetry: () => unawaited(_controller.refresh()),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _DocumentBreadcrumbs(
                      space: _selectedSpace,
                      folder: _selectedFolder,
                      onRootTap: _goToDocumentRoot,
                      onSpaceTap: _selectedSpace == null
                          ? null
                          : () => _selectSpace(_selectedSpace!.id),
                    ),
                    const SizedBox(height: 18),
                    if (_visibleSpaces.isNotEmpty) ...[
                      const _DriveSectionLabel(title: 'Divisi'),
                      const SizedBox(height: 12),
                      _DriveSpaceGrid(
                        spaces: _visibleSpaces,
                        onTap: _selectSpace,
                      ),
                    ],
                    if (_visibleFolders.isNotEmpty) ...[
                      if (_visibleSpaces.isNotEmpty) const SizedBox(height: 22),
                      _DriveSectionLabel(
                        title: _selectedSpace == null ? 'Folders' : 'Folders',
                      ),
                      const SizedBox(height: 12),
                      _DriveFolderGrid(
                        folders: _visibleFolders,
                        onTap: _selectFolder,
                      ),
                    ],
                    if (_recentFiles.isNotEmpty &&
                        _selectedSpaceId == null) ...[
                      const SizedBox(height: 22),
                      const _DriveSectionLabel(title: 'Recent'),
                      const SizedBox(height: 12),
                      ..._recentFiles.map((file) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DriveFileTile(
                            file: file,
                            onTap: () => unawaited(_handleFileTap(file)),
                            onPreview: () => unawaited(_handleFileTap(file)),
                            onDownload: () => unawaited(_downloadFile(file)),
                            onShare: () => unawaited(_shareFile(file)),
                            onRename: () => unawaited(_renameFile(file)),
                            onMove: () => unawaited(_moveFile(file)),
                            onShowProperties: () => _showFileProperties(file),
                            onToggleBookmark: () => _toggleBookmark(file.id),
                            onDelete: () => unawaited(_deleteFile(file)),
                          ),
                        );
                      }),
                    ],
                    if (_visibleFiles.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _DriveSectionLabel(
                        title: _selectedSpaceId == null ? 'All Files' : 'Files',
                      ),
                      const SizedBox(height: 12),
                      ..._visibleFiles.map((file) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DriveFileTile(
                            file: file,
                            onTap: () => unawaited(_handleFileTap(file)),
                            onPreview: () => unawaited(_handleFileTap(file)),
                            onDownload: () => unawaited(_downloadFile(file)),
                            onShare: () => unawaited(_shareFile(file)),
                            onRename: () => unawaited(_renameFile(file)),
                            onMove: () => unawaited(_moveFile(file)),
                            onShowProperties: () => _showFileProperties(file),
                            onToggleBookmark: () => _toggleBookmark(file.id),
                            onDelete: () => unawaited(_deleteFile(file)),
                          ),
                        );
                      }),
                    ],
                    if (_visibleSpaces.isEmpty &&
                        _visibleFolders.isEmpty &&
                        _recentFiles.isEmpty &&
                        _visibleFiles.isEmpty)
                      _DocumentEmptyState(
                        title: 'Tidak ada hasil yang cocok',
                        subtitle:
                            'Ubah kata kunci pencarian atau pindah ke folder lain untuk melihat file yang tersedia.',
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.title,
    required this.onMenuTap,
    required this.onReturnTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onMenuTap;
  final VoidCallback onReturnTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onMenuTap,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleLarge),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onReturnTap,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Menu Utama'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDrawer extends StatelessWidget {
  const _WorkspaceDrawer({
    required this.currentView,
    required this.conversations,
    required this.activeConversationId,
    required this.onOpenAssistant,
    required this.onOpenDocuments,
    required this.onStartNewChat,
    required this.onOpenConversation,
  });

  final _KnowledgeWorkspaceView currentView;
  final List<_KnowledgeConversation> conversations;
  final String? activeConversationId;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenDocuments;
  final VoidCallback onStartNewChat;
  final ValueChanged<String> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAssistantView = currentView == _KnowledgeWorkspaceView.assistant;

    return Drawer(
      width: 332,
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: BrandSurface(
            padding: EdgeInsets.zero,
            radius: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                  child: Column(
                    children: [
                      _WorkspaceNavTile(
                        icon: Icons.auto_awesome_rounded,
                        label: 'AI Assistant',
                        selected: isAssistantView,
                        onTap: onOpenAssistant,
                      ),
                      const SizedBox(height: 10),
                      _WorkspaceNavTile(
                        icon: Icons.folder_copy_rounded,
                        label: 'Smart Document Hub',
                        selected: !isAssistantView,
                        onTap: onOpenDocuments,
                      ),
                    ],
                  ),
                ),
                if (isAssistantView) ...[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: FilledButton.icon(
                      onPressed: onStartNewChat,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New Chat'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'History Chat',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: conversations.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Text(
                              'Belum ada riwayat chat. Mulai obrolan baru dari drawer ini.',
                              style: textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                            physics: const ClampingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final conversation = conversations[index];
                              return _WorkspaceConversationTile(
                                conversation: conversation,
                                selected:
                                    activeConversationId == conversation.id,
                                onTap: () =>
                                    onOpenConversation(conversation.id),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemCount: conversations.length,
                          ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceNavTile extends StatelessWidget {
  const _WorkspaceNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.goldSoft.withValues(alpha: 0.54)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.goldDeep : AppColors.inkSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceConversationTile extends StatelessWidget {
  const _WorkspaceConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final _KnowledgeConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceAlt : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.circle : Icons.chevron_right_rounded,
                size: selected ? 8 : 18,
                color: selected ? AppColors.goldDeep : AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentBreadcrumbs extends StatelessWidget {
  const _DocumentBreadcrumbs({
    required this.space,
    required this.folder,
    required this.onRootTap,
    this.onSpaceTap,
  });

  final _KnowledgeSpace? space;
  final _KnowledgeFolder? folder;
  final VoidCallback onRootTap;
  final VoidCallback? onSpaceTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _BreadcrumbChip(
          label: 'All Files',
          onTap: onRootTap,
          selected: space == null,
        ),
        if (space != null)
          _BreadcrumbChip(
            label: space!.name,
            onTap: onSpaceTap,
            selected: folder == null,
          ),
        if (folder != null)
          _BreadcrumbChip(label: folder!.name, selected: true),
      ],
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.goldSoft.withValues(alpha: 0.64)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: selected ? AppColors.goldDeep : AppColors.inkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentFilterPill extends StatelessWidget {
  const _DocumentFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.goldSoft.withValues(alpha: 0.72)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? AppColors.goldDeep : AppColors.inkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DriveSectionLabel extends StatelessWidget {
  const _DriveSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _DriveFolderGrid extends StatelessWidget {
  const _DriveFolderGrid({required this.folders, required this.onTap});

  final List<_KnowledgeFolder> folders;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 640
            ? 4
            : width >= 360
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: folders.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final folder = folders[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(folder.id),
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          color: AppColors.goldDeep,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        folder.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DriveSpaceGrid extends StatelessWidget {
  const _DriveSpaceGrid({required this.spaces, required this.onTap});

  final List<_KnowledgeSpace> spaces;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 640
            ? 4
            : width >= 360
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: spaces.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.04,
          ),
          itemBuilder: (context, index) {
            final space = spaces[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(space.id),
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: space.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(space.icon, color: space.accentColor),
                      ),
                      const Spacer(),
                      Text(
                        space.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (space.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          space.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DriveFileTile extends StatelessWidget {
  const _DriveFileTile({
    required this.file,
    required this.onTap,
    required this.onPreview,
    required this.onDownload,
    required this.onShare,
    required this.onRename,
    required this.onMove,
    required this.onShowProperties,
    required this.onToggleBookmark,
    required this.onDelete,
  });

  final _KnowledgeDocumentFile file;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onShowProperties;
  final VoidCallback onToggleBookmark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: file.typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(file.icon, color: file.typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          PopupMenuButton<_FileActionMenuItem>(
            tooltip: 'File actions',
            color: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (value) {
              switch (value) {
                case _FileActionMenuItem.preview:
                  onPreview();
                case _FileActionMenuItem.download:
                  onDownload();
                case _FileActionMenuItem.share:
                  onShare();
                case _FileActionMenuItem.rename:
                  onRename();
                case _FileActionMenuItem.move:
                  onMove();
                case _FileActionMenuItem.details:
                  onShowProperties();
                case _FileActionMenuItem.favorite:
                  onToggleBookmark();
                case _FileActionMenuItem.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.preview,
                child: _DriveMenuItem(
                  icon: Icons.visibility_rounded,
                  label: 'Preview',
                ),
              ),
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.download,
                child: _DriveMenuItem(
                  icon: Icons.download_rounded,
                  label: 'Download',
                ),
              ),
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.share,
                child: _DriveMenuItem(
                  icon: Icons.ios_share_rounded,
                  label: 'Share link',
                ),
              ),
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.rename,
                child: _DriveMenuItem(
                  icon: Icons.drive_file_rename_outline_rounded,
                  label: 'Rename',
                ),
              ),
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.move,
                child: _DriveMenuItem(
                  icon: Icons.drive_file_move_rounded,
                  label: 'Pindah folder',
                ),
              ),
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.details,
                child: const _DriveMenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'Detail Properties',
                ),
              ),
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.favorite,
                child: _DriveMenuItem(
                  icon: file.isBookmarked
                      ? Icons.bookmark_remove_rounded
                      : Icons.bookmark_add_rounded,
                  label: file.isBookmarked
                      ? 'Hapus dari Favorit'
                      : 'Tambah ke Favorit',
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.delete,
                child: _DriveMenuItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  destructive: true,
                ),
              ),
            ],
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceAlt,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveMenuItem extends StatelessWidget {
  const _DriveMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.red : AppColors.ink;

    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentEmptyState extends StatelessWidget {
  const _DocumentEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      padding: const EdgeInsets.all(24),
      backgroundColor: AppColors.surfaceAlt,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.folder_off_rounded,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantLoadingState extends StatelessWidget {
  const _AssistantLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BrandSurface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Memuat knowledge workspace...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentLoadingState extends StatelessWidget {
  const _DocumentLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BrandSurface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Memuat dokumen...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeInlineError extends StatelessWidget {
  const _KnowledgeInlineError({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Muat ulang',
  });

  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: AppColors.surfaceAlt,
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.goldDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onRetry, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    super.key,
    required this.prompts,
    required this.onPromptTap,
  });

  final List<_AssistantPrompt> prompts;
  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          const SizedBox(height: 64),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.goldSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.goldDeep,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Apa yang ingin Anda ketahui?',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Tanya SOP, panduan, atau proses internal perusahaan.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          for (var index = 0; index < prompts.length; index++) ...[
            RevealUp(
              index: index,
              child: _AssistantPromptCard(
                prompt: prompts[index],
                onTap: () => onPromptTap(prompts[index].prompt),
              ),
            ),
            if (index != prompts.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AssistantPromptCard extends StatelessWidget {
  const _AssistantPromptCard({required this.prompt, required this.onTap});

  final _AssistantPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(prompt.icon, color: AppColors.goldDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prompt.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.arrow_outward_rounded,
            size: 18,
            color: AppColors.inkMuted,
          ),
        ],
      ),
    );
  }
}

class _AssistantComposerField extends StatelessWidget {
  const _AssistantComposerField({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final isFocused = focusNode.hasFocus;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isFocused ? AppColors.borderStrong : AppColors.border,
              width: isFocused ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isFocused
                    ? const Color(0x1A9B6B17)
                    : const Color(0x12291C09),
                blurRadius: isFocused ? 24 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tanyakan knowledge internal...',
                      hintMaxLines: 1,
                      hintStyle: textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssistantComposerIconButton extends StatelessWidget {
  const _AssistantComposerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E291C09),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.ink, size: 28),
        ),
      ),
    );
  }
}

class _AssistantComposerSendButton extends StatelessWidget {
  const _AssistantComposerSendButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: enabled ? AppColors.goldDeep : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: enabled ? null : Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12291C09),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            enabled ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
            color: enabled ? Colors.white : AppColors.ink,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _AssistantThreadItem extends StatelessWidget {
  const _AssistantThreadItem({
    required this.message,
    required this.onSourceTap,
    required this.actionsEnabled,
    required this.onActionTap,
  });

  final _AssistantMessage message;
  final ValueChanged<_AssistantSource> onSourceTap;
  final bool actionsEnabled;
  final void Function(_AssistantMessage message, _AssistantAction action)
  onActionTap;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              message.text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
            ),
          ),
        ),
      );
    }

    return BrandSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asisten',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.goldDeep,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message.text,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.ink, height: 1.55),
          ),
          if (message.sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Sources',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < message.sources.length; index++) ...[
              _AssistantSourceCard(
                source: message.sources[index],
                onTap: message.sources[index].documentId == null
                    ? null
                    : () => onSourceTap(message.sources[index]),
              ),
              if (index != message.sources.length - 1)
                const SizedBox(height: 10),
            ],
          ],
          if (message.sourceClosing != null) ...[
            const SizedBox(height: 14),
            Text(
              message.sourceClosing!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.ink,
                height: 1.55,
              ),
            ),
          ],
          if (message.actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final action in message.actions)
                  _AssistantActionButton(
                    action: action,
                    enabled: actionsEnabled,
                    onTap: () => onActionTap(message, action),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AssistantActionButton extends StatelessWidget {
  const _AssistantActionButton({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final _AssistantAction action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (action.sourceAction.isPrimary) {
      return FilledButton(
        onPressed: enabled ? onTap : null,
        child: Text(action.label),
      );
    }

    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      child: Text(action.label),
    );
  }
}

class _AssistantSourceCard extends StatelessWidget {
  const _AssistantSourceCard({required this.source, this.onTap});

  final _AssistantSource source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: source.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_rounded,
              color: source.accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  source.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_outward_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class _AssistantTypingCard extends StatelessWidget {
  const _AssistantTypingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _AssistantPrompt {
  const _AssistantPrompt({
    required this.title,
    required this.prompt,
    required this.icon,
  });

  final String title;
  final String prompt;
  final IconData icon;
}

class _AssistantSource {
  const _AssistantSource({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.documentId,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final String? documentId;
}

class _AssistantMessage {
  const _AssistantMessage._({
    required this.text,
    required this.isUser,
    this.sourceMessage,
    this.sourceClosing,
    this.sources = const [],
    this.actions = const [],
  });

  const _AssistantMessage.user({required String text})
    : this._(text: text, isUser: true);

  const _AssistantMessage.assistant({
    required String text,
    KnowledgeAssistantMessage? sourceMessage,
    String? sourceClosing,
    List<_AssistantSource> sources = const [],
    List<_AssistantAction> actions = const [],
  }) : this._(
         text: text,
         isUser: false,
         sourceMessage: sourceMessage,
         sourceClosing: sourceClosing,
         sources: sources,
         actions: actions,
       );

  final String text;
  final bool isUser;
  final KnowledgeAssistantMessage? sourceMessage;
  final String? sourceClosing;
  final List<_AssistantSource> sources;
  final List<_AssistantAction> actions;
}

class _AssistantAction {
  const _AssistantAction({required this.label, required this.sourceAction});

  final String label;
  final KnowledgeConversationAction sourceAction;
}

class _KnowledgeConversation {
  _KnowledgeConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required List<_AssistantMessage> messages,
  }) : messages = List<_AssistantMessage>.from(messages);

  final String id;
  final List<_AssistantMessage> messages;
  String title;
  DateTime updatedAt;

  String get preview =>
      messages.isEmpty ? 'Belum ada isi obrolan.' : messages.last.text;
}

class _KnowledgeSpace {
  const _KnowledgeSpace({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.folders,
    this.defaultSectionId,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<_KnowledgeFolder> folders;
  final String? defaultSectionId;
}

class _KnowledgeFolder {
  const _KnowledgeFolder({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.caption,
    required this.updatedLabel,
  });

  final String id;
  final String spaceId;
  final String name;
  final String caption;
  final String updatedLabel;
}

class _MoveTarget {
  const _MoveTarget({
    required this.sectionId,
    required this.spaceId,
    required this.label,
    required this.isRoot,
  });

  final String sectionId;
  final String spaceId;
  final String label;
  final bool isRoot;
}

enum _CreateMenuAction { folder, document }

enum _UploadMenuAction { document, file }

class _FolderDraft {
  const _FolderDraft({required this.name, this.description});

  final String name;
  final String? description;
}

class _UploadDraft {
  const _UploadDraft({required this.title, this.summary});

  final String title;
  final String? summary;
}

class _DocumentDraft {
  const _DocumentDraft({required this.title, required this.body});

  final String title;
  final String body;
}

class _CreateMenuSheet extends StatelessWidget {
  const _CreateMenuSheet();

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: 'Buat baru',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DriveChoiceTile(
            icon: Icons.create_new_folder_rounded,
            title: 'Folder',
            subtitle: 'Buat folder di divisi yang sedang dibuka.',
            onTap: () => Navigator.of(context).pop(_CreateMenuAction.folder),
          ),
          const SizedBox(height: 10),
          _DriveChoiceTile(
            icon: Icons.note_add_rounded,
            title: 'Dokumen',
            subtitle: 'Buat dokumen teks langsung dari aplikasi.',
            onTap: () => Navigator.of(context).pop(_CreateMenuAction.document),
          ),
        ],
      ),
    );
  }
}

class _UploadMenuSheet extends StatelessWidget {
  const _UploadMenuSheet();

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: 'Upload',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DriveChoiceTile(
            icon: Icons.description_rounded,
            title: 'Upload dokumen',
            subtitle: 'PDF, Word, Excel, PPT, atau dokumen kerja lain.',
            onTap: () => Navigator.of(context).pop(_UploadMenuAction.document),
          ),
          const SizedBox(height: 10),
          _DriveChoiceTile(
            icon: Icons.upload_file_rounded,
            title: 'Upload file',
            subtitle: 'Upload lampiran umum ke folder saat ini.',
            onTap: () => Navigator.of(context).pop(_UploadMenuAction.file),
          ),
        ],
      ),
    );
  }
}

class _DriveChoiceTile extends StatelessWidget {
  const _DriveChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.goldDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareLinkSheet extends StatelessWidget {
  const _ShareLinkSheet({
    required this.title,
    required this.shareUrl,
    required this.onNativeShare,
  });

  final String title;
  final String shareUrl;
  final VoidCallback onNativeShare;

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: 'Share dokumen',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              shareUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: shareUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link sudah disalin.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNativeShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleInputSheet extends StatelessWidget {
  const _SingleInputSheet({
    required this.title,
    required this.label,
    required this.controller,
    required this.submitLabel,
  });

  final String title;
  final String label;
  final TextEditingController controller;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (_) => _submit(context),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _submit(context),
              child: Text(submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }
}

class _CreateFolderSheet extends StatelessWidget {
  const _CreateFolderSheet({
    required this.nameController,
    required this.descriptionController,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: 'Folder baru',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama folder'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  _FolderDraft(
                    name: name,
                    description: _blankToNull(descriptionController.text),
                  ),
                );
              },
              child: const Text('Buat folder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadDocumentSheet extends StatelessWidget {
  const _UploadDocumentSheet({
    required this.fileName,
    required this.titleController,
    required this.summaryController,
  });

  final String fileName;
  final TextEditingController titleController;
  final TextEditingController summaryController;

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: 'Upload file',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Judul dokumen'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: summaryController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ringkasan'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  _UploadDraft(
                    title: title,
                    summary: _blankToNull(summaryController.text),
                  ),
                );
              },
              child: const Text('Upload'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateDocumentSheet extends StatelessWidget {
  const _CreateDocumentSheet({
    required this.titleController,
    required this.bodyController,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: 'Dokumen baru',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Judul dokumen'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Isi dokumen'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final body = bodyController.text.trim();
                if (title.isEmpty || body.isEmpty) {
                  return;
                }
                Navigator.of(
                  context,
                ).pop(_DocumentDraft(title: title, body: body));
              },
              child: const Text('Buat dokumen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveDocumentSheet extends StatelessWidget {
  const _MoveDocumentSheet({required this.targets});

  final List<_MoveTarget> targets;

  @override
  Widget build(BuildContext context) {
    return _DriveActionSheet(
      title: 'Pindah ke',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.separated(
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final target = targets[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                target.isRoot ? Icons.home_work_rounded : Icons.folder_rounded,
                color: AppColors.goldDeep,
              ),
              title: Text(
                target.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(target),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: targets.length,
        ),
      ),
    );
  }
}

class _DriveActionSheet extends StatelessWidget {
  const _DriveActionSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + bottomInset),
      child: BrandSurface(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _KnowledgeDocumentFile {
  _KnowledgeDocumentFile({
    required this.id,
    required this.spaceId,
    required this.folderId,
    required this.title,
    required this.summary,
    required this.typeLabel,
    required this.pathLabel,
    required this.sizeLabel,
    required this.updatedLabel,
    required this.lastAccessedLabel,
    required this.ownerLabel,
    required this.previewText,
    required this.icon,
    required this.typeColor,
    required this.updatedAt,
    this.attachmentUrl,
    this.attachmentName,
    this.sourceLink,
    this.isBookmarked = false,
  });

  final String id;
  final String spaceId;
  final String folderId;
  final String title;
  final String summary;
  final String typeLabel;
  final String pathLabel;
  final String sizeLabel;
  final String updatedLabel;
  final String lastAccessedLabel;
  final String ownerLabel;
  final String previewText;
  final IconData icon;
  final Color typeColor;
  final DateTime updatedAt;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? sourceLink;
  bool isBookmarked;
}

_KnowledgeSpace _adaptSpace(KnowledgeHubSpace space) {
  final accentColor = _spaceAccentColor(space);
  return _KnowledgeSpace(
    id: space.id,
    name: space.name,
    description: space.description,
    icon: _spaceIconFor(space),
    accentColor: accentColor,
    defaultSectionId: space.defaultSectionId,
    folders: space.folders.map(_adaptFolder).toList(growable: false),
  );
}

_KnowledgeFolder _adaptFolder(KnowledgeHubFolder folder) {
  return _KnowledgeFolder(
    id: folder.id,
    spaceId: folder.spaceId,
    name: folder.name,
    caption: folder.description.isEmpty
        ? '${folder.entryCount} dokumen'
        : folder.description,
    updatedLabel: '${folder.entryCount} item',
  );
}

_KnowledgeDocumentFile _adaptDocument(KnowledgeHubDocument document) {
  final typeColor = _documentTypeColor(document);
  final previewText = document.body.trim().isNotEmpty
      ? document.body.trim()
      : document.summary.trim();
  final formatLabel =
      document.attachmentMime ??
      document.sourceKindLabel.trim().ifEmpty('Knowledge entry');

  return _KnowledgeDocumentFile(
    id: document.id,
    spaceId: document.spaceId,
    folderId: document.folderId,
    title: document.title,
    summary: document.summary,
    typeLabel: document.typeLabel,
    pathLabel: document.pathLabel,
    sizeLabel: formatLabel,
    updatedLabel: _dateLabel(document.updatedAt),
    lastAccessedLabel: _dateLabel(document.updatedAt),
    ownerLabel: document.ownerLabel,
    previewText: previewText.isEmpty
        ? 'Konten detail dokumen belum tersedia.'
        : previewText,
    icon: _documentIconFor(document),
    typeColor: typeColor,
    updatedAt: document.updatedAt,
    attachmentUrl: document.attachmentUrl,
    attachmentName: document.attachmentName,
    sourceLink: document.sourceLink,
    isBookmarked: document.isBookmarked,
  );
}

_KnowledgeConversation _adaptConversation(
  KnowledgeConversationSummary conversation,
) {
  return _KnowledgeConversation(
    id: conversation.id,
    title: conversation.title,
    updatedAt: conversation.updatedAt,
    messages: conversation.preview.trim().isEmpty
        ? const <_AssistantMessage>[]
        : [_AssistantMessage.assistant(text: conversation.preview)],
  );
}

_AssistantMessage _adaptAssistantMessage(KnowledgeAssistantMessage message) {
  if (message.isUser) {
    return _AssistantMessage.user(text: message.text);
  }

  return _AssistantMessage.assistant(
    text: message.text,
    sourceMessage: message,
    sourceClosing: message.sourceClosing,
    sources: message.sources.map(_adaptAssistantSource).toList(growable: false),
    actions: message.actions.map(_adaptAssistantAction).toList(growable: false),
  );
}

_AssistantSource _adaptAssistantSource(KnowledgeAssistantSource source) {
  return _AssistantSource(
    title: source.title,
    subtitle: source.subtitle,
    accentColor: _sourceAccentColor(source),
    documentId: source.documentId,
  );
}

_AssistantAction _adaptAssistantAction(KnowledgeConversationAction action) {
  return _AssistantAction(label: action.label, sourceAction: action);
}

IconData _promptIconFor(String question) {
  final normalized = question.toLowerCase();
  if (normalized.contains('akses') || normalized.contains('s21')) {
    return Icons.lock_open_rounded;
  }
  if (normalized.contains('dokumen') || normalized.contains('onboarding')) {
    return Icons.folder_copy_rounded;
  }
  if (normalized.contains('helpdesk') || normalized.contains('ticket')) {
    return Icons.support_agent_rounded;
  }
  return Icons.fact_check_rounded;
}

IconData _spaceIconFor(KnowledgeHubSpace space) {
  final normalized = '${space.iconKey} ${space.name}'.toLowerCase();
  if (normalized.contains('shield') || normalized.contains('security')) {
    return Icons.shield_rounded;
  }
  if (normalized.contains('it') || normalized.contains('tech')) {
    return Icons.dns_rounded;
  }
  if (normalized.contains('finance') || normalized.contains('accounting')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (normalized.contains('procurement') || normalized.contains('vendor')) {
    return Icons.inventory_2_rounded;
  }
  return Icons.apartment_rounded;
}

Color _spaceAccentColor(KnowledgeHubSpace space) {
  final normalized = '${space.name} ${space.kind}'.toLowerCase();
  if (normalized.contains('it') || normalized.contains('security')) {
    return AppColors.blue;
  }
  if (normalized.contains('procurement') || normalized.contains('vendor')) {
    return AppColors.emerald;
  }
  if (normalized.contains('helpdesk') || normalized.contains('incident')) {
    return AppColors.red;
  }
  return AppColors.goldDeep;
}

IconData _documentIconFor(KnowledgeHubDocument document) {
  final normalized =
      '${document.type} ${document.typeLabel} ${document.attachmentMime ?? ''}'
          .toLowerCase();
  if (normalized.contains('pdf')) {
    return Icons.picture_as_pdf_rounded;
  }
  if (normalized.contains('sheet') || normalized.contains('excel')) {
    return Icons.grid_view_rounded;
  }
  if (normalized.contains('image')) {
    return Icons.image_rounded;
  }
  return Icons.description_rounded;
}

Color _documentTypeColor(KnowledgeHubDocument document) {
  final normalized = '${document.type} ${document.typeLabel}'.toLowerCase();
  if (normalized.contains('troubleshooting') ||
      normalized.contains('incident')) {
    return AppColors.red;
  }
  if (normalized.contains('onboarding') || normalized.contains('vendor')) {
    return AppColors.emerald;
  }
  if (normalized.contains('policy') || normalized.contains('jobdesk')) {
    return AppColors.blue;
  }
  if (normalized.contains('pdf')) {
    return AppColors.red;
  }
  return AppColors.goldDeep;
}

Color _sourceAccentColor(KnowledgeAssistantSource source) {
  final normalized = '${source.title} ${source.subtitle}'.toLowerCase();
  if (normalized.contains('it') || normalized.contains('security')) {
    return AppColors.blue;
  }
  if (normalized.contains('vendor') || normalized.contains('procurement')) {
    return AppColors.emerald;
  }
  if (normalized.contains('helpdesk') || normalized.contains('incident')) {
    return AppColors.red;
  }
  return AppColors.goldDeep;
}

String _dateLabel(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return 'Belum tercatat';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final normalizedDate = DateTime(date.year, date.month, date.day);
  if (normalizedDate == today) {
    return 'Hari ini';
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String? _blankToNull(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _titleFromPickedFile(String fileName) {
  final normalized = fileName.trim();
  if (normalized.isEmpty) {
    return 'Dokumen baru';
  }

  return normalized.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
}

String _safeDocumentFileName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'gesit-document' : cleaned;
}

extension _BlankStringX on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
