import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../screens/form_submission_screen.dart';
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
          form.workflow.toLowerCase().contains(query) ||
          form.description.toLowerCase().contains(query) ||
          form.tags.any((tag) => tag.toLowerCase().contains(query));
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
                  onTap: () => pushBrandedRoute(
                    context,
                    FormSubmissionScreen(form: filteredForms[index]),
                  ),
                ),
              ),
              if (index != filteredForms.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
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
    final hasVerifiedDescription =
        form.descriptionVerified && form.description.trim().isNotEmpty;

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
          if (hasVerifiedDescription) ...[
            const SizedBox(height: 8),
            Text(
              form.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
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
