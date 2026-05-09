import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/gesit_api_client.dart';
import '../data/knowledge_workspace_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class KnowledgeDocumentPreviewScreen extends StatefulWidget {
  const KnowledgeDocumentPreviewScreen({
    super.key,
    required this.document,
    required this.controller,
  });

  final KnowledgeHubDocument document;
  final KnowledgeWorkspaceController controller;

  @override
  State<KnowledgeDocumentPreviewScreen> createState() =>
      _KnowledgeDocumentPreviewScreenState();
}

class _KnowledgeDocumentPreviewScreenState
    extends State<KnowledgeDocumentPreviewScreen> {
  Uint8List? _bytes;
  String? _contentType;
  String? _errorMessage;
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreview();
    });
  }

  Future<void> _loadPreview() async {
    if (widget.document.attachmentUrl == null) {
      setState(() {
        _loading = false;
        _errorMessage = widget.document.body.trim().isEmpty
            ? 'Dokumen ini belum punya konten preview.'
            : null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final payload = await widget.controller.fetchDocumentPreview(
        widget.document.id,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _bytes = payload.bytes;
        _contentType = _normalizeContentType(
          payload.contentType ?? widget.document.attachmentMime,
        );
      });
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = 'Preview dokumen belum bisa dimuat.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _downloadDocument() async {
    if (_downloading) {
      return;
    }

    setState(() => _downloading = true);
    try {
      final fileName = _safeFileName(
        widget.document.attachmentName ?? '${widget.document.title}.txt',
      );
      final bytes = widget.document.attachmentUrl == null
          ? Uint8List.fromList(utf8.encode(widget.document.body))
          : (await widget.controller.downloadDocument(
              widget.document.id,
            )).bytes;
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDirectory = Directory('${directory.path}/gesit_downloads');
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }
      final file = File('${downloadsDirectory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File tersimpan: ${file.path}')));
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
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.document.pathLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: _downloading ? null : _downloadDocument,
                      tooltip: 'Download',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: _downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: BrandSurface(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildPreviewBody(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _PreviewMessageState(
        icon: Icons.insert_drive_file_rounded,
        title: 'Preview belum tersedia',
        message: _errorMessage!,
        actionLabel: 'Coba lagi',
        onAction: _loadPreview,
      );
    }

    final bytes = _bytes;
    final contentType = _contentType ?? '';

    if (bytes != null && contentType.contains('application/pdf')) {
      return PdfViewer.data(
        bytes,
        sourceName: widget.document.attachmentName ?? widget.document.title,
      );
    }

    if (bytes != null && contentType.startsWith('image/')) {
      return InteractiveViewer(
        minScale: 0.7,
        maxScale: 4,
        child: Center(child: Image.memory(bytes)),
      );
    }

    if (bytes != null && _isTextContent(contentType)) {
      return _TextPreview(text: utf8.decode(bytes, allowMalformed: true));
    }

    if (widget.document.body.trim().isNotEmpty) {
      return _TextPreview(text: widget.document.body.trim());
    }

    return _PreviewMessageState(
      icon: Icons.file_download_rounded,
      title: 'File asli siap diunduh',
      message:
          'Format ini belum punya renderer internal. Download file asli untuk membukanya.',
      actionLabel: 'Download',
      onAction: _downloadDocument,
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.ink, height: 1.55),
      ),
    );
  }
}

class _PreviewMessageState extends StatelessWidget {
  const _PreviewMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.goldDeep),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _normalizeContentType(String? value) {
  return (value ?? '').split(';').first.trim().toLowerCase();
}

bool _isTextContent(String contentType) {
  return contentType.startsWith('text/') ||
      contentType.contains('json') ||
      contentType.contains('xml');
}

String _safeFileName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'gesit-document' : cleaned;
}
