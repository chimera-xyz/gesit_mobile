import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class KnowledgeWorkspaceScreen extends StatefulWidget {
  const KnowledgeWorkspaceScreen({super.key});

  @override
  State<KnowledgeWorkspaceScreen> createState() =>
      _KnowledgeWorkspaceScreenState();
}

enum _KnowledgeWorkspaceView { assistant, documents }

enum _DocumentHubFilter { all, folders, files, bookmarked }

enum _FileActionMenuItem { details, favorite }

class _KnowledgeWorkspaceScreenState extends State<KnowledgeWorkspaceScreen> {
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

  late final List<_KnowledgeSpace> _spaces = _buildDemoSpaces();
  late final List<_KnowledgeDocumentFile> _documents = _buildDemoDocuments();
  late final List<_KnowledgeConversation> _conversationHistory =
      _buildSeedConversations();

  _KnowledgeWorkspaceView _currentView = _KnowledgeWorkspaceView.assistant;
  _DocumentHubFilter _documentFilter = _DocumentHubFilter.all;
  bool _isResponding = false;
  String? _activeConversationId;
  String? _selectedSpaceId;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _composerController.addListener(_refreshState);
    _documentSearchController.addListener(_refreshState);
  }

  @override
  void dispose() {
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

  void _refreshState() {
    if (mounted) {
      setState(() {});
    }
  }

  _KnowledgeConversation? get _activeConversation {
    final activeId = _activeConversationId;
    if (activeId == null) {
      return null;
    }

    for (final conversation in _conversationHistory) {
      if (conversation.id == activeId) {
        return conversation;
      }
    }

    return null;
  }

  List<_AssistantMessage> get _messages =>
      _activeConversation?.messages ?? const [];

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

  List<_KnowledgeFolder> get _allFolders {
    final folders = <_KnowledgeFolder>[];
    for (final space in _spaces) {
      folders.addAll(space.folders);
    }
    return folders;
  }

  List<_KnowledgeFolder> get _visibleFolders {
    if (_documentFilter == _DocumentHubFilter.files ||
        _documentFilter == _DocumentHubFilter.bookmarked ||
        _selectedFolderId != null) {
      return const [];
    }

    final folders = _selectedSpace?.folders ?? _allFolders;

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
      _activeConversationId = null;
      _isResponding = false;
      _composerController.clear();
      _currentView = _KnowledgeWorkspaceView.assistant;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _openConversation(String conversationId) {
    setState(() {
      _activeConversationId = conversationId;
      _currentView = _KnowledgeWorkspaceView.assistant;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    _scrollToBottom();
  }

  Future<void> _sendMessage([String? seededPrompt]) async {
    final value = (seededPrompt ?? _composerController.text).trim();
    if (value.isEmpty || _isResponding) {
      return;
    }

    var conversation = _activeConversation;
    if (conversation == null) {
      conversation = _KnowledgeConversation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _conversationTitleFor(value),
        updatedAt: DateTime(2026, 4, 18, 9, 20),
        messages: const [],
      );
      _conversationHistory.add(conversation);
      _activeConversationId = conversation.id;
    }

    setState(() {
      conversation!.messages.add(_AssistantMessage.user(text: value));
      conversation.updatedAt = DateTime.now();
      _composerController.clear();
      _isResponding = true;
    });

    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 480));
    if (!mounted) {
      return;
    }

    setState(() {
      conversation!.messages.add(_buildReply(value));
      conversation.updatedAt = DateTime.now();
      _isResponding = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) {
        return;
      }

      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent + 180,
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

  _AssistantMessage _buildReply(String prompt) {
    final normalized = prompt.toLowerCase();

    if (normalized.contains('approval') || normalized.contains('pengadaan')) {
      return const _AssistantMessage.assistant(
        text:
            'Alur umumnya: requester isi form pengadaan, head division review kebutuhan, finance validasi budget, lalu procurement proses vendor dan dokumen final. Fokus mobile utamanya ada pada justifikasi bisnis, budget owner, dan quotation.',
        sources: [
          _AssistantSource(
            title: 'SOP Approval Pengadaan',
            subtitle: 'Corporate Operations · SOP',
            accentColor: AppColors.goldDeep,
            documentId: 'doc-approval-procurement',
          ),
          _AssistantSource(
            title: 'Panduan Vendor Onboarding',
            subtitle: 'Procurement · Panduan',
            accentColor: AppColors.emerald,
            documentId: 'doc-vendor-onboarding',
          ),
        ],
      );
    }

    if (normalized.contains('s21') || normalized.contains('akses')) {
      return const _AssistantMessage.assistant(
        text:
            'Untuk akses user baru, biasanya dibutuhkan data user, role yang diminta, justifikasi akses, dan tanggal efektif. Setelah itu approval manager berjalan dulu, lalu validasi IT security dan IT operations sebelum akses aktif.',
        sources: [
          _AssistantSource(
            title: 'Panduan Akses S21+',
            subtitle: 'IT Security · Panduan',
            accentColor: AppColors.blue,
            documentId: 'doc-s21-access',
          ),
        ],
      );
    }

    if (normalized.contains('vendor')) {
      return const _AssistantMessage.assistant(
        text:
            'Dokumen yang umum diminta untuk vendor onboarding adalah identitas perusahaan, NPWP, rekening pembayaran, PIC vendor, dan dokumen legal pendukung. Kalau prosesnya melibatkan pembayaran, finance biasanya ikut validasi data rekening.',
        sources: [
          _AssistantSource(
            title: 'Panduan Vendor Onboarding',
            subtitle: 'Procurement · Panduan',
            accentColor: AppColors.emerald,
            documentId: 'doc-vendor-onboarding',
          ),
          _AssistantSource(
            title: 'Checklist Due Diligence Vendor',
            subtitle: 'Procurement · Checklist',
            accentColor: AppColors.goldDeep,
            documentId: 'doc-vendor-due-diligence',
          ),
        ],
      );
    }

    if (normalized.contains('helpdesk') || normalized.contains('kritikal')) {
      return const _AssistantMessage.assistant(
        text:
            'Checklist awal ticket helpdesk kritikal: identifikasi area terdampak, cek scope user atau device, catat waktu mulai incident, assign PIC aktif, dan update status berkala sampai mitigasi selesai. Untuk issue jaringan inti, escalation sebaiknya dilakukan paling awal.',
        sources: [
          _AssistantSource(
            title: 'FAQ Helpdesk Internal',
            subtitle: 'IT Support · FAQ',
            accentColor: AppColors.red,
            documentId: 'doc-helpdesk-faq',
          ),
          _AssistantSource(
            title: 'Runbook Incident Kritikal',
            subtitle: 'IT Support · Runbook',
            accentColor: AppColors.red,
            documentId: 'doc-incident-runbook',
          ),
        ],
      );
    }

    return const _AssistantMessage.assistant(
      text:
          'Saya bisa bantu ringkas SOP, jelaskan alur approval, bantu cari knowledge item, atau buat checklist proses internal. Coba spesifikkan topiknya seperti approval, akses sistem, vendor onboarding, atau helpdesk.',
      sources: [
        _AssistantSource(
          title: 'Knowledge Workspace GESIT',
          subtitle: 'AI Assistant · Internal Workspace',
          accentColor: AppColors.goldDeep,
          documentId: 'doc-mobile-workspace',
        ),
      ],
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
      _selectedFolderId = file.folderId;
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
    final file = _findDocumentById(fileId);
    if (file == null) {
      return;
    }

    setState(() {
      file.isBookmarked = !file.isBookmarked;
    });
  }

  void _handleFileTap(_KnowledgeDocumentFile file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Preview "${file.title}" siap disambungkan ke backend dokumen.',
        ),
      ),
    );
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
                _DetailInfoRow(label: 'Size', value: file.sizeLabel),
                _DetailInfoRow(
                  label: 'Terakhir diakses',
                  value: file.lastAccessedLabel,
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

  String _conversationTitleFor(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.length <= 34) {
      return trimmed;
    }
    return '${trimmed.substring(0, 34).trimRight()}...';
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
    final canSend = _composerController.text.trim().isNotEmpty;

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
                ? _AssistantEmptyState(
                    key: const ValueKey('assistant-empty'),
                    prompts: _prompts,
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
                        return const _AssistantTypingCard();
                      }

                      return _AssistantThreadItem(
                        message: _messages[index],
                        onSourceTap: _jumpToSource,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemCount: _messages.length + (_isResponding ? 1 : 0),
                  ),
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
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _DocumentBreadcrumbs(
                space: _selectedSpace,
                folder: _selectedFolder,
                onRootTap: _goToDocumentRoot,
                onSpaceTap: _selectedSpace == null
                    ? null
                    : () => _selectSpace(_selectedSpace!.id),
              ),
              const SizedBox(height: 18),
              if (_visibleFolders.isNotEmpty) ...[
                _DriveSectionLabel(
                  title: _selectedSpace == null
                      ? 'Folders'
                      : _selectedSpace!.name,
                ),
                const SizedBox(height: 12),
                _DriveFolderGrid(
                  folders: _visibleFolders,
                  onTap: _selectFolder,
                ),
              ],
              if (_recentFiles.isNotEmpty && _selectedSpaceId == null) ...[
                const SizedBox(height: 22),
                const _DriveSectionLabel(title: 'Recent'),
                const SizedBox(height: 12),
                ..._recentFiles.map((file) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DriveFileTile(
                      file: file,
                      onTap: () => _handleFileTap(file),
                      onShowProperties: () => _showFileProperties(file),
                      onToggleBookmark: () => _toggleBookmark(file.id),
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
                      onTap: () => _handleFileTap(file),
                      onShowProperties: () => _showFileProperties(file),
                      onToggleBookmark: () => _toggleBookmark(file.id),
                    ),
                  );
                }),
              ],
              if (_visibleFolders.isEmpty &&
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

class _DriveFileTile extends StatelessWidget {
  const _DriveFileTile({
    required this.file,
    required this.onTap,
    required this.onShowProperties,
    required this.onToggleBookmark,
  });

  final _KnowledgeDocumentFile file;
  final VoidCallback onTap;
  final VoidCallback onShowProperties;
  final VoidCallback onToggleBookmark;

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
                case _FileActionMenuItem.details:
                  onShowProperties();
                case _FileActionMenuItem.favorite:
                  onToggleBookmark();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.details,
                child: Text(
                  'Detail Properties',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuItem<_FileActionMenuItem>(
                value: _FileActionMenuItem.favorite,
                child: Text(
                  file.isBookmarked
                      ? 'Hapus dari Favorit'
                      : 'Tambah ke Favorit',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
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
  });

  final _AssistantMessage message;
  final ValueChanged<_AssistantSource> onSourceTap;

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
            'Assistant',
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
        ],
      ),
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
  const _AssistantTypingCard();

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
            'Assistant sedang menyiapkan jawaban...',
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
    this.sources = const [],
  });

  const _AssistantMessage.user({required String text})
    : this._(text: text, isUser: true);

  const _AssistantMessage.assistant({
    required String text,
    List<_AssistantSource> sources = const [],
  }) : this._(text: text, isUser: false, sources: sources);

  final String text;
  final bool isUser;
  final List<_AssistantSource> sources;
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
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<_KnowledgeFolder> folders;
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
  bool isBookmarked;
}

