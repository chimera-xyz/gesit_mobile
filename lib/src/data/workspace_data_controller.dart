import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../models/leave_models.dart';
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

  bool get canShowActionableTasksLane {
    final user = _sessionController.session?.user;
    if (user?.canApproveForms == true || user?.canAccessLeave == true) {
      return true;
    }

    return !_usingFallbackTasks && pendingActionCount > 0;
  }

  TaskItem? taskById(String submissionId) {
    for (final task in _tasks) {
      if (!task.isLeave && task.id == submissionId) {
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
      var latestCookies = session.cookies;
      final tasks = <TaskItem>[];
      var tasksError = '';

      if (session.user.canAccessSubmissionTasks) {
        try {
          final payload = await _apiClient.fetchSubmissions(
            baseUrl: session.apiBaseUrl,
            cookies: latestCookies,
            queryParameters: {
              if (search != null && search.trim().isNotEmpty)
                'search': search.trim(),
              if (status != null && status.trim().isNotEmpty)
                'status': status.trim(),
              if (formId != null && formId.trim().isNotEmpty)
                'form_id': formId.trim(),
            },
          );
          latestCookies = payload.cookies;
          await _sessionController.syncCookies(payload.cookies);

          final rawSubmissions = _asList(payload.data['submissions']);
          tasks.addAll(
            rawSubmissions.map(
              (rawSubmission) => _adaptSubmission(rawSubmission, session),
            ),
          );
        } on GesitApiException catch (error) {
          if (error.statusCode == 401) {
            _tasksError = 'Sesi login berakhir. Silakan masuk lagi.';
            _tasks = const <TaskItem>[];
            _usingFallbackTasks = false;
            await _sessionController.invalidateSession(
              errorMessage: _tasksError,
            );
            return;
          }
          tasksError = error.message;
        } on TimeoutException {
          tasksError = 'Server tasks terlalu lama merespons.';
        } catch (_) {
          tasksError = 'Tasks belum bisa dimuat dari server.';
        }
      }

      if (session.user.canAccessLeave) {
        try {
          final leavePayload = await _apiClient.fetchLeaveDashboard(
            baseUrl: session.apiBaseUrl,
            cookies: latestCookies,
          );
          latestCookies = leavePayload.cookies;
          await _sessionController.syncCookies(leavePayload.cookies);

          final dashboard = LeaveDashboardData.fromJson(leavePayload.data);
          tasks.addAll(
            dashboard.approvalQueue
                .map(
                  (request) =>
                      _adaptLeaveApproval(request, baseUrl: session.apiBaseUrl),
                )
                .toList(growable: false),
          );
        } on GesitApiException catch (error) {
          if (error.statusCode == 401) {
            _tasksError = 'Sesi login berakhir. Silakan masuk lagi.';
            _tasks = const <TaskItem>[];
            _usingFallbackTasks = false;
            await _sessionController.invalidateSession(
              errorMessage: _tasksError,
            );
            return;
          }
          tasksError = error.message;
        } on TimeoutException {
          tasksError = 'Server cuti terlalu lama merespons.';
        } catch (_) {
          tasksError = 'Approval cuti belum bisa dimuat.';
        }
      }

      if (tasks.isEmpty &&
          tasksError.isNotEmpty &&
          session.user.canAccessSubmissionTasks &&
          !session.user.canAccessLeave) {
        _tasksError = tasksError;
        _tasks = List<TaskItem>.unmodifiable(DemoData.tasks);
        _usingFallbackTasks = true;
        return;
      }

      tasks.sort(_sortTasks);
      _tasks = List<TaskItem>.unmodifiable(tasks);
      _usingFallbackTasks = false;
      _tasksError = tasksError.isEmpty ? null : tasksError;
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
    if (task.isLeave) {
      return _fetchLeaveTaskDetail(task);
    }

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

  Future<Uint8List> fetchTaskPdfPreview(TaskItem task) async {
    final submissionId = task.id?.trim();
    if (submissionId == null || submissionId.isEmpty) {
      throw const GesitApiException('Submission belum punya ID PDF valid.');
    }

    final session = _requireSession();
    if (task.isLeave) {
      final payload = await _apiClient.fetchLeavePdfPreview(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        leaveRequestId: submissionId,
      );
      await _sessionController.syncCookies(payload.cookies);

      if (payload.bytes.isEmpty) {
        throw const GesitApiException(
          'File PDF cuti kosong atau belum tersedia.',
        );
      }

      return payload.bytes;
    }

    final payload = await _apiClient.fetchSubmissionPdfPreview(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      submissionId: submissionId,
    );
    await _sessionController.syncCookies(payload.cookies);

    if (payload.bytes.isEmpty) {
      throw const GesitApiException('File PDF kosong atau belum tersedia.');
    }

    return payload.bytes;
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
    Map<String, List<ApiMultipartFilePayload>> fileGroups = const {},
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
      fileGroups: fileGroups,
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
    if (task.isLeave) {
      return _approveLeaveTask(
        task: task,
        notes: notes,
        signatureDataUrl: signatureDataUrl,
      );
    }

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
    if (task.isLeave) {
      return _rejectLeaveTask(task: task, reason: reason);
    }

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
    final currentIndex = nextTasks.indexWhere(
      (task) => task.identityKey == nextTask.identityKey,
    );

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
        formConfig: formConfig,
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

    final allowsMultipleFiles =
        rawField['multiple'] == true ||
        ((_intValue(rawField['max_files']) ?? 1) > 1);

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
      minItems: _intValue(rawField['min_items']) ?? 1,
      maxItems: _intValue(rawField['max_items']) ?? 2,
      allowsMultipleFiles: allowsMultipleFiles,
      maxFiles:
          _intValue(rawField['max_files']) ?? (allowsMultipleFiles ? 5 : 1),
      acceptedFileTypes: _normalizeOptions(
        rawField['accepted_mimes'] ?? rawField['accepted_extensions'],
      ),
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

  Future<TaskItem> _fetchLeaveTaskDetail(TaskItem task) async {
    final leaveRequestId = task.id?.trim();
    if (leaveRequestId == null || leaveRequestId.isEmpty) {
      return task;
    }

    final session = _requireSession();
    final payload = await _apiClient.fetchLeaveDashboard(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
    );
    await _sessionController.syncCookies(payload.cookies);

    final dashboard = LeaveDashboardData.fromJson(payload.data);
    final leaveRequest = dashboard.approvalQueue
        .where((request) => request.id == leaveRequestId)
        .firstOrNull;
    if (leaveRequest == null) {
      return task;
    }

    final updatedTask = _adaptLeaveApproval(
      leaveRequest,
      baseUrl: session.apiBaseUrl,
    );
    _replaceOrInsertTask(updatedTask);
    notifyListeners();
    return updatedTask;
  }

  Future<TaskItem> _approveLeaveTask({
    required TaskItem task,
    required String notes,
    String? signatureDataUrl,
  }) async {
    final leaveRequestId = task.id?.trim();
    if (leaveRequestId == null || leaveRequestId.isEmpty) {
      throw const GesitApiException('Pengajuan cuti belum punya ID backend.');
    }

    final session = _requireSession();
    var latestCookies = session.cookies;
    String? signatureId;

    if (signatureDataUrl != null && signatureDataUrl.trim().isNotEmpty) {
      final approvalStepId = task.currentApprovalStepId;
      if (approvalStepId == null) {
        throw const GesitApiException(
          'Approval step cuti aktif tidak ditemukan untuk signature.',
        );
      }

      final signaturePayload = await _apiClient.drawLeaveSignature(
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

    final payload = await _apiClient.approveLeaveRequest(
      baseUrl: session.apiBaseUrl,
      cookies: latestCookies,
      leaveRequestId: leaveRequestId,
      reviewerNotes: notes.trim().isEmpty ? null : notes.trim(),
      signatureId: signatureId,
    );
    await _sessionController.syncCookies(payload.cookies);

    final request = _asMap(payload.data['request']);
    if (request.isEmpty) {
      throw const GesitApiException('Respons approval cuti tidak valid.');
    }

    final updatedTask = _adaptLeaveApproval(
      LeaveRequestItem.fromJson(request),
      baseUrl: session.apiBaseUrl,
    );
    _replaceOrInsertTask(updatedTask);
    await refreshTasks();
    return updatedTask;
  }

  Future<TaskItem> _rejectLeaveTask({
    required TaskItem task,
    required String reason,
  }) async {
    final leaveRequestId = task.id?.trim();
    if (leaveRequestId == null || leaveRequestId.isEmpty) {
      throw const GesitApiException('Pengajuan cuti belum punya ID backend.');
    }

    final session = _requireSession();
    final payload = await _apiClient.rejectLeaveRequest(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      leaveRequestId: leaveRequestId,
      reviewerNotes: reason.trim(),
    );
    await _sessionController.syncCookies(payload.cookies);

    final request = _asMap(payload.data['request']);
    if (request.isEmpty) {
      throw const GesitApiException('Respons penolakan cuti tidak valid.');
    }

    final updatedTask = _adaptLeaveApproval(
      LeaveRequestItem.fromJson(request),
      baseUrl: session.apiBaseUrl,
    );
    _replaceOrInsertTask(updatedTask);
    await refreshTasks();
    return updatedTask;
  }

  TaskItem _adaptLeaveApproval(LeaveRequestItem request, {String? baseUrl}) {
    final status = request.status.trim().toLowerCase();
    final isPending = status == 'pending';
    final submittedAt = request.submittedAt ?? request.createdAt;
    final currentStep = request.currentPendingStep;
    final availableActions = request.availableActions
        .map(_adaptLeaveAction)
        .toList(growable: false);
    final timelineSteps = request.approvalSteps
        .map(
          (step) => _adaptLeaveTimelineStep(
            step,
            currentPendingStepId: currentStep?.id,
          ),
        )
        .toList(growable: false);
    final pdfPreviewUrl = _resolveAbsoluteUrl(
      baseUrl ?? '',
      request.pdfPreviewUrl,
    );
    final pdfDownloadUrl = _resolveAbsoluteUrl(
      baseUrl ?? '',
      request.pdfDownloadUrl,
    );

    return TaskItem(
      id: request.id,
      title: request.leaveType?.name ?? 'Pengajuan Cuti',
      requester: request.requesterName ?? 'Karyawan',
      summary: _leaveSummary(request),
      workflowLabel: 'Approval Cuti',
      workflowStatus: _mapLeaveStatus(status),
      priorityLabel: request.durationLabel,
      timeLabel: _relativeTimeLabel(submittedAt),
      lane: availableActions.isNotEmpty
          ? TaskLane.actionable
          : isPending
          ? TaskLane.inProgress
          : TaskLane.history,
      accentColor: _leaveStatusColor(status),
      formFields: _leaveDetailFields(request),
      kind: TaskKind.leave,
      leaveRequest: request,
      requiresSignature: availableActions.any(
        (action) => action.requiresSignature,
      ),
      attachmentLabel:
          _fileNameFromUrl(pdfDownloadUrl) ?? 'CUTI-${request.id}.pdf',
      currentApprovalStepId: currentStep?.id,
      currentActionTitle:
          currentStep?.stepName ??
          availableActions.firstOrNull?.stepName ??
          request.statusLabel,
      currentActionNotesPlaceholder:
          availableActions.firstOrNull?.notesPlaceholder ??
          'Tambahkan catatan jika diperlukan',
      currentPendingActorLabel:
          request.currentPendingActorLabel ??
          currentStep?.actorLabel ??
          availableActions.firstOrNull?.actorLabel,
      availableActions: availableActions,
      timelineSteps: timelineSteps.isEmpty
          ? _leaveTimeline(request)
          : timelineSteps,
      pdfPreviewUrl: pdfPreviewUrl,
      pdfDownloadUrl: pdfDownloadUrl,
      canPreviewPdf: request.canPreviewPdf,
      createdAt: submittedAt,
      rejectionReason: request.reviewerNotes,
    );
  }

  SubmissionAction _adaptLeaveAction(LeaveActionItem action) {
    return SubmissionAction(
      action: action.action,
      stepNumber: action.stepNumber,
      stepName: action.stepName,
      actorLabel: action.actorLabel,
      label: action.label,
      rejectLabel: action.rejectLabel,
      notesPlaceholder: action.notesPlaceholder,
      notesRequired: action.notesRequired,
      canReject: action.canReject,
      requiresSignature: action.requiresSignature,
      canEditForm: action.canEditForm,
    );
  }

  SubmissionTimelineStep _adaptLeaveTimelineStep(
    LeaveApprovalStepItem step, {
    required int? currentPendingStepId,
  }) {
    final status = step.status.trim().toLowerCase();
    final approvedAt = step.approvedAt;
    final actor = (step.approverName ?? '').trim().isNotEmpty
        ? step.approverName!
        : step.actorLabel;

    return SubmissionTimelineStep(
      id: step.id,
      stepNumber: step.stepNumber,
      title: step.stepName,
      actor: actor,
      statusLabel: _approvalStepStatusLabel(status),
      timeLabel: approvedAt != null
          ? _relativeTimeLabel(approvedAt)
          : status == 'pending'
          ? 'Menunggu tanda tangan'
          : status == 'waiting'
          ? 'Menunggu giliran'
          : 'Belum diproses',
      note: (step.notes ?? '').trim().isNotEmpty
          ? step.notes!
          : _approvalStepDefaultNote(status),
      accentColor: _approvalStepAccentColor(status),
      icon: _approvalStepIcon(status),
      isActive: currentPendingStepId != null && step.id == currentPendingStepId,
      requiresSignature: step.requiresSignature,
    );
  }

  String _leaveSummary(LeaveRequestItem request) {
    final dateRange = _formatDateRange(request.startDate, request.endDate);
    final reason = request.reason.trim();

    if (reason.isEmpty) {
      return '$dateRange • ${request.durationLabel}';
    }

    return '$dateRange • $reason';
  }

  List<SubmissionField> _leaveDetailFields(LeaveRequestItem request) {
    final fields = <SubmissionField>[
      SubmissionField(
        label: 'Jenis cuti',
        value: request.leaveType?.name ?? 'Cuti',
      ),
      SubmissionField(
        label: 'Tanggal',
        value: _formatDateRange(request.startDate, request.endDate),
      ),
      SubmissionField(label: 'Durasi', value: request.durationLabel),
      SubmissionField(
        label: 'Departemen',
        value: request.requesterDepartment?.trim().isNotEmpty == true
            ? request.requesterDepartment!
            : '-',
      ),
      SubmissionField(
        label: 'Staff pengganti',
        value: request.replacementName?.trim().isNotEmpty == true
            ? request.replacementName!
            : '-',
      ),
      SubmissionField(
        label: 'Alasan',
        value: request.reason.trim().isEmpty ? '-' : request.reason,
      ),
    ];

    if ((request.emergencyContact ?? '').trim().isNotEmpty) {
      fields.add(
        SubmissionField(
          label: 'Kontak darurat',
          value: request.emergencyContact!,
        ),
      );
    }

    if ((request.reviewerNotes ?? '').trim().isNotEmpty) {
      fields.add(
        SubmissionField(
          label: 'Catatan reviewer',
          value: request.reviewerNotes!,
        ),
      );
    }

    return fields;
  }

  List<SubmissionTimelineStep> _leaveTimeline(LeaveRequestItem request) {
    final status = request.status.trim().toLowerCase();
    final submittedAt = request.submittedAt ?? request.createdAt;
    final reviewedAt = request.reviewedAt;
    final decisionLabel = switch (status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      'cancelled' => 'Dibatalkan',
      _ => 'Menunggu',
    };
    final decisionColor = _leaveStatusColor(status);
    final decisionIcon = switch (status) {
      'approved' => Icons.check_circle_rounded,
      'rejected' => Icons.cancel_rounded,
      'cancelled' => Icons.remove_circle_rounded,
      _ => Icons.schedule_rounded,
    };

    return [
      SubmissionTimelineStep(
        stepNumber: 1,
        title: 'Pengajuan dikirim',
        actor: request.requesterName ?? 'Karyawan',
        statusLabel: 'Selesai',
        timeLabel: _relativeTimeLabel(submittedAt),
        note: 'Pengajuan cuti masuk ke antrean approval.',
        accentColor: AppColors.emerald,
        icon: Icons.send_rounded,
      ),
      SubmissionTimelineStep(
        stepNumber: 2,
        title: 'Review cuti',
        actor: request.reviewerName ?? 'Approver Cuti',
        statusLabel: decisionLabel,
        timeLabel: reviewedAt == null
            ? 'Menunggu keputusan'
            : _relativeTimeLabel(reviewedAt),
        note: (request.reviewerNotes ?? '').trim().isNotEmpty
            ? request.reviewerNotes!
            : status == 'pending'
            ? 'Menunggu keputusan dari approver.'
            : 'Pengajuan cuti sudah diproses.',
        accentColor: decisionColor,
        icon: decisionIcon,
        isActive: status == 'pending',
      ),
    ];
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

      final rawType = (_stringValue(rawField['type']) ?? '').toLowerCase();
      if (rawType == 'procurement_items') {
        final procurementItems = _procurementSubmissionItems(formData[fieldId]);
        if (procurementItems.isEmpty) {
          continue;
        }

        detailFields.add(
          SubmissionField(
            label: _stringValue(rawField['label']) ?? fieldId,
            value: _procurementItemsSummary(procurementItems),
            procurementItems: procurementItems,
          ),
        );
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

      if ((_stringValue(rawField['type']) ?? '').toLowerCase() ==
          'procurement_items') {
        final procurementItems = _procurementSubmissionItems(formData[fieldId]);
        if (procurementItems.isEmpty) {
          continue;
        }

        summaryParts.add(_procurementItemsSummary(procurementItems));
        if (summaryParts.length == 2) {
          break;
        }
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
      case 'procurement_items':
        return FormFieldType.procurementItems;
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

  TaskSubmissionStatus _mapLeaveStatus(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'approved':
        return TaskSubmissionStatus.leaveApproved;
      case 'rejected':
        return TaskSubmissionStatus.leaveRejected;
      case 'cancelled':
        return TaskSubmissionStatus.leaveCancelled;
      default:
        return TaskSubmissionStatus.leavePending;
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

  String _formatDateRange(DateTime start, DateTime end) {
    if (_dateOnly(start) == _dateOnly(end)) {
      return _formatDateValue(start);
    }

    if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${_formatDateValue(end)}';
    }

    return '${_formatDateValue(start)} - ${_formatDateValue(end)}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _approvalStepStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      case 'skipped':
        return 'Dilewati';
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
      case 'pending':
        return 'Menunggu tanda tangan dan keputusan approver.';
      case 'waiting':
        return 'Langkah ini akan aktif setelah tahap sebelumnya selesai.';
      case 'skipped':
        return 'Langkah ini tidak lagi perlu diproses.';
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
      case 'skipped':
        return AppColors.inkMuted;
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
      case 'skipped':
        return Icons.remove_circle_rounded;
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

  Color _leaveStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      case 'cancelled':
        return AppColors.inkMuted;
      default:
        return AppColors.amber;
    }
  }

  Color _formAccentColor({required String title, required String workflow}) {
    final normalizedTitle = title.toLowerCase();
    final normalizedWorkflow = workflow.toLowerCase();

    if (normalizedTitle.contains('reimbursement') ||
        normalizedTitle.contains('berobat') ||
        normalizedWorkflow.contains('reimbursement')) {
      return AppColors.emerald;
    }

    if (normalizedTitle.contains('pengadaan') ||
        normalizedWorkflow.contains('procurement')) {
      return AppColors.goldDeep;
    }

    return AppColors.gold;
  }

  String _formCategory({
    Map<String, dynamic> formConfig = const {},
    required String title,
    required String workflow,
  }) {
    final configuredCategory = _stringValue(formConfig['category'])?.trim();

    if (configuredCategory != null && configuredCategory.isNotEmpty) {
      return configuredCategory;
    }

    final normalizedTitle = title.toLowerCase();
    final normalizedWorkflow = workflow.toLowerCase();

    if (normalizedTitle.contains('reimbursement') ||
        normalizedTitle.contains('berobat') ||
        normalizedWorkflow.contains('reimbursement')) {
      return 'Reimbursement';
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

    final rawType = (_stringValue(rawField['type']) ?? '').toLowerCase();

    if (rawType == 'file') {
      if (value is List) {
        final fileNames = value
            .map((item) => item.toString().trim().split('/').last)
            .where((item) => item.isNotEmpty)
            .toList(growable: false);

        return fileNames.isEmpty ? null : fileNames.join(', ');
      }

      final normalizedFileValue = value.toString().trim();
      return normalizedFileValue.isEmpty
          ? null
          : normalizedFileValue.split('/').last;
    }

    if (value is List) {
      if (value.every((item) => item is Map)) {
        final procurementItems = _procurementSubmissionItems(value);
        return procurementItems.isEmpty
            ? null
            : _procurementItemsPlainText(procurementItems);
      }

      final items = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      return items.isEmpty ? null : items.join(', ');
    }

    final normalizedValue = value.toString().trim();
    if (normalizedValue.isEmpty) {
      return null;
    }

    if (rawType == 'date') {
      final parsed = _dateTimeValue(normalizedValue);
      if (parsed != null) {
        return _formatDateValue(parsed);
      }
    }

    return normalizedValue;
  }

  List<ProcurementSubmissionItem> _procurementSubmissionItems(Object? value) {
    if (value is! List) {
      return const <ProcurementSubmissionItem>[];
    }

    return value
        .whereType<Map>()
        .map((item) {
          final description =
              _stringValue(item['description']) ??
              _stringValue(item['name']) ??
              '';
          final specifications =
              _stringValue(item['specifications']) ??
              _stringValue(item['specification']) ??
              '';
          final quantity = _numValue(item['quantity']) ?? 0;
          final unitPrice =
              _numValue(item['unit_price']) ?? _numValue(item['price']) ?? 0;
          final amount = _numValue(item['amount']) ?? (quantity * unitPrice);

          if (description.isEmpty &&
              specifications.isEmpty &&
              quantity <= 0 &&
              unitPrice <= 0 &&
              amount <= 0) {
            return null;
          }

          return ProcurementSubmissionItem(
            description: description,
            quantity: quantity,
            unitPrice: unitPrice,
            amount: amount,
            specifications: specifications,
          );
        })
        .whereType<ProcurementSubmissionItem>()
        .toList(growable: false);
  }

  String _procurementItemsSummary(List<ProcurementSubmissionItem> items) {
    final firstName = items.first.description.trim().isNotEmpty
        ? items.first.description.trim()
        : 'Item pengadaan';
    final countLabel = items.length == 1 ? '1 item' : '${items.length} item';
    final total = items.fold<num>(0, (sum, item) => sum + item.amount);

    if (total > 0) {
      return '$firstName • $countLabel • ${_formatCurrency(total)}';
    }

    return '$firstName • $countLabel';
  }

  String _procurementItemsPlainText(List<ProcurementSubmissionItem> items) {
    return items
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          final name = item.description.trim().isNotEmpty
              ? item.description.trim()
              : 'Item $index';
          final priceLine =
              'Qty ${_formatQuantity(item.quantity)} x ${_formatCurrency(item.unitPrice)} = ${_formatCurrency(item.amount)}';

          if (!item.hasSpecifications) {
            return '$index. $name\n$priceLine';
          }

          return '$index. $name\nSpesifikasi: ${item.specifications}\n$priceLine';
        })
        .join('\n\n');
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

  num? _numValue(Object? value) {
    if (value is num) {
      return value;
    }

    final normalized = _stringValue(
      value,
    )?.replaceAll('.', '').replaceAll(',', '.');
    return normalized == null ? null : num.tryParse(normalized);
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatQuantity(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  DateTime? _dateTimeValue(Object? value) {
    final normalized = _stringValue(value);
    return normalized == null ? null : DateTime.tryParse(normalized)?.toLocal();
  }
}
