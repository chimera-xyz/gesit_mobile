import 'package:flutter/material.dart';

import '../data/workspace_data_controller.dart';
import '../models/app_models.dart';
import '../screens/form_submission_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class FormsScreen extends StatefulWidget {
  const FormsScreen({super.key, required this.controller});

  final WorkspaceDataController controller;

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.controller.formsLoaded && !widget.controller.formsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.refreshForms();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final forms = widget.controller.forms;
        final query = _searchController.text.trim().toLowerCase();
        final filteredForms = forms
            .where((form) => _matchesSearch(form, query))
            .toList(growable: false);
        final groupedForms = _groupForms(filteredForms);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, kBottomBarInset + 152),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RevealUp(
                child: _FormsHeader(
                  shownCount: filteredForms.length,
                  totalCount: forms.length,
                  loading: widget.controller.formsLoading,
                ),
              ),
              const SizedBox(height: 18),
              RevealUp(
                index: 1,
                child: _FormsSearchField(
                  controller: _searchController,
                  hasQuery: query.isNotEmpty,
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              if (widget.controller.formsError != null) ...[
                const SizedBox(height: 16),
                _InlineNotice(
                  message: widget.controller.usingFallbackForms
                      ? 'Server forms belum siap. Menampilkan data cadangan.'
                      : widget.controller.formsError!,
                ),
              ],
              const SizedBox(height: 20),
              if (widget.controller.formsLoading && forms.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else if (filteredForms.isEmpty)
                _EmptyFormsState(hasQuery: query.isNotEmpty)
              else
                for (var index = 0; index < groupedForms.length; index++) ...[
                  RevealUp(
                    key: ValueKey('form-group-${groupedForms[index].category}'),
                    index: index + 2,
                    child: _FormGroupSection(
                      group: groupedForms[index],
                      onOpenForm: _openForm,
                    ),
                  ),
                  if (index != groupedForms.length - 1)
                    const SizedBox(height: 18),
                ],
            ],
          ),
        );
      },
    );
  }

  bool _matchesSearch(FormTemplate form, String query) {
    return query.isEmpty ||
        form.title.toLowerCase().contains(query) ||
        form.workflow.toLowerCase().contains(query) ||
        form.description.toLowerCase().contains(query) ||
        form.tags.any((tag) => tag.toLowerCase().contains(query));
  }

  void _openForm(FormTemplate form) {
    pushBrandedRoute(
      context,
      FormSubmissionScreen(form: form, controller: widget.controller),
    );
  }
}

class _FormsHeader extends StatelessWidget {
  const _FormsHeader({
    required this.shownCount,
    required this.totalCount,
    required this.loading,
  });

  final int shownCount;
  final int totalCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countLabel = shownCount == totalCount
        ? '$totalCount template tersedia'
        : '$shownCount dari $totalCount template';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forms',
                style: textTheme.displayMedium?.copyWith(
                  fontSize: 34,
                  height: 1.02,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                countLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: _FormsColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.3),
            ),
          ),
      ],
    );
  }
}

class _FormsSearchField extends StatelessWidget {
  const _FormsSearchField({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: textTheme.bodyMedium?.copyWith(
          color: _FormsColors.ink,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Cari form',
          hintStyle: textTheme.bodyMedium?.copyWith(
            color: _FormsColors.soft,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _FormsColors.soft,
            size: 22,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _FormsColors.soft,
                    size: 20,
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: _FormsColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _FormsColors.ink, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.goldSoft.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.goldDeep,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: _FormsColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFormsState extends StatelessWidget {
  const _EmptyFormsState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final message = hasQuery
        ? 'Coba kata kunci lain.'
        : 'Form akan muncul setelah data dari server tersedia.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _FormsColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: _FormsColors.soft,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text('Form tidak ditemukan', style: textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: _FormsColors.muted),
          ),
        ],
      ),
    );
  }
}

class _FormGroupSection extends StatefulWidget {
  const _FormGroupSection({required this.group, required this.onOpenForm});

