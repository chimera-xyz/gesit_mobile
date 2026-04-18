import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class SubmissionDetailScreen extends StatefulWidget {
  const SubmissionDetailScreen({super.key, required this.task});

  final TaskItem task;

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final TextEditingController _approvalNoteController = TextEditingController();
  bool _showProgressDetails = false;

  List<SubmissionField> get _allSubmissionFields => DemoData.submissionFields;

  List<SubmissionField> get _detailFields => _allSubmissionFields
      .where((field) => field.label != 'Attachment')
      .toList(growable: false);

  SubmissionField get _attachment => _allSubmissionFields.firstWhere(
    (field) => field.label == 'Attachment',
    orElse: () => const SubmissionField(
      label: 'Attachment',
      value: 'requisition-preview.pdf',
    ),
  );

  List<SubmissionTimelineStep> get _progressSteps =>
      DemoData.submissionTimeline;

  SubmissionTimelineStep? get _activeProgressStep {
    for (final step in _progressSteps) {
      if (step.statusLabel.toLowerCase() == 'active') {
        return step;
      }
    }

    return null;
  }

  bool get _currentStepRequiresSignature =>
      _activeProgressStep?.requiresSignature ?? widget.task.requiresSignature;

  String get _currentActionTitle =>
      _activeProgressStep?.title ?? widget.task.statusLabel;

  String get _progressSummary {
    final activeStep = _activeProgressStep;

    if (activeStep != null) {
      return '${_progressSteps.length} langkah • Aktif: ${activeStep.title}';
    }

    return '${_progressSteps.length} langkah • Semua step selesai';
  }

  @override
  void dispose() {
    _approvalNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleApprovePressed() async {
    if (_currentStepRequiresSignature) {
      final signed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        enableDrag: false,
        builder: (context) {
          return _SignatureApprovalSheet(
            title: _currentActionTitle,
            onUseSignature: () => Navigator.of(context).pop(true),
          );
        },
      );

      if (signed != true || !mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tanda tangan digital sudah ditambahkan. Approval siap dihubungkan ke workflow backend.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'UI approve action siap dihubungkan ke workflow backend.',
        ),
      ),
    );
  }

  void _handleRejectPressed() {
    if (_approvalNoteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi alasan atau catatan penolakan terlebih dahulu.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UI reject action siap dihubungkan ke workflow backend.'),
      ),
    );
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
                                    label: widget.task.statusLabel,
                                    color: widget.task.accentColor,
                                  ),
                                  StatusChip(
                                    label: widget.task.priorityLabel,
                                    color: AppColors.amber,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                widget.task.timeLabel,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.task.title,
                          style: textTheme.headlineMedium?.copyWith(
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetaTile(
                              label: 'Requester',
                              value: widget.task.requester,
                            ),
                            _MetaTile(
                              label: 'Workflow',
                              value: DemoData.forms.first.workflow,
                            ),
                            _MetaTile(
                              label: 'Current Step',
                              value: _currentActionTitle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Details', style: textTheme.titleLarge),
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
                Text('Attachment', style: textTheme.titleLarge),
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
                                'PDF document',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Preview PDF siap dihubungkan ke viewer backend.',
                                ),
                              ),
                            );
                          },
                          child: const Text('Preview'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Action', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                RevealUp(
                  index: 4,
                  child: BrandSurface(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Action Required',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.goldDeep,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(_currentActionTitle, style: textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          _currentStepRequiresSignature
                              ? 'Langkah ini membutuhkan tanda tangan digital sebelum approval selesai.'
                              : 'Langkah ini bisa diproses langsung tanpa tanda tangan tambahan.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        if (_currentStepRequiresSignature)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: StatusChip(
                              label: 'Signature Required',
                              color: AppColors.red,
                            ),
                          ),
                        Text('Approval note', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _approvalNoteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Tambahkan catatan jika diperlukan',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _handleRejectPressed,
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _handleApprovePressed,
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Progress', style: textTheme.titleLarge),
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
                                    'Workflow Progress',
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
    final connectorColor = step.statusLabel == 'Queued'
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
                      'Step $index',
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
  final VoidCallback onUseSignature;

  @override
  State<_SignatureApprovalSheet> createState() =>
      _SignatureApprovalSheetState();
}

class _SignatureApprovalSheetState extends State<_SignatureApprovalSheet> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  String? _errorText;
  double _headerDragOffset = 0;

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

  void _submit() {
    if (!_hasSignature) {
      setState(() {
        _errorText = 'Tanda tangan belum digambar.';
      });
      return;
    }

    widget.onUseSignature();
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
                  child: Container(
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
