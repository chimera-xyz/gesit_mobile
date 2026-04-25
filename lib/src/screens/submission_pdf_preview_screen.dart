import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/workspace_data_controller.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class SubmissionPdfPreviewScreen extends StatefulWidget {
  const SubmissionPdfPreviewScreen({
    super.key,
    required this.task,
    required this.controller,
  });

  final TaskItem task;
  final WorkspaceDataController controller;

  @override
  State<SubmissionPdfPreviewScreen> createState() =>
      _SubmissionPdfPreviewScreenState();
}

class _SubmissionPdfPreviewScreenState
    extends State<SubmissionPdfPreviewScreen> {
  Uint8List? _pdfBytes;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPdf();
    });
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await widget.controller.fetchTaskPdfPreview(widget.task);
      if (!mounted) {
        return;
      }

      setState(() => _pdfBytes = bytes);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pdfBytes = null;
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pdfBytes = _pdfBytes;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RevealUp(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface.withValues(
                            alpha: 0.92,
                          ),
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
                              'Pratinjau PDF',
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.task.attachmentLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: RevealUp(
                    index: 1,
                    child: BrandSurface(
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: _loading
                            ? const _PdfLoadingState()
                            : _errorMessage != null
                            ? _PdfErrorState(
                                message: _errorMessage!,
                                onRetry: _loadPdf,
                              )
                            : pdfBytes == null
                            ? _PdfErrorState(
                                message: 'PDF belum tersedia.',
                                onRetry: _loadPdf,
                              )
                            : PdfViewer.data(
                                pdfBytes,
                                sourceName:
                                    'submission-${widget.task.id ?? widget.task.attachmentLabel}-${pdfBytes.length}.pdf',
                              ),
                      ),
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
}

class _PdfLoadingState extends StatelessWidget {
  const _PdfLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PdfErrorState extends StatelessWidget {
  const _PdfErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppColors.red,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              'PDF belum bisa dibuka',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
