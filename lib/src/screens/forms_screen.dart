import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class FormsScreen extends StatefulWidget {
  const FormsScreen({super.key});

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categories = <String>{
      'Semua',
      ...DemoData.forms.map((form) => form.category),
    };
    final query = _searchController.text.trim().toLowerCase();
    final filteredForms = DemoData.forms.where((form) {
      final matchesCategory =
          _selectedCategory == 'Semua' || form.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          form.title.toLowerCase().contains(query) ||
          form.workflow.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomBarInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealUp(child: Text('Forms', style: textTheme.headlineMedium)),
          const SizedBox(height: 14),
          AppSearchField(
            controller: _searchController,
            hintText: 'Cari form atau workflow',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (final category in categories) ...[
                  FilterPill(
                    label: category,
                    selected: _selectedCategory == category,
                    onTap: () => setState(() => _selectedCategory = category),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (filteredForms.isEmpty)
            BrandSurface(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Belum ada form yang cocok dengan pencarian atau kategori ini.',
                style: textTheme.bodyMedium,
              ),
            )
          else
            for (var index = 0; index < filteredForms.length; index++) ...[
              RevealUp(
                index: index + 1,
                child: _FormListCard(
                  form: filteredForms[index],
                  onTap: () => _showFormPreview(filteredForms[index]),
                ),
              ),
              if (index != filteredForms.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  void _showFormPreview(FormTemplate form) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;

        return FractionallySizedBox(
          heightFactor: 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: BrandSurface(
              radius: 32,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusChip(
                                label: form.category,
                                color: form.accentColor,
                              ),
                              const SizedBox(height: 10),
                              Text(form.title, style: textTheme.titleLarge),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      children: [
                        Text('Fields', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        ...form.fields.map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(field, style: textTheme.bodyMedium),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Flow', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        for (
                          var index = 0;
                          index < form.approvalSteps.length;
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: form.accentColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: form.accentColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    form.approvalSteps[index],
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FormListCard extends StatelessWidget {
  const _FormListCard({required this.form, required this.onTap});

  final FormTemplate form;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: form.category, color: form.accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  form.etaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.goldDeep,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(form.title, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            form.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            form.workflow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${form.fields.length} fields',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.borderStrong,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  form.tags.take(2).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
