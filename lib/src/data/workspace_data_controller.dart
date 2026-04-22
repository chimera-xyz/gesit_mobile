import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/session_models.dart';
import '../theme/app_theme.dart';
import 'app_session_controller.dart';
import 'demo_data.dart';
import 'gesit_api_client.dart';

class WorkspaceDataController extends ChangeNotifier {
  WorkspaceDataController({
    required AppSessionController sessionController,
    GesitApiClient? apiClient,
  }) : _sessionController = sessionController,
       _apiClient = apiClient ?? GesitApiClient();

  final AppSessionController _sessionController;
  final GesitApiClient _apiClient;

  List<FormTemplate> _forms = List<FormTemplate>.unmodifiable(DemoData.forms);
  List<TaskItem> _tasks = List<TaskItem>.unmodifiable(DemoData.tasks);
  bool _formsLoading = false;
  bool _tasksLoading = false;
  bool _formsLoaded = false;
  bool _tasksLoaded = false;
  bool _usingFallbackForms = true;
  bool _usingFallbackTasks = true;
  String? _formsError;
  String? _tasksError;

  List<FormTemplate> get forms => _forms;
  List<TaskItem> get tasks => _tasks;
  bool get formsLoading => _formsLoading;
  bool get tasksLoading => _tasksLoading;
  bool get formsLoaded => _formsLoaded;
  bool get tasksLoaded => _tasksLoaded;
  bool get usingFallbackForms => _usingFallbackForms;
  bool get usingFallbackTasks => _usingFallbackTasks;
  String? get formsError => _formsError;
  String? get tasksError => _tasksError;

  int get activeFormCount => _forms.where((form) => form.isActive).length;

  int get pendingActionCount =>
      _tasks.where((task) => task.lane == TaskLane.actionable).length;

  TaskItem? taskById(String submissionId) {
    for (final task in _tasks) {
      if (task.id == submissionId) {
        return task;
      }
    }

    return null;
  }

  Future<void> ensureLoaded() async {
    await Future.wait([
      if (!_formsLoaded) refreshForms(),
      if (!_tasksLoaded) refreshTasks(),
    ]);
  }

  Future<void> refreshForms() async {
    final session = _sessionController.session;
    if (session == null) {
      return;
    }

    if (!session.user.canAccessForms) {
      _forms = const <FormTemplate>[];
      _formsLoaded = true;
      _usingFallbackForms = false;
      _formsError = null;
      notifyListeners();
      return;
    }

    _formsLoading = true;
    notifyListeners();

    try {
      final payload = await _apiClient.fetchForms(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      await _sessionController.syncCookies(payload.cookies);

      final rawForms = _asList(payload.data['forms']);
      _forms = List<FormTemplate>.unmodifiable(
        rawForms
            .map((rawForm) => _adaptForm(rawForm, session.user))
            .toList(growable: false),
      );
      _usingFallbackForms = false;
      _formsError = null;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        _formsError = 'Sesi login berakhir. Silakan masuk lagi.';
        _forms = const <FormTemplate>[];
        _usingFallbackForms = false;
        await _sessionController.invalidateSession(errorMessage: _formsError);
        return;
      }
      _formsError = error.message;
      _forms = List<FormTemplate>.unmodifiable(DemoData.forms);
      _usingFallbackForms = true;
    } on TimeoutException {
      _formsError = 'Server forms terlalu lama merespons.';
      _forms = List<FormTemplate>.unmodifiable(DemoData.forms);
      _usingFallbackForms = true;
    } catch (_) {
      _formsError = 'Forms belum bisa dimuat dari server.';
      _forms = List<FormTemplate>.unmodifiable(DemoData.forms);
      _usingFallbackForms = true;
    } finally {
      _formsLoading = false;
      _formsLoaded = true;
      notifyListeners();
    }
  }