List<_KnowledgeConversation> _buildSeedConversations() {
  return [
    _KnowledgeConversation(
      id: 'conv-s21-access',
      title: 'Akses S21+ User Baru',
      updatedAt: DateTime(2026, 4, 18, 9, 10),
      messages: const [
        _AssistantMessage.user(text: 'Bagaimana proses akses S21+ user baru?'),
        _AssistantMessage.assistant(
          text:
              'Untuk akses user baru, biasanya dibutuhkan data user, role yang diminta, justifikasi akses, dan tanggal efektif. Setelah itu approval manager berjalan dulu, lalu validasi IT security dan IT operations sebelum akses aktif.',
          sources: [
            _AssistantSource(
              title: 'Panduan Akses S21+',
              subtitle: 'IT Security · Panduan',
              accentColor: AppColors.blue,
              documentId: 'doc-s21-access',
            ),
          ],
        ),
      ],
    ),
    _KnowledgeConversation(
      id: 'conv-vendor-onboarding',
      title: 'Vendor Onboarding',
      updatedAt: DateTime(2026, 4, 17, 15, 42),
      messages: const [
        _AssistantMessage.user(
          text: 'Dokumen apa yang dibutuhkan vendor onboarding?',
        ),
        _AssistantMessage.assistant(
          text:
              'Dokumen yang umum diminta adalah identitas perusahaan, NPWP, rekening pembayaran, PIC vendor, dan dokumen legal pendukung. Finance biasanya ikut validasi rekening dan kelengkapan dokumen.',
          sources: [
            _AssistantSource(
              title: 'Panduan Vendor Onboarding',
              subtitle: 'Procurement · Panduan',
              accentColor: AppColors.emerald,
              documentId: 'doc-vendor-onboarding',
            ),
            _AssistantSource(
              title: 'Checklist Due Diligence Vendor',
              subtitle: 'Procurement · Checklist',
              accentColor: AppColors.goldDeep,
              documentId: 'doc-vendor-due-diligence',
            ),
          ],
        ),
      ],
    ),
    _KnowledgeConversation(
      id: 'conv-helpdesk',
      title: 'Helpdesk Kritikal',
      updatedAt: DateTime(2026, 4, 16, 11, 28),
      messages: const [
        _AssistantMessage.user(text: 'Buat checklist helpdesk kritikal'),
        _AssistantMessage.assistant(
          text:
              'Checklist awal ticket helpdesk kritikal: identifikasi area terdampak, cek scope user atau device, catat waktu mulai incident, assign PIC aktif, dan update status berkala sampai mitigasi selesai.',
          sources: [
            _AssistantSource(
              title: 'Runbook Incident Kritikal',
              subtitle: 'IT Support · Runbook',
              accentColor: AppColors.red,
              documentId: 'doc-incident-runbook',
            ),
          ],
        ),
      ],
    ),
  ];
}

