class LeaveTypeOption {
  const LeaveTypeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.defaultAnnualQuota,
    required this.requiresBalance,
    required this.requiresAttachment,
    required this.isPaid,
    required this.color,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final num defaultAnnualQuota;
  final bool requiresBalance;
  final bool requiresAttachment;
  final bool isPaid;
  final String color;

  factory LeaveTypeOption.fromJson(Map<String, dynamic> json) {
    return LeaveTypeOption(
      id: '${json['id'] ?? ''}',
      code: _stringValue(json['code']) ?? 'annual',
      name: _stringValue(json['name']) ?? 'Cuti',
      description: _stringValue(json['description']) ?? '',
      defaultAnnualQuota: _numValue(json['default_annual_quota']),
      requiresBalance: json['requires_balance'] != false,
      requiresAttachment: json['requires_attachment'] == true,
      isPaid: json['is_paid'] != false,
      color: _stringValue(json['color']) ?? '#9B6B17',
    );
  }
}

class LeaveStaffOption {
  const LeaveStaffOption({
    required this.id,
    required this.name,
    this.email,
    this.department,
    this.roleLabel,
  });

  final String id;
  final String name;
  final String? email;
  final String? department;
  final String? roleLabel;

  String get subtitle {
    final parts = <String>[
      if ((department ?? '').trim().isNotEmpty) department!.trim(),
      if ((roleLabel ?? '').trim().isNotEmpty) roleLabel!.trim(),
    ];

    return parts.isEmpty ? (email ?? '').trim() : parts.join(' • ');
  }

  factory LeaveStaffOption.fromJson(Map<String, dynamic> json) {
    return LeaveStaffOption(
      id: '${json['id'] ?? ''}',
      name: _stringValue(json['name']) ?? 'Staff',
      email: _stringValue(json['email']),
      department: _stringValue(json['department']),
      roleLabel: _stringValue(json['role_label']),
    );
  }
}

class LeaveBalanceSummary {
  const LeaveBalanceSummary({
    required this.year,
    required this.leaveType,
    required this.entitledDays,
    required this.carriedOverDays,
    required this.adjustedDays,
    required this.usedDays,
    required this.pendingDays,
    required this.remainingDays,
    this.expiresAt,
  });

  final int year;
  final LeaveTypeOption leaveType;
  final num entitledDays;
  final num carriedOverDays;
  final num adjustedDays;
  final num usedDays;
  final num pendingDays;
  final num remainingDays;
  final DateTime? expiresAt;

  num get totalDays => entitledDays + carriedOverDays + adjustedDays;

  factory LeaveBalanceSummary.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceSummary(
      year: _intValue(json['year']) ?? DateTime.now().year,
      leaveType: LeaveTypeOption.fromJson(_mapValue(json['leave_type'])),
      entitledDays: _numValue(json['entitled_days']),
      carriedOverDays: _numValue(json['carried_over_days']),
      adjustedDays: _numValue(json['adjusted_days']),
      usedDays: _numValue(json['used_days']),
      pendingDays: _numValue(json['pending_days']),
      remainingDays: _numValue(json['remaining_days']),
      expiresAt: _optionalDate(json['expires_at']),
    );
  }
}

class LeaveDashboardSummary {
  const LeaveDashboardSummary({
    this.currentLeave,
    this.currentLeaveReturnDate,
    this.lastLeave,
    this.nextLeave,
    required this.approvedThisYear,
    required this.pendingCount,
    required this.rejectedThisYear,
  });

  final LeaveRequestItem? currentLeave;
  final DateTime? currentLeaveReturnDate;
  final LeaveRequestItem? lastLeave;
  final LeaveRequestItem? nextLeave;
  final int approvedThisYear;
  final int pendingCount;
  final int rejectedThisYear;

  factory LeaveDashboardSummary.fromJson(Map<String, dynamic> json) {
    return LeaveDashboardSummary(
      currentLeave: json['current_leave'] is Map
          ? LeaveRequestItem.fromJson(_mapValue(json['current_leave']))
          : null,
      currentLeaveReturnDate: _optionalDate(json['current_leave_return_date']),
      lastLeave: json['last_leave'] is Map
          ? LeaveRequestItem.fromJson(_mapValue(json['last_leave']))
          : null,
      nextLeave: json['next_leave'] is Map
          ? LeaveRequestItem.fromJson(_mapValue(json['next_leave']))
          : null,
      approvedThisYear: _intValue(json['approved_this_year']) ?? 0,
      pendingCount: _intValue(json['pending_count']) ?? 0,
      rejectedThisYear: _intValue(json['rejected_this_year']) ?? 0,
    );
  }
}