  Future<void> refreshTasks({
    String? search,
    String? status,
    String? formId,
  }) async {
    final session = _sessionController.session;
    if (session == null) {
      return;
    }

    if (!session.user.canAccessTasks) {
      _tasks = const <TaskItem>[];
      _tasksLoaded = true;
      _usingFallbackTasks = false;
      _tasksError = null;
      notifyListeners();
      return;
    }

    _tasksLoading = true;
    notifyListeners();

    try {
      final payload = await _apiClient.fetchSubmissions(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (status != null && status.trim().isNotEmpty)
            'status': status.trim(),
          if (formId != null && formId.trim().isNotEmpty)
            'form_id': formId.trim(),
        },
      );
      await _sessionController.syncCookies(payload.cookies);

      final rawSubmissions = _asList(payload.data['submissions']);
      final tasks = rawSubmissions
          .map((rawSubmission) => _adaptSubmission(rawSubmission, session))
          .toList(growable: false);
      tasks.sort(_sortTasks);
      _tasks = List<TaskItem>.unmodifiable(tasks);
      _usingFallbackTasks = false;
      _tasksError = null;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        _tasksError = 'Sesi login berakhir. Silakan masuk lagi.';
        _tasks = const <TaskItem>[];
        _usingFallbackTasks = false;
        await _sessionController.invalidateSession(errorMessage: _tasksError);
        return;
      }
      _tasksError = error.message;
      _tasks = List<TaskItem>.unmodifiable(DemoData.tasks);
      _usingFallbackTasks = true;
    } on TimeoutException {
      _tasksError = 'Server tasks terlalu lama merespons.';
      _tasks = List<TaskItem>.unmodifiable(DemoData.tasks);
      _usingFallbackTasks = true;
    } catch (_) {
      _tasksError = 'Tasks belum bisa dimuat dari server.';
      _tasks = List<TaskItem>.unmodifiable(DemoData.tasks);
      _usingFallbackTasks = true;
    } finally {
      _tasksLoading = false;
      _tasksLoaded = true;
      notifyListeners();
    }
  }

  Future<TaskItem> fetchTaskDetail(TaskItem task) async {
    if (task.id == null || task.id!.trim().isEmpty) {
      return task;
    }

    final session = _requireSession();
    final payload = await _apiClient.fetchSubmissionDetail(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      submissionId: task.id!,
    );
    await _sessionController.syncCookies(payload.cookies);

    final submission = _asMap(payload.data['submission']);
    if (submission.isEmpty) {
      throw const GesitApiException('Detail submission tidak valid.');
    }

    final updatedTask = _adaptSubmission(submission, session);
    _replaceOrInsertTask(updatedTask);
    notifyListeners();
    return updatedTask;
  }

  Future<TaskItem> findOrFetchTaskById(String submissionId) async {
    final existingTask = taskById(submissionId);
    if (existingTask != null) {
      return fetchTaskDetail(existingTask);
    }

    final session = _requireSession();
    final payload = await _apiClient.fetchSubmissionDetail(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      submissionId: submissionId,
    );
    await _sessionController.syncCookies(payload.cookies);

    final submission = _asMap(payload.data['submission']);
    if (submission.isEmpty) {
      throw const GesitApiException('Detail submission tidak valid.');
    }

    final updatedTask = _adaptSubmission(submission, session);
    _replaceOrInsertTask(updatedTask);
    notifyListeners();
    return updatedTask;
  }

  Future<TaskItem> submitForm({
    required FormTemplate form,
    required Map<String, dynamic> formData,
    Map<String, ApiMultipartFilePayload> files = const {},
  }) async {
    final session = _requireSession();
    final formId = form.id;

    if (formId == null || formId.trim().isEmpty) {
      throw const GesitApiException(
        'Form ini masih mode demo dan belum punya ID backend.',
      );
    }

    final payload = await _apiClient.createSubmission(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      formId: formId,
      formData: formData,
      files: files,
    );
    await _sessionController.syncCookies(payload.cookies);

    final submission = _asMap(payload.data['submission']);
    if (submission.isEmpty) {
      throw const GesitApiException('Respons submit form tidak valid.');
    }

    final createdTask = _adaptSubmission(submission, session);
    _replaceOrInsertTask(createdTask);
    await refreshTasks();
    return createdTask;
  }

  Future<TaskItem> approveTask({
    required TaskItem task,
    required String notes,
    String? signatureDataUrl,
  }) async {
    final session = _requireSession();
    var latestCookies = session.cookies;
    String? signatureId;

    if (signatureDataUrl != null && signatureDataUrl.trim().isNotEmpty) {
      final approvalStepId = task.currentApprovalStepId;
      if (approvalStepId == null) {
        throw const GesitApiException(
          'Approval step aktif tidak ditemukan untuk signature.',
        );
      }

      final signaturePayload = await _apiClient.drawSignature(
        baseUrl: session.apiBaseUrl,
        cookies: latestCookies,
        approvalStepId: approvalStepId,
        signatureDataUrl: signatureDataUrl,
      );
      latestCookies = signaturePayload.cookies;
      await _sessionController.syncCookies(latestCookies);
      final signature = _asMap(signaturePayload.data['signature']);
      signatureId = _stringValue(signature['id']);
    }

    if (task.id == null || task.id!.trim().isEmpty) {
      throw const GesitApiException('Submission ini belum punya ID backend.');
    }

    final approvalPayload = await _apiClient.approveSubmission(
      baseUrl: session.apiBaseUrl,
      cookies: latestCookies,
      submissionId: task.id!,
      notes: notes.trim().isEmpty ? null : notes.trim(),
      signatureId: signatureId,
    );
    await _sessionController.syncCookies(approvalPayload.cookies);

    final submission = _asMap(approvalPayload.data['submission']);
    if (submission.isEmpty) {
      throw const GesitApiException('Respons approval tidak valid.');
    }

    final updatedTask = _adaptSubmission(submission, session);
    _replaceOrInsertTask(updatedTask);
    await refreshTasks();
    return updatedTask;
  }

  Future<TaskItem> rejectTask({
    required TaskItem task,
    required String reason,
  }) async {
    if (task.id == null || task.id!.trim().isEmpty) {
      throw const GesitApiException('Submission ini belum punya ID backend.');
    }

    final session = _requireSession();
    final payload = await _apiClient.rejectSubmission(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      submissionId: task.id!,
      rejectionReason: reason.trim(),
    );
    await _sessionController.syncCookies(payload.cookies);

    final submission = _asMap(payload.data['submission']);
    if (submission.isEmpty) {
      throw const GesitApiException('Respons penolakan tidak valid.');
    }

    final updatedTask = _adaptSubmission(submission, session);
    _replaceOrInsertTask(updatedTask);
    await refreshTasks();
    return updatedTask;
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  AppSession _requireSession() {
    final session = _sessionController.session;
    if (session == null) {
      throw const GesitApiException('Session login tidak tersedia.');
    }

    return session;
  }

  void _replaceOrInsertTask(TaskItem nextTask) {
    final nextTasks = _tasks.toList(growable: true);
    final currentIndex = nextTasks.indexWhere((task) => task.id == nextTask.id);

    if (currentIndex >= 0) {
      nextTasks[currentIndex] = nextTask;
    } else {
      nextTasks.insert(0, nextTask);
    }

    nextTasks.sort(_sortTasks);
    _tasks = List<TaskItem>.unmodifiable(nextTasks);
  }

  int _sortTasks(TaskItem left, TaskItem right) {
    final leftCreatedAt = left.createdAt;
    final rightCreatedAt = right.createdAt;

    if (leftCreatedAt == null && rightCreatedAt == null) {
      return 0;
    }
    if (leftCreatedAt == null) {
      return 1;
    }
    if (rightCreatedAt == null) {
      return -1;
    }

    return rightCreatedAt.compareTo(leftCreatedAt);
  }

  FormTemplate _adaptForm(
    Map<String, dynamic> rawForm,
    AuthenticatedUser user,
  ) {
    final formConfig = _asMap(rawForm['form_config']);
    final workflow = _asMap(rawForm['workflow']);
    final workflowConfig = _asMap(workflow['workflow_config']);
    final fieldConfigs = _asList(formConfig['fields'])
        .map((rawField) => _adaptFormField(rawField, user))
        .toList(growable: false);
    final approvalSteps = _workflowHumanSteps(workflowConfig);
    final workflowLabel = _stringValue(workflow['name']) ?? 'Workflow Internal';
    final description = (_stringValue(rawForm['description']) ?? '').trim();
    final accentColor = _formAccentColor(
      title: _stringValue(rawForm['name']) ?? '',
      workflow: workflowLabel,
    );

    return FormTemplate(
      id: _stringValue(rawForm['id']),
      slug: _stringValue(rawForm['slug']),
      title: _stringValue(rawForm['name']) ?? 'Internal Form',
      description: description,
      category: _formCategory(
        title: _stringValue(rawForm['name']) ?? '',
        workflow: workflowLabel,
      ),
      workflow: workflowLabel,
      etaLabel: approvalSteps.isEmpty
          ? 'Form internal'
          : '${approvalSteps.length} tahap approval',
      fields: fieldConfigs,
      approvalSteps: approvalSteps,
      accentColor: accentColor,
      tags: fieldConfigs
          .map((field) => field.label)
          .where((label) => label.trim().isNotEmpty)
          .take(3)
          .toList(growable: false),
      isActive: rawForm['is_active'] != false,
      submissionCount: _intValue(rawForm['submissions_count']) ?? 0,
      descriptionVerified: description.isNotEmpty,
    );
  }

  FormFieldConfig _adaptFormField(
    Map<String, dynamic> rawField,
    AuthenticatedUser user,
  ) {
    final fieldType = _mapFieldType(_stringValue(rawField['type']));
    final initialValue = _resolveAutoFillValue(
      _stringValue(rawField['auto_fill']),
      user,
      fieldType,
    );

    return FormFieldConfig(
      id: _stringValue(rawField['id']) ?? '',
      label: _stringValue(rawField['label']) ?? 'Field',
      type: fieldType,
      placeholder: _stringValue(rawField['placeholder']),
      helperText: _stringValue(rawField['helper_text']),
      required: rawField['required'] == true,
      readOnly: rawField['readonly'] == true || rawField['readOnly'] == true,
      initialValue: initialValue,
      options: _normalizeOptions(rawField['options']),
    );
  }

  TaskItem _adaptSubmission(
    Map<String, dynamic> rawSubmission,
    AppSession session,
  ) {
    final form = _asMap(rawSubmission['form']);
    final workflow = _asMap(form['workflow']);
    final workflowConfig = _asMap(workflow['workflow_config']);
    final formConfig = _asMap(form['form_config']);
    final formFieldsSchema = _asList(formConfig['fields']);
    final formData = _asMap(rawSubmission['form_data']);
    final currentStatus =
        _stringValue(rawSubmission['current_status']) ?? 'submitted';
    final availableActions = _asList(
      rawSubmission['available_actions'],
    ).map(_adaptSubmissionAction).toList(growable: false);
    final currentPendingStep = _asMap(rawSubmission['current_pending_step']);
    final timelineSteps = _asList(rawSubmission['approval_steps'])
        .map(
          (rawStep) => _adaptTimelineStep(
            rawStep,
            currentPendingStepId: _intValue(currentPendingStep['id']),
          ),
        )
        .toList(growable: false);
    final detailFields = _mapSubmissionFields(formFieldsSchema, formData);
    final createdAt = _dateTimeValue(rawSubmission['created_at']);
    final baseUrl = session.apiBaseUrl;
    final pdfPreviewUrl = _resolveAbsoluteUrl(
      baseUrl,
      _stringValue(rawSubmission['pdf_preview_url']),
    );
    final pdfDownloadUrl = _resolveAbsoluteUrl(
      baseUrl,
      _stringValue(rawSubmission['pdf_download_url']),
    );

    return TaskItem(
      id: _stringValue(rawSubmission['id']),
      formId: _stringValue(form['id']),
      title: _stringValue(form['name']) ?? 'Submission',
      requester: _stringValue(_asMap(rawSubmission['user'])['name']) ?? '-',
      summary: _buildSubmissionSummary(formFieldsSchema, formData),
      workflowLabel: _stringValue(workflow['name']) ?? 'Workflow Internal',
      workflowStatus: _mapSubmissionStatus(currentStatus),
      priorityLabel: _resolvePriorityLabel(formFieldsSchema, formData),
      timeLabel: _relativeTimeLabel(createdAt),
      lane: _resolveTaskLane(
        currentStatus: currentStatus,
        availableActions: availableActions,
      ),
      accentColor: _statusAccentColor(currentStatus),
      formFields: detailFields,
      requiresSignature: availableActions.any(
        (action) => action.requiresSignature,
      ),
      attachmentLabel: _resolveAttachmentLabel(
        formFieldsSchema,
        formData,
        fallbackPdfUrl: pdfDownloadUrl,
        submissionId: _stringValue(rawSubmission['id']) ?? '',
      ),
      currentApprovalStepId: _intValue(currentPendingStep['id']),
      currentActionTitle:
          _stringValue(currentPendingStep['step_name']) ??
          availableActions.firstOrNull?.stepName,
      currentActionNotesPlaceholder:
          availableActions.firstOrNull?.notesPlaceholder,
      currentPendingActorLabel:
          _stringValue(currentPendingStep['actor_label']) ??
          _stringValue(currentPendingStep['approver_role']),
      availableActions: availableActions,
      timelineSteps: timelineSteps.isEmpty
          ? _buildWorkflowTimelineFallback(workflowConfig)
          : timelineSteps,
      pdfPreviewUrl: pdfPreviewUrl,
      pdfDownloadUrl: pdfDownloadUrl,
      canPreviewPdf: rawSubmission['can_preview_pdf'] == true,
      createdAt: createdAt,
      rejectedAtStep: _resolveRejectedStepIndex(
        currentStatus: currentStatus,
        timelineSteps: timelineSteps,
      ),
      rejectionReason: _stringValue(rawSubmission['rejection_reason']),
    );
  }

  SubmissionAction _adaptSubmissionAction(Map<String, dynamic> rawAction) {
    return SubmissionAction(
      action: _stringValue(rawAction['action']) ?? 'approve',
      stepNumber: _intValue(rawAction['step_number']) ?? 1,
      stepName: _stringValue(rawAction['step_name']) ?? 'Approval',
      actorLabel: _stringValue(rawAction['actor_label']) ?? 'Internal',
      label: _stringValue(rawAction['label']) ?? 'Setujui',
      rejectLabel: _stringValue(rawAction['reject_label']) ?? 'Tolak',
      notesPlaceholder:
          _stringValue(rawAction['notes_placeholder']) ??
          'Tambahkan catatan jika diperlukan',
      notesRequired: rawAction['notes_required'] == true,
      canReject: rawAction['can_reject'] == true,
      requiresSignature: rawAction['requires_signature'] == true,
      canEditForm: rawAction['can_edit_form'] == true,
    );
  }

  SubmissionTimelineStep _adaptTimelineStep(
    Map<String, dynamic> rawStep, {
    required int? currentPendingStepId,
  }) {
    final status = (_stringValue(rawStep['status']) ?? 'pending').toLowerCase();
    final approvedAt = _dateTimeValue(rawStep['approved_at']);
    final note = _stringValue(rawStep['notes']);
    final actorLabel =
        _stringValue(_asMap(rawStep['approver'])['name']) ??
        _stringValue(rawStep['actor_label']) ??
        _stringValue(rawStep['approver_role']) ??
        'System';

    return SubmissionTimelineStep(
      id: _intValue(rawStep['id']),
      stepNumber: _intValue(rawStep['step_number']),
      title: _stringValue(rawStep['step_name']) ?? 'Workflow Step',
      actor: actorLabel,
      statusLabel: _approvalStepStatusLabel(status),
      timeLabel: approvedAt != null
          ? _relativeTimeLabel(approvedAt)
          : (status == 'pending' ? 'Menunggu giliran' : 'Belum diproses'),
      note: note?.trim().isNotEmpty == true
          ? note!
          : _approvalStepDefaultNote(status),
      accentColor: _approvalStepAccentColor(status),
      icon: _approvalStepIcon(status),
      isActive:
          currentPendingStepId != null &&
          _intValue(rawStep['id']) == currentPendingStepId,
      requiresSignature:
          _asMap(rawStep['config_snapshot'])['requires_signature'] == true,
    );
  }

  List<SubmissionField> _mapSubmissionFields(
    List<Map<String, dynamic>> formFieldsSchema,
    Map<String, dynamic> formData,
  ) {
    final detailFields = <SubmissionField>[];

    for (final rawField in formFieldsSchema) {
      final fieldId = _stringValue(rawField['id']);
      if (fieldId == null || fieldId.isEmpty) {
        continue;
      }

      final displayValue = _formatSubmissionFieldValue(
        rawField: rawField,
        value: formData[fieldId],
      );
      if (displayValue == null || displayValue.trim().isEmpty) {
        continue;
      }

      detailFields.add(
        SubmissionField(
          label: _stringValue(rawField['label']) ?? fieldId,
          value: displayValue,
        ),
      );
    }

    return detailFields;
  }

  List<String> _workflowHumanSteps(Map<String, dynamic> workflowConfig) {
    final steps = <String>[];

    for (final rawStep in _asList(workflowConfig['steps'])) {
      final actorType = _stringValue(rawStep['actor_type']) ?? '';
      final action = _stringValue(rawStep['action']) ?? '';
      if (actorType == 'system' || action == 'submit' || action == 'complete') {
        continue;
      }

      final stepName = _stringValue(rawStep['name']);
      if (stepName != null && stepName.trim().isNotEmpty) {
        steps.add(stepName.trim());
      }
    }

    return steps;
  }

  List<SubmissionTimelineStep> _buildWorkflowTimelineFallback(
    Map<String, dynamic> workflowConfig,
  ) {
    final humanSteps = _workflowHumanSteps(workflowConfig);

    return humanSteps
        .asMap()
        .entries
        .map(
          (entry) => SubmissionTimelineStep(
            stepNumber: entry.key + 1,
            title: entry.value,
            actor: 'Workflow',
            statusLabel: 'Menunggu',
            timeLabel: 'Belum diproses',
            note: 'Langkah ini akan aktif sesuai alur workflow.',
            accentColor: AppColors.borderStrong,
            icon: Icons.schedule_rounded,
          ),
        )
        .toList(growable: false);
  }

  String _buildSubmissionSummary(
    List<Map<String, dynamic>> formFieldsSchema,
    Map<String, dynamic> formData,
  ) {
    final summaryParts = <String>[];

    for (final rawField in formFieldsSchema) {
      final fieldId = _stringValue(rawField['id']);
      if (fieldId == null || fieldId.isEmpty) {
        continue;
      }

      if (_stringValue(rawField['auto_fill']) != null) {
        continue;
      }

      if ((_stringValue(rawField['type']) ?? '').toLowerCase() == 'file') {
        continue;
      }

      final value = _formatSubmissionFieldValue(
        rawField: rawField,
        value: formData[fieldId],
      );
      if (value == null || value.trim().isEmpty) {
        continue;
      }

      summaryParts.add(value.trim());
      if (summaryParts.length == 2) {
        break;
      }
    }

    if (summaryParts.isEmpty) {
      return 'Pengajuan internal menunggu tindak lanjut.';
    }

    return summaryParts.join(' • ');
  }

  String _resolvePriorityLabel(
    List<Map<String, dynamic>> formFieldsSchema,
    Map<String, dynamic> formData,
  ) {
    for (final rawField in formFieldsSchema) {
      final fieldId = _stringValue(rawField['id']);
      final label = (_stringValue(rawField['label']) ?? '').toLowerCase();
      if (fieldId == null || fieldId.isEmpty) {
        continue;
      }

      if (!label.contains('urgensi')) {
        continue;
      }

      final value = _formatSubmissionFieldValue(
        rawField: rawField,
        value: formData[fieldId],
      );
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }

    return 'Normal';
  }

  String _resolveAttachmentLabel(
    List<Map<String, dynamic>> formFieldsSchema,
    Map<String, dynamic> formData, {
    required String? fallbackPdfUrl,
    required String submissionId,
  }) {
    for (final rawField in formFieldsSchema) {
      final fieldId = _stringValue(rawField['id']);
      final fieldType = (_stringValue(rawField['type']) ?? '').toLowerCase();
      if (fieldId == null || fieldType != 'file') {
        continue;
      }

      final rawValue = formData[fieldId];
      final formatted = _formatSubmissionFieldValue(
        rawField: rawField,
        value: rawValue,
      );
      if (formatted != null && formatted.trim().isNotEmpty) {
        return formatted;
      }
    }

    final pdfFileName = _fileNameFromUrl(fallbackPdfUrl);
    if (pdfFileName != null) {
      return pdfFileName;
    }

    return 'submission-$submissionId.pdf';
  }

  TaskLane _resolveTaskLane({
    required String currentStatus,
    required List<SubmissionAction> availableActions,
  }) {
    if (availableActions.isNotEmpty) {
      return TaskLane.actionable;
    }

    if (currentStatus == 'completed' || currentStatus == 'rejected') {
      return TaskLane.history;
    }

    return TaskLane.inProgress;
  }

  int? _resolveRejectedStepIndex({
    required String currentStatus,
    required List<SubmissionTimelineStep> timelineSteps,
  }) {
    if (currentStatus != 'rejected') {
      return null;
    }

    for (var index = 0; index < timelineSteps.length; index++) {
      if (timelineSteps[index].statusLabel == 'Ditolak') {
        return index + 1;
      }
    }

    return null;
  }

  FormFieldType _mapFieldType(String? rawType) {
    switch ((rawType ?? '').trim().toLowerCase()) {
      case 'email':
        return FormFieldType.email;
      case 'number':
        return FormFieldType.number;
      case 'date':
        return FormFieldType.date;
      case 'file':
        return FormFieldType.file;
      case 'select':
        return FormFieldType.select;
      case 'radio':
        return FormFieldType.radio;
      case 'checkbox':
        return FormFieldType.checkbox;
      case 'textarea':
        return FormFieldType.multiline;
      default:
        return FormFieldType.text;
    }
  }

  TaskSubmissionStatus _mapSubmissionStatus(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'pending_it':
        return TaskSubmissionStatus.pendingIt;
      case 'pending_director':
        return TaskSubmissionStatus.pendingDirector;
      case 'pending_accounting':
        return TaskSubmissionStatus.pendingAccounting;
      case 'pending_payment':
        return TaskSubmissionStatus.pendingPayment;
      case 'completed':
        return TaskSubmissionStatus.completed;
      case 'rejected':
        return TaskSubmissionStatus.rejected;
      default:
        return TaskSubmissionStatus.submitted;
    }
  }

  String? _resolveAutoFillValue(
    String? autoFill,
    AuthenticatedUser user,
    FormFieldType fieldType,
  ) {
    if (autoFill == null || autoFill.trim().isEmpty) {
      return null;
    }

    switch (autoFill) {
      case 'user.name':
        return user.name;
      case 'user.email':
        return user.email;
      case 'user.department':
        return user.department;
      case 'user.employee_id':
        return user.employeeId;
      case 'today':
        return fieldType == FormFieldType.date
            ? _formatDateValue(DateTime.now())
            : DateTime.now().toIso8601String().split('T').first;
      default:
        return null;
    }
  }

  String _relativeTimeLabel(DateTime? timestamp) {
    if (timestamp == null) {
      return '-';
    }

    final delta = DateTime.now().difference(timestamp);
    if (delta.inSeconds < 60) {
      return 'Baru saja';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} menit lalu';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours} jam lalu';
    }
    if (delta.inDays < 7) {
      return '${delta.inDays} hari lalu';
    }
    if (delta.inDays < 30) {
      return '${(delta.inDays / 7).floor()} minggu lalu';
    }

    return _formatDateValue(timestamp);
  }

  String _formatDateValue(DateTime value) {
    final monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${value.day} ${monthNames[value.month - 1]} ${value.year}';
  }

  String _approvalStepStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  String _approvalStepDefaultNote(String status) {
    switch (status) {
      case 'approved':
        return 'Langkah ini sudah diproses.';
      case 'rejected':
        return 'Workflow dihentikan pada langkah ini.';
      default:
        return 'Langkah ini belum diproses.';
    }
  }

  Color _approvalStepAccentColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.emerald;
      case 'rejected':
        return AppColors.red;
      default:
        return AppColors.goldDeep;
    }
  }

  IconData _approvalStepIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _statusAccentColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed':
        return AppColors.emerald;
      case 'rejected':
        return AppColors.red;
      case 'pending_payment':
        return AppColors.blue;
      case 'pending_accounting':
        return AppColors.blue;
      case 'pending_director':
        return AppColors.goldDeep;
      case 'pending_it':
        return AppColors.goldDeep;
      default:
        return AppColors.gold;
    }
  }

  Color _formAccentColor({required String title, required String workflow}) {
    final normalizedTitle = title.toLowerCase();
    final normalizedWorkflow = workflow.toLowerCase();

    if (normalizedTitle.contains('password') ||
        normalizedWorkflow.contains('password')) {
      return AppColors.blue;
    }

    if (normalizedTitle.contains('pengadaan') ||
        normalizedWorkflow.contains('procurement')) {
      return AppColors.goldDeep;
    }

    return AppColors.gold;
  }

  String _formCategory({required String title, required String workflow}) {
    final normalizedTitle = title.toLowerCase();
    final normalizedWorkflow = workflow.toLowerCase();

    if (normalizedTitle.contains('password') ||
        normalizedWorkflow.contains('password')) {
      return 'IT Access';
    }

    if (normalizedTitle.contains('pengadaan') ||
        normalizedWorkflow.contains('procurement')) {
      return 'Procurement';
    }

    return 'Internal';
  }

  String? _formatSubmissionFieldValue({
    required Map<String, dynamic> rawField,
    required Object? value,
  }) {
    if (value == null) {
      return null;
    }

    if (value is List) {
      final items = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      return items.isEmpty ? null : items.join(', ');
    }

    final rawType = (_stringValue(rawField['type']) ?? '').toLowerCase();
    final normalizedValue = value.toString().trim();
    if (normalizedValue.isEmpty) {
      return null;
    }

    if (rawType == 'file') {
      return normalizedValue.split('/').last;
    }

    if (rawType == 'date') {
      final parsed = _dateTimeValue(normalizedValue);
      if (parsed != null) {
        return _formatDateValue(parsed);
      }
    }

    return normalizedValue;
  }

  String? _resolveAbsoluteUrl(String baseUrl, String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri != null && uri.hasScheme) {
      return rawUrl;
    }

    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '$normalizedBase$normalizedPath';
  }

  String? _fileNameFromUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(rawUrl);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : rawUrl.split('/').last;
    return segment.trim().isEmpty ? null : segment;
  }

  List<String> _normalizeOptions(Object? rawOptions) {
    if (rawOptions is List) {
      return rawOptions
          .map((option) => option.toString().trim())
          .where((option) => option.isNotEmpty)
          .toList(growable: false);
    }

    if (rawOptions is String) {
      return rawOptions
          .split(',')
          .map((option) => option.trim())
          .where((option) => option.isNotEmpty)
          .toList(growable: false);
    }

    return const <String>[];
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.cast<String, dynamic>();
    }

    return const <String, dynamic>{};
  }

  String? _stringValue(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final normalized = _stringValue(value);
    return normalized == null ? null : int.tryParse(normalized);
  }

  DateTime? _dateTimeValue(Object? value) {
    final normalized = _stringValue(value);
    return normalized == null ? null : DateTime.tryParse(normalized)?.toLocal();
  }
}
