import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/demo_data.dart';
import '../data/gesit_api_client.dart';
import '../data/workspace_data_controller.dart';
import '../models/app_models.dart';
import '../screens/submission_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_session_scope.dart';
import '../widgets/brand_widgets.dart';

class FormSubmissionScreen extends StatefulWidget {
  const FormSubmissionScreen({
    super.key,
    required this.form,
    required this.controller,
  });

  final FormTemplate form;
  final WorkspaceDataController controller;

  @override
  State<FormSubmissionScreen> createState() => _FormSubmissionScreenState();
}

class _FormSubmissionScreenState extends State<FormSubmissionScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selectedOptions = {};
  final Map<String, Set<String>> _selectedMultiOptions = {};
  final Map<String, PlatformFile> _selectedFiles = {};
  bool _showApprovalDetails = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    for (final field in widget.form.fields) {
      switch (field.type) {
        case FormFieldType.select:
        case FormFieldType.radio:
          _selectedOptions[field.id] = field.initialValue;
          break;
        case FormFieldType.checkbox:
          _selectedMultiOptions[field.id] = <String>{
            if (field.initialValue != null &&
                field.initialValue!.trim().isNotEmpty)
              ...field.initialValue!
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty),
          };
          break;
        case FormFieldType.text:
        case FormFieldType.multiline:
        case FormFieldType.date:
        case FormFieldType.file:
        case FormFieldType.number:
        case FormFieldType.email:
          _controllers[field.id] = TextEditingController(
            text: field.initialValue ?? '',
          );
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = AppSessionScope.watch(context).session;
    final requesterName = session?.user.name ?? DemoData.userName;
    final divisionLabel = session?.user.divisionLabel ?? DemoData.userDivision;
    final hasVerifiedDescription =
        widget.form.descriptionVerified &&
        widget.form.description.trim().isNotEmpty;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                keyboardVisible ? 32 : 148,
              ),
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
                              alpha: 0.94,
                            ),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Isi Form',
                            style: textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  RevealUp(
                    index: 1,
                    child: SizedBox(
                      width: double.infinity,
                      child: BrandSurface(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                StatusChip(
                                  label: widget.form.category,
                                  color: widget.form.accentColor,
                                ),
                                StatusChip(
                                  label: widget.form.etaLabel,
                                  color: AppColors.ink,
                                  icon: Icons.schedule_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              widget.form.title,
                              style: textTheme.headlineMedium?.copyWith(
                                fontSize: 28,
                              ),
                            ),
                            if (hasVerifiedDescription) ...[
                              const SizedBox(height: 10),
                              Text(
                                widget.form.description,
                                style: textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _MetaPill(
                                  icon: Icons.account_circle_rounded,
                                  label: requesterName,
                                ),
                                _MetaPill(
                                  icon: Icons.apartment_rounded,
                                  label: divisionLabel,
                                ),
                                _MetaPill(
                                  icon: Icons.account_tree_rounded,
                                  label: widget.form.workflow,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RevealUp(
                    index: 2,
                    child: SizedBox(
                      width: double.infinity,
                      child: BrandSurface(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Alur Approval',
                                        style: textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${widget.form.approvalSteps.length} langkah',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(
                                    () => _showApprovalDetails =
                                        !_showApprovalDetails,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.surfaceAlt,
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  icon: Icon(
                                    _showApprovalDetails
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                            if (_showApprovalDetails) ...[
                              const SizedBox(height: 16),
                              for (
                                var index = 0;
                                index < widget.form.approvalSteps.length;
                                index++
                              ) ...[
                                _ApprovalStepRow(
                                  index: index + 1,
                                  label: widget.form.approvalSteps[index],
                                  accentColor: widget.form.accentColor,
                                  isLast:
                                      index ==
                                      widget.form.approvalSteps.length - 1,
                                ),
                                if (index !=
                                    widget.form.approvalSteps.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RevealUp(
                    index: 3,
                    child: SizedBox(
                      width: double.infinity,
                      child: BrandSurface(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Field Form', style: textTheme.titleMedium),
                            const SizedBox(height: 16),
                            for (final field in widget.form.fields) ...[
                              _FormFieldBlock(
                                field: field,
                                child: _buildField(context, field),
                              ),
                              const SizedBox(height: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: keyboardVisible
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.98),
                  border: const Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12291C09),
                      blurRadius: 18,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(
                          _submitting ? 'Mengirim...' : 'Kirim Pengajuan',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(BuildContext context, FormFieldConfig field) {
    switch (field.type) {
      case FormFieldType.text:
      case FormFieldType.email:
      case FormFieldType.number:
        return TextField(
          controller: _controllers[field.id],
          keyboardType: _keyboardType(field.type),
          textInputAction: TextInputAction.next,
          textCapitalization: field.type == FormFieldType.email
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          readOnly: field.readOnly,
          decoration: InputDecoration(hintText: field.placeholder),
        );
      case FormFieldType.multiline:
        return TextField(
          controller: _controllers[field.id],
          maxLines: 5,
          minLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
          readOnly: field.readOnly,
          decoration: InputDecoration(
            hintText: field.placeholder,
            alignLabelWithHint: true,
          ),
        );
      case FormFieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: _selectedOptions[field.id],
          isExpanded: true,
          decoration: InputDecoration(
            hintText: field.placeholder ?? 'Pilih salah satu',
          ),
          items: field.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: field.readOnly
              ? null
              : (value) => setState(() => _selectedOptions[field.id] = value),
        );
      case FormFieldType.radio:
        return Column(
          children: [
            for (final option in field.options) ...[
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: field.readOnly
                    ? null
                    : () => setState(() => _selectedOptions[field.id] = option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _selectedOptions[field.id] == option
                          ? AppColors.goldDeep
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedOptions[field.id] == option
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: _selectedOptions[field.id] == option
                            ? AppColors.goldDeep
                            : AppColors.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(option)),
                    ],
                  ),
                ),
              ),
              if (option != field.options.last) const SizedBox(height: 10),
            ],
          ],
        );
      case FormFieldType.checkbox:
        final selectedValues = _selectedMultiOptions[field.id] ?? <String>{};
        return Column(
          children: [
            for (final option in field.options) ...[
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: selectedValues.contains(option),
                contentPadding: EdgeInsets.zero,
                title: Text(option),
                onChanged: field.readOnly
                    ? null
                    : (checked) => setState(() {
                        final nextValues = Set<String>.from(selectedValues);
                        if (checked == true) {
                          nextValues.add(option);
                        } else {
                          nextValues.remove(option);
                        }
                        _selectedMultiOptions[field.id] = nextValues;
                      }),
              ),
            ],
          ],
        );
      case FormFieldType.date:
        return TextField(
          controller: _controllers[field.id],
          readOnly: true,
          onTap: field.readOnly ? null : () => _pickDate(field),
          decoration: InputDecoration(
            hintText: field.placeholder ?? 'Pilih tanggal',
            suffixIcon: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.inkMuted,
            ),
          ),
        );
      case FormFieldType.file:
        return TextField(
          controller: _controllers[field.id],
          readOnly: true,
          onTap: field.readOnly ? null : () => _pickAttachment(field),
          decoration: InputDecoration(
            hintText: field.placeholder ?? 'Pilih file',
            suffixIcon: IconButton(
              onPressed: field.readOnly ? null : () => _pickAttachment(field),
              icon: const Icon(
                Icons.attach_file_rounded,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        );
    }
  }

  TextInputType _keyboardType(FormFieldType type) {
    switch (type) {
      case FormFieldType.email:
        return TextInputType.emailAddress;
      case FormFieldType.number:
        return TextInputType.number;
      case FormFieldType.text:
      case FormFieldType.multiline:
      case FormFieldType.select:
      case FormFieldType.radio:
      case FormFieldType.checkbox:
      case FormFieldType.date:
      case FormFieldType.file:
        return TextInputType.text;
    }
  }

  Future<void> _pickDate(FormFieldConfig field) async {
    final parsed = _tryParseDate(_controllers[field.id]?.text);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.goldDeep,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.ink,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
            ),
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: AppColors.surface,
              headerForegroundColor: AppColors.ink,
              dividerColor: AppColors.border,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    _controllers[field.id]?.text = DateFormat(
      'd MMMM yyyy',
      'id_ID',
    ).format(picked);
    setState(() {});
  }

  Future<void> _pickAttachment(FormFieldConfig field) async {
    final selectedFile = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (!mounted || selectedFile == null || selectedFile.files.isEmpty) {
      return;
    }

    final file = selectedFile.files.single;
    _selectedFiles[field.id] = file;
    _controllers[field.id]?.text = file.name;
    setState(() {});
  }

  DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      return DateFormat('d MMMM yyyy', 'id_ID').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  dynamic _submissionFieldValue(FormFieldConfig field) {
    switch (field.type) {
      case FormFieldType.select:
      case FormFieldType.radio:
        return _selectedOptions[field.id]?.trim() ?? '';
      case FormFieldType.checkbox:
        return (_selectedMultiOptions[field.id] ?? <String>{})
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false);
      case FormFieldType.file:
        return _selectedFiles[field.id];
      case FormFieldType.date:
        final rawValue = _controllers[field.id]?.text.trim() ?? '';
        final parsed = _tryParseDate(rawValue);
        return parsed == null
            ? rawValue
            : DateFormat('yyyy-MM-dd').format(parsed);
      case FormFieldType.text:
      case FormFieldType.multiline:
      case FormFieldType.number:
      case FormFieldType.email:
        return _controllers[field.id]?.text.trim() ?? '';
    }
  }

  Future<void> _submit() async {
    final missingFields = <String>[];
    final formData = <String, dynamic>{};
    final files = <String, ApiMultipartFilePayload>{};

    for (final field in widget.form.fields) {
      final value = _submissionFieldValue(field);

      if (field.required &&
          ((value is String && value.isEmpty) ||
              (value is List && value.isEmpty) ||
              (value == null))) {
        missingFields.add(field.label);
        continue;
      }

      switch (field.type) {
        case FormFieldType.file:
          final file = value is PlatformFile ? value : null;
          if (file == null) {
            continue;
          }
          files[field.id] = ApiMultipartFilePayload(
            fileName: file.name,
            path: file.path,
            bytes: file.bytes,
          );
          break;
        case FormFieldType.checkbox:
          if (value is List<String> && value.isNotEmpty) {
            formData[field.id] = value;
          }
          break;
        case FormFieldType.select:
        case FormFieldType.radio:
        case FormFieldType.text:
        case FormFieldType.multiline:
        case FormFieldType.date:
        case FormFieldType.number:
        case FormFieldType.email:
          if (value is String && value.isNotEmpty) {
            formData[field.id] = value;
          }
          break;
      }
    }

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lengkapi field wajib: ${missingFields.take(2).join(', ')}${missingFields.length > 2 ? ' dan lainnya' : ''}.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final createdTask = await widget.controller.submitForm(
        form: widget.form,
        formData: formData,
        files: files,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan berhasil dikirim ke server.')),
      );

      await Navigator.of(context).pushReplacement<void, void>(
        BrandedPageRoute(
          builder: (_) => SubmissionDetailScreen(
            task: createdTask,
            controller: widget.controller,
          ),
        ),
      );
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
        const SnackBar(
          content: Text('Pengajuan belum berhasil dikirim. Coba lagi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.goldDeep),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalStepRow extends StatelessWidget {
  const _ApprovalStepRow({
    required this.index,
    required this.label,
    required this.accentColor,
    required this.isLast,
  });

  final int index;
  final String label;
  final Color accentColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: textTheme.bodySmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 28,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormFieldBlock extends StatelessWidget {
  const _FormFieldBlock({required this.field, required this.child});

  final FormFieldConfig field;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: field.label,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
            children: [
              if (field.required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
        if (field.helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            field.helperText!,
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ],
    );
  }
}