class LeaveApprovalStepItem {
  const LeaveApprovalStepItem({
    this.id,
    required this.stepNumber,
    required this.stepKey,
    required this.stepName,
    required this.actorType,
    this.actorValue,
    required this.actorLabel,
    this.approverName,
    required this.status,
    this.notes,
    this.signatureId,
    this.configSnapshot = const <String, dynamic>{},
    this.approvedAt,
    this.createdAt,
  });

  final int? id;
  final int stepNumber;
  final String stepKey;
  final String stepName;
  final String actorType;
  final String? actorValue;
  final String actorLabel;
  final String? approverName;
  final String status;
  final String? notes;
  final int? signatureId;
  final Map<String, dynamic> configSnapshot;
  final DateTime? approvedAt;
  final DateTime? createdAt;

  bool get requiresSignature => configSnapshot['requires_signature'] == true;

  factory LeaveApprovalStepItem.fromJson(Map<String, dynamic> json) {
    return LeaveApprovalStepItem(
      id: _intValue(json['id']),
      stepNumber: _intValue(json['step_number']) ?? 1,
      stepKey: _stringValue(json['step_key']) ?? '',
      stepName: _stringValue(json['step_name']) ?? 'Approval Cuti',
      actorType: _stringValue(json['actor_type']) ?? '',
      actorValue: _stringValue(json['actor_value']),
      actorLabel: _stringValue(json['actor_label']) ?? 'Approver Cuti',
      approverName: _stringValue(_mapValue(json['approver'])['name']),
      status: _stringValue(json['status']) ?? 'waiting',
      notes: _stringValue(json['notes']),
      signatureId: _intValue(json['signature_id']),
      configSnapshot: _mapValue(json['config_snapshot']),
      approvedAt: _optionalDateTime(json['approved_at']),
      createdAt: _optionalDateTime(json['created_at']),
    );
  }
}

class LeaveActionItem {
  const LeaveActionItem({
    required this.action,
    required this.stepNumber,
    required this.stepName,
    required this.actorLabel,
    required this.label,
    required this.rejectLabel,
    required this.notesPlaceholder,
    required this.notesRequired,
    required this.canReject,
    required this.requiresSignature,
    required this.canEditForm,
  });

  final String action;
  final int stepNumber;
  final String stepName;
  final String actorLabel;
  final String label;
  final String rejectLabel;
  final String notesPlaceholder;
  final bool notesRequired;
  final bool canReject;
  final bool requiresSignature;
  final bool canEditForm;

  factory LeaveActionItem.fromJson(Map<String, dynamic> json) {
    return LeaveActionItem(
      action: _stringValue(json['action']) ?? 'approve_leave',
      stepNumber: _intValue(json['step_number']) ?? 1,
      stepName: _stringValue(json['step_name']) ?? 'Approval Cuti',
      actorLabel: _stringValue(json['actor_label']) ?? 'Approver Cuti',
      label: _stringValue(json['label']) ?? 'Setujui',
      rejectLabel: _stringValue(json['reject_label']) ?? 'Tolak',
      notesPlaceholder:
          _stringValue(json['notes_placeholder']) ??
          'Tambahkan catatan jika diperlukan',
      notesRequired: json['notes_required'] == true,
      canReject: json['can_reject'] == true,
      requiresSignature: json['requires_signature'] == true,
      canEditForm: json['can_edit_form'] == true,
    );
  }
}

class LeaveRequestItem {
  const LeaveRequestItem({
    required this.id,
    this.requesterName,
    this.requesterDepartment,
    this.replacementUserId,
    this.replacementName,
    this.replacementDepartment,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalWorkingDays,
    required this.durationLabel,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.canCancel,
    this.delegationNotes,
    this.emergencyContact,
    this.reviewerName,
    this.reviewedAt,
    this.reviewerNotes,
    this.submittedAt,
    this.createdAt,
    this.attachmentName,
    this.attachmentUrl,
    this.currentStepKey,
    this.currentPendingActorLabel,
    this.approvalSteps = const <LeaveApprovalStepItem>[],
    this.currentPendingStep,
    this.availableActions = const <LeaveActionItem>[],
    this.pdfPreviewUrl,
    this.pdfDownloadUrl,
    this.canPreviewPdf = false,
  });

  final String id;
  final String? requesterName;
  final String? requesterDepartment;
  final String? replacementUserId;
  final String? replacementName;
  final String? replacementDepartment;
  final LeaveTypeOption? leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final num totalWorkingDays;
  final String durationLabel;
  final String reason;
  final String? delegationNotes;
  final String? emergencyContact;
  final String status;
  final String statusLabel;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final String? reviewerNotes;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final bool canCancel;
  final String? attachmentName;
  final String? attachmentUrl;
  final String? currentStepKey;
  final String? currentPendingActorLabel;
  final List<LeaveApprovalStepItem> approvalSteps;
  final LeaveApprovalStepItem? currentPendingStep;
  final List<LeaveActionItem> availableActions;
  final String? pdfPreviewUrl;
  final String? pdfDownloadUrl;
  final bool canPreviewPdf;