List<_KnowledgeSpace> _buildDemoSpaces() {
  return const [
    _KnowledgeSpace(
      id: 'space-ops',
      name: 'Corporate Operations',
      description: 'SOP approval, procurement, dan workflow operasional.',
      icon: Icons.apartment_rounded,
      accentColor: AppColors.goldDeep,
      folders: [
        _KnowledgeFolder(
          id: 'folder-procurement',
          spaceId: 'space-ops',
          name: 'Procurement',
          caption: 'SOP pembelian, approval, dan quotation',
          updatedLabel: 'Hari ini',
        ),
        _KnowledgeFolder(
          id: 'folder-policy',
          spaceId: 'space-ops',
          name: 'Policy & SOP',
          caption: 'Panduan operasional lintas divisi',
          updatedLabel: '17 Apr',
        ),
      ],
    ),
    _KnowledgeSpace(
      id: 'space-it',
      name: 'IT Security',
      description: 'Akses sistem, security baseline, dan runbook teknis.',
      icon: Icons.shield_rounded,
      accentColor: AppColors.blue,
      folders: [
        _KnowledgeFolder(
          id: 'folder-access',
          spaceId: 'space-it',
          name: 'Access Management',
          caption: 'Provisioning user, role, dan review akses',
          updatedLabel: 'Hari ini',
        ),
        _KnowledgeFolder(
          id: 'folder-runbook',
          spaceId: 'space-it',
          name: 'Runbook',
          caption: 'Incident handling dan checklist recovery',
          updatedLabel: '16 Apr',
        ),
      ],
    ),
    _KnowledgeSpace(
      id: 'space-proc',
      name: 'Procurement',
      description: 'Vendor onboarding, due diligence, dan legal support.',
      icon: Icons.inventory_2_rounded,
      accentColor: AppColors.emerald,
      folders: [
        _KnowledgeFolder(
          id: 'folder-vendor',
          spaceId: 'space-proc',
          name: 'Vendor Onboarding',
          caption: 'Dokumen vendor dan checklist legal',
          updatedLabel: '17 Apr',
        ),
        _KnowledgeFolder(
          id: 'folder-contract',
          spaceId: 'space-proc',
          name: 'Contract Support',
          caption: 'Template kontrak dan lampiran pendukung',
          updatedLabel: '15 Apr',
        ),
      ],
    ),
  ];
}