  final _FormGroup group;
  final ValueChanged<FormTemplate> onOpenForm;

  @override
  State<_FormGroupSection> createState() => _FormGroupSectionState();
}

class _FormGroupSectionState extends State<_FormGroupSection> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final group = widget.group;

    return Container(
      decoration: BoxDecoration(
        color: _FormsColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F111111),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: '${_expanded ? 'Tutup' : 'Buka'} kategori ${group.category}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _toggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: _FormsColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${group.forms.length} form',
                        style: textTheme.bodySmall?.copyWith(
                          color: _FormsColors.soft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _FormsColors.soft,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: _FormsColors.line,
                ),
                for (var index = 0; index < group.forms.length; index++) ...[
                  _FormDirectoryTile(
                    form: group.forms[index],
                    onTap: () => widget.onOpenForm(group.forms[index]),
                  ),
                  if (index != group.forms.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 72,
                      endIndent: 16,
                      color: _FormsColors.line,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormDirectoryTile extends StatelessWidget {
  const _FormDirectoryTile({required this.form, required this.onTap});

  final FormTemplate form;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondaryText =
        form.descriptionVerified && form.description.isNotEmpty
        ? form.description
        : form.workflow;
    final detailText = _detailText(form);

    return Semantics(
      button: true,
      label: 'Buka form ${form.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                _FormIconBubble(form: form),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.16,
                          color: _FormsColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: _FormsColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: _FormsColors.soft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _FormsColors.soft,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormIconBubble extends StatelessWidget {
  const _FormIconBubble({required this.form});

  final FormTemplate form;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: form.accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(_iconForForm(form), color: form.accentColor, size: 22),
    );
  }
}

class _FormGroup {
  const _FormGroup({required this.category, required this.forms});

  final String category;
  final List<FormTemplate> forms;
}

class _FormsColors {
  const _FormsColors._();

  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF151412);
  static const Color muted = Color(0xFF68635B);
  static const Color soft = Color(0xFF948E84);
  static const Color line = Color(0xFFE7E3DD);
}

List<_FormGroup> _groupForms(List<FormTemplate> forms) {
  final grouped = <String, List<FormTemplate>>{};

  for (final form in forms) {
    grouped.putIfAbsent(form.category, () => <FormTemplate>[]).add(form);
  }

  final categories = grouped.keys.toList(growable: false)..sort();

  return [
    for (final category in categories)
      _FormGroup(category: category, forms: grouped[category]!),
  ];
}

IconData _iconForForm(FormTemplate form) {
  final text = '${form.category} ${form.title} ${form.workflow}'.toLowerCase();

  if (text.contains('akses') ||
      text.contains('access') ||
      text.contains('security')) {
    return Icons.admin_panel_settings_rounded;
  }
  if (text.contains('travel') ||
      text.contains('perjalanan') ||
      text.contains('dinas')) {
    return Icons.flight_takeoff_rounded;
  }
  if (text.contains('vendor') || text.contains('legal')) {
    return Icons.business_center_rounded;
  }
  if (text.contains('reimbursement') || text.contains('berobat')) {
    return Icons.medical_services_rounded;
  }
  if (text.contains('marketing') || text.contains('campaign')) {
    return Icons.campaign_rounded;
  }
  if (text.contains('pengadaan') ||
      text.contains('procurement') ||
      text.contains('hardware') ||
      text.contains('software')) {
    return Icons.inventory_2_rounded;
  }
  if (text.contains('finance') ||
      text.contains('budget') ||
      text.contains('payment')) {
    return Icons.payments_rounded;
  }

  return Icons.description_rounded;
}

String _detailText(FormTemplate form) {
  final fieldLabel = '${form.fields.length} isian';

  if (form.submissionCount > 0) {
    return '$fieldLabel • ${form.etaLabel} • ${form.submissionCount} pengajuan';
  }

  return '$fieldLabel • ${form.etaLabel}';
}
