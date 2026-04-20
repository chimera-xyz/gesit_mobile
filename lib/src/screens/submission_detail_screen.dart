import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/demo_data.dart';
import '../data/workspace_data_controller.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class SubmissionDetailScreen extends StatefulWidget {
  const SubmissionDetailScreen({
    super.key,
    required this.task,
    required this.controller,
  });

  final TaskItem task;
  final WorkspaceDataController controller;

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final TextEditingController _approvalNoteController = TextEditingController();
  bool _showProgressDetails = false;
  late TaskItem _task;
  bool _loadingDetail = false;
  bool _processingAction = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;

    if ((_task.id ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLatestDetail();
      });
    }
  }

  List<SubmissionField> get _allSubmissionFields => _task.formFields.isNotEmpty
      ? _task.formFields
      : DemoData.submissionFieldsFor(_task);

  List<SubmissionField> get _detailFields => _allSubmissionFields
      .where((field) => field.label != 'Lampiran')
      .toList(growable: false);

  SubmissionField get _attachment => _allSubmissionFields.firstWhere(
    (field) => field.label == 'Lampiran',
    orElse: () =>
        SubmissionField(label: 'Lampiran', value: _task.attachmentLabel),
  );

  List<SubmissionTimelineStep> get _progressSteps =>
      _task.timelineSteps.isNotEmpty
      ? _task.timelineSteps
      : DemoData.submissionTimelineFor(_task);

  SubmissionTimelineStep? get _activeProgressStep {
    for (final step in _progressSteps) {
      if (step.isActive || step.statusLabel.toLowerCase() == 'aktif') {
        return step;
      }
    }

    return null;
  }

  bool get _currentStepRequiresSignature =>
      _currentAction?.requiresSignature ??
      _activeProgressStep?.requiresSignature ??
      _task.requiresSignature;

  SubmissionAction? get _currentAction =>
      _task.availableActions.isNotEmpty ? _task.availableActions.first : null;

  String get _currentActionTitle =>
      _currentAction?.stepName ??
      _task.currentActionTitle ??
      _activeProgressStep?.title ??
      _task.statusLabel;

  String get _progressSummary {
    if (_task.workflowStatus == TaskSubmissionStatus.rejected) {
      return '${_progressSteps.length} langkah • Workflow dihentikan';
    }

    final activeStep = _activeProgressStep;

    if (activeStep != null) {
      return '${_progressSteps.length} langkah • Aktif: ${activeStep.title}';
    }

    return '${_progressSteps.length} langkah • Semua tahap selesai';
  }

  bool get _showsDecisionActions =>
      _task.lane == TaskLane.actionable && _currentAction != null;

  String get _statusCardEyebrow {
    switch (_task.lane) {
      case TaskLane.actionable:
        return 'Perlu aksi';
      case TaskLane.inProgress:
        return 'Sedang diproses';
      case TaskLane.history:
        return 'Riwayat';
    }
  }

  String get _statusCardDescription {
    switch (_task.lane) {
      case TaskLane.actionable:
        return _currentStepRequiresSignature
            ? 'Langkah ini membutuhkan tanda tangan digital sebelum approval selesai.'
            : 'Langkah ini bisa diproses langsung tanpa tanda tangan tambahan.';
      case TaskLane.inProgress:
        return 'Pengajuan ini masih berjalan di workflow ${_task.workflowLabel} dan belum membutuhkan aksi dari Anda.';
      case TaskLane.history:
        if (_task.workflowStatus == TaskSubmissionStatus.completed) {
          return 'Pengajuan ini sudah selesai dan tidak memerlukan tindak lanjut.';
        }

        return _task.rejectionReason ??
            'Pengajuan ini ditutup pada salah satu tahap review dan perlu direvisi sebelum diajukan ulang.';
    }
  }

  @override
  void dispose() {
    _approvalNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestDetail() async {
    if ((_task.id ?? '').isEmpty) {
      return;
    }

    setState(() => _loadingDetail = true);

    try {
      final updatedTask = await widget.controller.fetchTaskDetail(_task);
      if (!mounted) {
        return;
      }

      setState(() => _task = updatedTask);
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  Future<void> _handleApprovePressed() async {
    final action = _currentAction;
    if (action == null) {
      return;
    }

    if (action.notesRequired && _approvalNoteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan approval wajib diisi untuk langkah ini.'),
        ),
      );
      return;
    }

    String? signatureDataUrl;
    if (_currentStepRequiresSignature) {
      final signed = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        enableDrag: false,
        builder: (context) {
          return _SignatureApprovalSheet(
            title: _currentActionTitle,
            onUseSignature: (signatureDataUrl) =>
                Navigator.of(context).pop(signatureDataUrl),
          );
        },
      );

      if (signed == null || signed.trim().isEmpty || !mounted) {
        return;
      }
      signatureDataUrl = signed;
    }

    setState(() => _processingAction = true);

    try {
      final updatedTask = await widget.controller.approveTask(
        task: _task,
        notes: _approvalNoteController.text.trim(),
        signatureDataUrl: signatureDataUrl,
      );
      if (!mounted) {
        return;
      }

      _approvalNoteController.clear();
      setState(() => _task = updatedTask);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action.label} berhasil diproses.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _processingAction = false);
      }
    }
  }

  Future<void> _handleRejectPressed() async {
    if (_approvalNoteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi alasan atau catatan penolakan terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() => _processingAction = true);

    try {
      final updatedTask = await widget.controller.rejectTask(
        task: _task,
        reason: _approvalNoteController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      _approvalNoteController.clear();
      setState(() => _task = updatedTask);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan berhasil ditolak.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _processingAction = false);
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
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
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
                            alpha: 0.9,
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Submission Detail',
                          style: textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadingDetail) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 18),
                RevealUp(
                  index: 1,
                  child: BrandSurface(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  StatusChip(
                                    label: _task.statusLabel,
                                    color: _task.accentColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _task.timeLabel,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _task.title,
                          style: textTheme.headlineMedium?.copyWith(
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetaTile(label: 'Pemohon', value: _task.requester),
                            _MetaTile(
                              label: 'Workflow',
                              value: _task.workflowLabel,
                            ),
                            _MetaTile(
                              label: 'Tahap saat ini',
                              value: _currentActionTitle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Detail', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                RevealUp(
                  index: 2,
                  child: BrandSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < _detailFields.length;
                          index++
                        ) ...[
                          _FieldRow(field: _detailFields[index]),
                          if (index != _detailFields.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Lampiran', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                RevealUp(
                  index: 3,
                  child: BrandSurface(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _attachment.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dokumen PDF',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: !_task.canPreviewPdf
                              ? null
                              : () async {
                                  final rawUrl =
                                      _task.pdfPreviewUrl ??
                                      _task.pdfDownloadUrl;
                                  final uri = rawUrl == null
                                      ? null
                                      : Uri.tryParse(rawUrl);
                                  if (uri == null) {
                                    return;
                                  }

                                  final launched = await launchUrl(uri);
                                  if (!launched && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'PDF tidak berhasil dibuka.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            _task.canPreviewPdf
                                ? 'Pratinjau'
                                : 'Belum tersedia',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Status', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                RevealUp(
                  index: 4,
                  child: BrandSurface(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusCardEyebrow.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.goldDeep,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _showsDecisionActions
                              ? _currentActionTitle
                              : _task.statusLabel,
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusCardDescription,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        if (_showsDecisionActions) ...[
                          if (_currentStepRequiresSignature)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: StatusChip(
                                label: 'Tanda tangan digital',
                                color: AppColors.red,
                              ),
                            ),
                          Text(
                            'Catatan approval',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _approvalNoteController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  _currentAction?.notesPlaceholder ??
                                  'Tambahkan catatan jika diperlukan',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (_currentAction?.canReject ?? false)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _processingAction
                                        ? null
                                        : _handleRejectPressed,
                                    child: Text(
                                      _processingAction
                                          ? 'Memproses...'
                                          : (_currentAction?.rejectLabel ??
                                                'Tolak'),
                                    ),
                                  ),
                                ),
                              if (_currentAction?.canReject ?? false)
                                const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _processingAction
                                      ? null
                                      : _handleApprovePressed,
                                  child: Text(
                                    _processingAction
                                        ? 'Memproses...'
                                        : (_currentAction?.label ?? 'Setujui'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          StatusChip(
                            label: _task.lane.label,
                            color: _task.accentColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Progress Workflow', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                RevealUp(
                  index: 5,
                  child: BrandSurface(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Progress workflow',
                                    style: textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _progressSummary,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(
                                () => _showProgressDetails =
                                    !_showProgressDetails,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surfaceAlt,
                                side: const BorderSide(color: AppColors.border),
                              ),
                              icon: Icon(
                                _showProgressDetails
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                        if (_showProgressDetails) ...[
                          const SizedBox(height: 16),
                          for (
                            var index = 0;
                            index < _progressSteps.length;
                            index++
                          ) ...[
                            _TimelineRow(
                              index: index + 1,
                              isLast: index == _progressSteps.length - 1,
                              step: _progressSteps[index],
                            ),
                            if (index != _progressSteps.length - 1)
                              const SizedBox(height: 14),
                          ],
                        ],
                      ],
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

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.step,
    required this.isLast,
  });

  final int index;
  final SubmissionTimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final connectorColor =
        step.statusLabel == 'Menunggu' || step.statusLabel == 'Tidak lanjut'
        ? AppColors.border
        : step.accentColor.withValues(alpha: 0.24);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: step.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: step.accentColor.withValues(alpha: 0.2),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(step.icon, size: 20, color: step.accentColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 54,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: connectorColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Tahap $index',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (step.requiresSignature)
                      const StatusChip(
                        label: 'TTD',
                        color: AppColors.red,
                        icon: Icons.draw_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title, style: textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            step.actor,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusChip(
                      label: step.statusLabel,
                      color: step.accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.timeLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.note,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field});

  final SubmissionField field;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              field.label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              field.value,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureApprovalSheet extends StatefulWidget {
  const _SignatureApprovalSheet({
    required this.title,
    required this.onUseSignature,
  });

  final String title;
  final ValueChanged<String> onUseSignature;

  @override
  State<_SignatureApprovalSheet> createState() =>
      _SignatureApprovalSheetState();
}

class _SignatureApprovalSheetState extends State<_SignatureApprovalSheet> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  String? _errorText;
  double _headerDragOffset = 0;
  Size _canvasSize = const Size(1, 1);

  bool get _hasSignature => _strokes.any((stroke) => stroke.isNotEmpty);

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _errorText = null;
      _strokes.add([details.localPosition]);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_strokes.isEmpty) {
      return;
    }

    setState(() {
      _strokes.last.add(details.localPosition);
    });
  }

  void _clearCanvas() {
    setState(() {
      _errorText = null;
      _strokes.clear();
    });
  }

  Future<void> _submit() async {
    if (!_hasSignature) {
      setState(() {
        _errorText = 'Tanda tangan belum digambar.';
      });
      return;
    }

    final signatureDataUrl = await _buildSignatureDataUrl();
    if (signatureDataUrl == null || signatureDataUrl.trim().isEmpty) {
      setState(() {
        _errorText = 'Tanda tangan tidak berhasil diproses.';
      });
      return;
    }

    widget.onUseSignature(signatureDataUrl);
  }

  void _handleHeaderDragUpdate(DragUpdateDetails details) {
    _headerDragOffset += details.delta.dy;
  }

  void _handleHeaderDragEnd(DragEndDetails details) {
    final shouldClose =
        _headerDragOffset > 48 ||
        (details.primaryVelocity != null && details.primaryVelocity! > 650);
    _headerDragOffset = 0;

    if (shouldClose) {
      Navigator.of(context).pop();
    }
  }

  Future<String?> _buildSignatureDataUrl() async {
    final exportSize = Size(
      _canvasSize.width <= 1 ? 900 : _canvasSize.width,
      _canvasSize.height <= 1 ? 420 : _canvasSize.height,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & exportSize;
    canvas.drawRect(rect, Paint()..color = Colors.white);
    _SignatureStrokePainter(strokes: _strokes).paint(canvas, exportSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      exportSize.width.ceil(),
      exportSize.height.ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return null;
    }

    final bytes = byteData.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: BrandSurface(
            radius: 32,
            backgroundColor: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _handleHeaderDragUpdate,
                  onVerticalDragEnd: _handleHeaderDragEnd,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanda Tangan Digital',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.goldDeep,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.title,
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Gores tanda tangan Anda di area putih sebelum approval diproses.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasSize = Size(
                        constraints.maxWidth - 24,
                        constraints.maxHeight - 24,
                      );

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: _handlePanStart,
                            onPanUpdate: _handlePanUpdate,
                            onPanEnd: (_) {},
                            child: CustomPaint(
                              foregroundPainter: _SignatureStrokePainter(
                                strokes: _strokes,
                              ),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: IgnorePointer(
                                  child: !_hasSignature
                                      ? Text(
                                          'Tulis tanda tangan di sini',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: AppColors.inkMuted,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearCanvas,
                      child: const Text('Hapus Canvas'),
                    ),
                  ],
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Gunakan Tanda Tangan Ini'),
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

class _SignatureStrokePainter extends CustomPainter {
  const _SignatureStrokePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }

      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, paint.strokeWidth / 2, paint);
        continue;
      }

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var index = 1; index < stroke.length; index++) {
        path.lineTo(stroke[index].dx, stroke[index].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureStrokePainter oldDelegate) {
    return true;
  }
}