  factory LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    final totalWorkingDays = _numValue(json['total_working_days']);

    return LeaveRequestItem(
      id: '${json['id'] ?? ''}',
      requesterName: _stringValue(json['requester_name']),
      requesterDepartment: _stringValue(json['requester_department']),
      replacementUserId: _stringValue(json['replacement_user_id']),
      replacementName: _stringValue(json['replacement_name']),
      replacementDepartment: _stringValue(json['replacement_department']),
      leaveType: json['leave_type'] is Map
          ? LeaveTypeOption.fromJson(_mapValue(json['leave_type']))
          : null,
      startDate: _dateValue(json['start_date']),
      endDate: _dateValue(json['end_date']),
      totalWorkingDays: totalWorkingDays,
      durationLabel:
          _stringValue(json['duration_label']) ??
          _formatDayLabel(totalWorkingDays),
      reason: _stringValue(json['reason']) ?? '',
      delegationNotes: _stringValue(json['delegation_notes']),
      emergencyContact: _stringValue(json['emergency_contact']),
      status: _stringValue(json['status']) ?? 'pending',
      statusLabel: _stringValue(json['status_label']) ?? 'Menunggu Approval',
      reviewerName: _stringValue(json['reviewer_name']),
      reviewedAt: _optionalDateTime(json['reviewed_at']),
      reviewerNotes: _stringValue(json['reviewer_notes']),
      submittedAt: _optionalDateTime(json['submitted_at']),
      createdAt: _optionalDateTime(json['created_at']),
      canCancel: json['can_cancel'] == true,
      attachmentName: _stringValue(json['attachment_name']),
      attachmentUrl: _stringValue(json['attachment_url']),
      currentStepKey: _stringValue(json['current_step_key']),
      currentPendingActorLabel: _stringValue(
        json['current_pending_actor_label'],
      ),
      approvalSteps: _listValue(json['approval_steps'])
          .map((item) => LeaveApprovalStepItem.fromJson(_mapValue(item)))
          .toList(growable: false),
      currentPendingStep: json['current_pending_step'] is Map
          ? LeaveApprovalStepItem.fromJson(
              _mapValue(json['current_pending_step']),
            )
          : null,
      availableActions: _listValue(json['available_actions'])
          .map((item) => LeaveActionItem.fromJson(_mapValue(item)))
          .toList(growable: false),
      pdfPreviewUrl: _stringValue(json['pdf_preview_url']),
      pdfDownloadUrl: _stringValue(json['pdf_download_url']),
      canPreviewPdf: json['can_preview_pdf'] == true,
    );
  }
}

class LeaveHolidayItem {
  const LeaveHolidayItem({
    required this.id,
    required this.date,
    required this.name,
    required this.type,
    required this.isJointLeave,
  });

  final String id;
  final DateTime date;
  final String name;
  final String type;
  final bool isJointLeave;

  factory LeaveHolidayItem.fromJson(Map<String, dynamic> json) {
    return LeaveHolidayItem(
      id: '${json['id'] ?? ''}',
      date: _dateValue(json['date']),
      name: _stringValue(json['name']) ?? 'Hari libur',
      type: _stringValue(json['type']) ?? 'national',
      isJointLeave: json['is_joint_leave'] == true,
    );
  }
}

class LeaveCalendarEvent {
  const LeaveCalendarEvent({
    required this.date,
    required this.title,
    required this.kind,
    required this.color,
  });

  final DateTime date;
  final String title;
  final String kind;
  final String color;

  factory LeaveCalendarEvent.fromJson(Map<String, dynamic> json) {
    return LeaveCalendarEvent(
      date: _dateValue(json['date']),
      title: _stringValue(json['title']) ?? 'Agenda',
      kind: _stringValue(json['kind']) ?? 'holiday',
      color: _stringValue(json['color']) ?? '#9B6B17',
    );
  }
}

class LongWeekendRecommendation {
  const LongWeekendRecommendation({
    required this.title,
    required this.holidayName,
    required this.startDate,
    required this.endDate,
    required this.daysOff,
    required this.leaveDaysNeeded,
    required this.suggestedLeaveDates,
  });

  final String title;
  final String holidayName;
  final DateTime startDate;
  final DateTime endDate;
  final int daysOff;
  final int leaveDaysNeeded;
  final List<DateTime> suggestedLeaveDates;