List<_KnowledgeDocumentFile> _buildDemoDocuments() {
  return [
    _KnowledgeDocumentFile(
      id: 'doc-approval-procurement',
      spaceId: 'space-ops',
      folderId: 'folder-procurement',
      title: 'SOP Approval Pengadaan',
      summary: 'Alur approval pengadaan, budget owner, dan lampiran quotation.',
      typeLabel: 'PDF',
      pathLabel: 'Corporate Operations / Procurement',
      sizeLabel: '1.4 MB',
      updatedLabel: 'Hari ini',
      lastAccessedLabel: 'Hari ini, 08.40',
      ownerLabel: 'Operations Team',
      previewText:
          'Dokumen ini menjelaskan alur pengadaan dari tahap request, review head division, validasi budget, hingga procurement execution. Bagian utama yang paling sering dibutuhkan di mobile biasanya justifikasi bisnis, budget owner, dan kelengkapan quotation.',
      icon: Icons.picture_as_pdf_rounded,
      typeColor: AppColors.red,
      updatedAt: DateTime(2026, 4, 18, 8, 40),
      isBookmarked: true,
    ),
    _KnowledgeDocumentFile(
      id: 'doc-mobile-workspace',
      spaceId: 'space-ops',
      folderId: 'folder-policy',
      title: 'Knowledge Workspace Mobile Notes',
      summary:
          'Catatan arsitektur workspace mobile untuk AI Assistant dan document hub.',
      typeLabel: 'DOC',
      pathLabel: 'Corporate Operations / Policy & SOP',
      sizeLabel: '824 KB',
      updatedLabel: 'Hari ini',
      lastAccessedLabel: 'Hari ini, 08.10',
      ownerLabel: 'Product Team',
      previewText:
          'Catatan ini merangkum keputusan UX mobile: Knowledge Hub langsung masuk AI Assistant, history chat ada di drawer, dan Smart Document Hub dipisah dengan interaction pattern ala Google Drive mobile.',
      icon: Icons.description_rounded,
      typeColor: AppColors.goldDeep,
      updatedAt: DateTime(2026, 4, 18, 8, 10),
    ),
    _KnowledgeDocumentFile(
      id: 'doc-s21-access',
      spaceId: 'space-it',
      folderId: 'folder-access',
      title: 'Panduan Akses S21+',
      summary: 'Panduan role, request akses, approval, dan aktivasi akun baru.',
      typeLabel: 'PDF',
      pathLabel: 'IT Security / Access Management',
      sizeLabel: '2.1 MB',
      updatedLabel: 'Hari ini',
      lastAccessedLabel: 'Hari ini, 07.48',
      ownerLabel: 'IT Security',
      previewText:
          'Panduan ini mencakup proses request akses user baru, mapping role, approval manager, validasi IT security, dan aktivasi oleh IT operations. Dipakai sebagai rujukan utama untuk provisioning user di mobile assistant.',
      icon: Icons.picture_as_pdf_rounded,
      typeColor: AppColors.blue,
      updatedAt: DateTime(2026, 4, 18, 7, 48),
      isBookmarked: true,
    ),
    _KnowledgeDocumentFile(
      id: 'doc-incident-runbook',
      spaceId: 'space-it',
      folderId: 'folder-runbook',
      title: 'Runbook Incident Kritikal',
      summary:
          'Checklist awal incident, escalation path, dan koordinasi mitigasi.',
      typeLabel: 'DOC',
      pathLabel: 'IT Security / Runbook',
      sizeLabel: '1.0 MB',
      updatedLabel: '16 Apr',
      lastAccessedLabel: '16 Apr 2026, 13.12',
      ownerLabel: 'IT Support',
      previewText:
          'Runbook ini menekankan identifikasi area terdampak, pencatatan timeline, assignment PIC, dan pola komunikasi sampai service recovery selesai. Cocok dijadikan quick reference saat incident kritikal berjalan.',
      icon: Icons.description_rounded,
      typeColor: AppColors.red,
      updatedAt: DateTime(2026, 4, 16, 13, 12),
    ),
    _KnowledgeDocumentFile(
      id: 'doc-helpdesk-faq',
      spaceId: 'space-it',
      folderId: 'folder-runbook',
      title: 'FAQ Helpdesk Internal',
      summary: 'FAQ kategori ticket, SLA, dan respon awal dari tim support.',
      typeLabel: 'SHEET',
      pathLabel: 'IT Security / Runbook',
      sizeLabel: '612 KB',
      updatedLabel: '15 Apr',
      lastAccessedLabel: '15 Apr 2026, 10.05',
      ownerLabel: 'IT Support',
      previewText:
          'FAQ ini merangkum kategori ticket internal, SLA standar, dan respon awal per jenis insiden. Kontennya dipakai untuk mengarahkan assistant saat memberi checklist quick triage.',
      icon: Icons.grid_view_rounded,
      typeColor: AppColors.red,
      updatedAt: DateTime(2026, 4, 15, 10, 5),
    ),
    _KnowledgeDocumentFile(
      id: 'doc-vendor-onboarding',
      spaceId: 'space-proc',
      folderId: 'folder-vendor',
      title: 'Panduan Vendor Onboarding',
      summary:
          'Dokumen vendor, legal checks, dan validasi rekening pembayaran.',
      typeLabel: 'PDF',
      pathLabel: 'Procurement / Vendor Onboarding',
      sizeLabel: '1.8 MB',
      updatedLabel: '17 Apr',
      lastAccessedLabel: '17 Apr 2026, 16.22',
      ownerLabel: 'Procurement Team',
      previewText:
          'Panduan onboarding vendor berisi daftar dokumen legal, data rekening, NPWP, identitas perusahaan, dan PIC vendor. Finance dan procurement memakai dokumen ini sebagai sumber validasi utama.',
      icon: Icons.picture_as_pdf_rounded,
      typeColor: AppColors.emerald,
      updatedAt: DateTime(2026, 4, 17, 16, 22),
      isBookmarked: true,
    ),
    _KnowledgeDocumentFile(
      id: 'doc-vendor-due-diligence',
      spaceId: 'space-proc',
      folderId: 'folder-vendor',
      title: 'Checklist Due Diligence Vendor',
      summary: 'Checklist legal dan operasional untuk evaluasi vendor baru.',
      typeLabel: 'DOC',
      pathLabel: 'Procurement / Vendor Onboarding',
      sizeLabel: '736 KB',
      updatedLabel: '16 Apr',
      lastAccessedLabel: '16 Apr 2026, 09.34',
      ownerLabel: 'Legal Support',
      previewText:
          'Checklist due diligence ini dipakai untuk memastikan legalitas, kelengkapan dokumen, reputasi vendor, dan kesiapan data pembayaran sebelum vendor diaktifkan di workflow procurement.',
      icon: Icons.description_rounded,
      typeColor: AppColors.goldDeep,
      updatedAt: DateTime(2026, 4, 16, 9, 34),
    ),
    _KnowledgeDocumentFile(
      id: 'doc-contract-template',
      spaceId: 'space-proc',
      folderId: 'folder-contract',
      title: 'Template Kontrak Vendor',
      summary:
          'Template dasar kontrak kerja sama beserta daftar lampiran standar.',
      typeLabel: 'DOC',
      pathLabel: 'Procurement / Contract Support',
      sizeLabel: '942 KB',
      updatedLabel: '15 Apr',
      lastAccessedLabel: '15 Apr 2026, 14.12',
      ownerLabel: 'Legal Support',
      previewText:
          'Template ini dipakai saat procurement sudah masuk tahap finalisasi kerja sama. Struktur lampiran dan klausul utamanya dibuat supaya mudah dipakai lintas vendor dengan penyesuaian terbatas.',
      icon: Icons.description_rounded,
      typeColor: AppColors.emerald,
      updatedAt: DateTime(2026, 4, 15, 14, 12),
    ),
  ];
}
