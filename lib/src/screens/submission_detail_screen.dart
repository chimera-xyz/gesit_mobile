import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class SubmissionDetailScreen extends StatelessWidget {
  const SubmissionDetailScreen({super.key, required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detailFields = DemoData.submissionFields
        .where((field) => field.label != 'Attachment')
        .toList();
    final attachment = DemoData.submissionFields.firstWhere(
      (field) => field.label == 'Attachment',
      orElse: () => const SubmissionField(
        label: 'Attachment',
        value: 'requisition-preview.pdf',
      ),
    );

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
                                    label: task.statusLabel,
                                    color: task.accentColor,
                                  ),
                                  StatusChip(
                                    label: task.priorityLabel,
                                    color: AppColors.amber,
                                  ),
                                  if (task.requiresSignature)
                                    const StatusChip(
                                      label: 'Sign',
                                      color: AppColors.red,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                task.timeLabel,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          task.title,
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
                              value: task.requester,
                            ),
                            _MetaTile(label: 'Target', value: task.timeLabel),
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
                          index < detailFields.length;
                          index++
                        ) ...[
                          _FieldRow(field: detailFields[index]),
                          if (index != detailFields.length - 1)
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
                                attachment.value,
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
                        Text('Approval note', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        const TextField(
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Tambahkan catatan jika diperlukan',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'UI reject action siap dihubungkan ke workflow backend.',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'UI approve action siap dihubungkan ke workflow backend.',
                                      ),
                                    ),
                                  );
                                },
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < DemoData.submissionTimeline.length;
                          index++
                        ) ...[
                          _TimelineRow(
                            step: DemoData.submissionTimeline[index],
                          ),
                          if (index != DemoData.submissionTimeline.length - 1)
                            const Divider(height: 1),
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
  const _TimelineRow({required this.step});

  final SubmissionTimelineStep step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: step.accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: step.accentColor, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 6),
                Text(
                  step.timeLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