  factory LongWeekendRecommendation.fromJson(Map<String, dynamic> json) {
    return LongWeekendRecommendation(
      title: _stringValue(json['title']) ?? 'Long weekend',
      holidayName: _stringValue(json['holiday_name']) ?? 'Hari libur',
      startDate: _dateValue(json['start_date']),
      endDate: _dateValue(json['end_date']),
      daysOff: _intValue(json['days_off']) ?? 0,
      leaveDaysNeeded: _intValue(json['leave_days_needed']) ?? 0,
      suggestedLeaveDates: _listValue(
        json['suggested_leave_dates'],
      ).map(_dateValue).toList(growable: false),
    );
  }
}

class LeaveDashboardData {
  const LeaveDashboardData({
    required this.year,
    required this.leaveTypes,
    this.staffOptions = const <LeaveStaffOption>[],
    required this.balance,
    required this.summary,
    required this.requests,
    required this.approvalQueue,
    required this.upcomingRequests,
    required this.holidays,
    required this.calendar,
    required this.longWeekends,
    required this.canApprove,
  });

  final int year;
  final List<LeaveTypeOption> leaveTypes;
  final List<LeaveStaffOption> staffOptions;
  final LeaveBalanceSummary balance;
  final LeaveDashboardSummary summary;
  final List<LeaveRequestItem> requests;
  final List<LeaveRequestItem> approvalQueue;
  final List<LeaveRequestItem> upcomingRequests;
  final List<LeaveHolidayItem> holidays;
  final List<LeaveCalendarEvent> calendar;
  final List<LongWeekendRecommendation> longWeekends;
  final bool canApprove;

  factory LeaveDashboardData.fromJson(Map<String, dynamic> json) {
    return LeaveDashboardData(
      year: _intValue(json['year']) ?? DateTime.now().year,
      leaveTypes: _listValue(json['leave_types'])
          .map((item) => LeaveTypeOption.fromJson(_mapValue(item)))
          .toList(growable: false),
      staffOptions: _listValue(json['staff_options'])
          .map((item) => LeaveStaffOption.fromJson(_mapValue(item)))
          .toList(growable: false),
      balance: LeaveBalanceSummary.fromJson(_mapValue(json['balance'])),
      summary: LeaveDashboardSummary.fromJson(_mapValue(json['summary'])),
      requests: _listValue(json['requests'])
          .map((item) => LeaveRequestItem.fromJson(_mapValue(item)))
          .toList(growable: false),
      approvalQueue: _listValue(json['approval_queue'])
          .map((item) => LeaveRequestItem.fromJson(_mapValue(item)))
          .toList(growable: false),
      upcomingRequests: _listValue(json['upcoming_requests'])
          .map((item) => LeaveRequestItem.fromJson(_mapValue(item)))
          .toList(growable: false),
      holidays: _listValue(json['holidays'])
          .map((item) => LeaveHolidayItem.fromJson(_mapValue(item)))
          .toList(growable: false),
      calendar: _listValue(json['calendar'])
          .map((item) => LeaveCalendarEvent.fromJson(_mapValue(item)))
          .toList(growable: false),
      longWeekends: _listValue(json['long_weekends'])
          .map((item) => LongWeekendRecommendation.fromJson(_mapValue(item)))
          .toList(growable: false),
      canApprove: json['can_approve'] == true,
    );
  }
}

String? _stringValue(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty || normalized == 'null'
      ? null
      : normalized;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}');
}

num _numValue(Object? value) {
  if (value is num) {
    return value;
  }
  final normalized = '${value ?? ''}'.replaceAll(',', '.').trim();
  return num.tryParse(normalized) ?? 0;
}

Map<String, dynamic> _mapValue(Object? value) {
  return switch (value) {
    final Map<String, dynamic> map => map,
    final Map<dynamic, dynamic> map => map.cast<String, dynamic>(),
    _ => const <String, dynamic>{},
  };
}

List<dynamic> _listValue(Object? value) {
  return switch (value) {
    final List<dynamic> list => list,
    _ => const <dynamic>[],
  };
}

DateTime _dateValue(Object? value) {
  return _optionalDate(value) ?? DateTime.now();
}

DateTime? _optionalDate(Object? value) {
  final normalized = _stringValue(value);
  if (normalized == null) {
    return null;
  }

  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) {
    return null;
  }

  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _optionalDateTime(Object? value) {
  final normalized = _stringValue(value);
  return normalized == null ? null : DateTime.tryParse(normalized);
}

String _formatDayLabel(num days) {
  final normalized = days % 1 == 0 ? days.toInt().toString() : '$days';
  return '$normalized hari kerja';
}
