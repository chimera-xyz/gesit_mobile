import '../models/leave_models.dart';

class LeaveDemoData {
  static LeaveDashboardData dashboard({DateTime? now}) {
    final today = now ?? DateTime.now();
    final year = today.year;
    final sick = LeaveTypeOption(
      id: '1',
      code: 'sick',
      name: 'Sakit',
      description: 'Cuti sakit dengan lampiran bila diperlukan.',
      defaultAnnualQuota: 0,
      requiresBalance: false,
      requiresAttachment: true,
      isPaid: true,
      color: '#15803D',
    );
    final emergency = LeaveTypeOption(
      id: '2',
      code: 'emergency',
      name: 'Darurat-Kematian, Kelahiran,dll(Cuti)',
      description: 'Cuti darurat untuk kondisi keluarga.',
      defaultAnnualQuota: 0,
      requiresBalance: false,
      requiresAttachment: false,
      isPaid: true,
      color: '#92400E',
    );
    final marriage = LeaveTypeOption(
      id: '3',
      code: 'marriage',
      name: 'Menikah(Cuti)',
      description: 'Cuti menikah karyawan.',
      defaultAnnualQuota: 0,
      requiresBalance: false,
      requiresAttachment: false,
      isPaid: true,
      color: '#7C3AED',
    );
    final maternity = LeaveTypeOption(
      id: '4',
      code: 'maternity',
      name: 'Hamil/Melahirkan(Cuti)',
      description: 'Cuti hamil atau melahirkan.',
      defaultAnnualQuota: 0,
      requiresBalance: false,
      requiresAttachment: false,
      isPaid: true,
      color: '#BE185D',
    );
    final annual = LeaveTypeOption(
      id: '5',
      code: 'annual',
      name: 'Tahunan(Cuti)',
      description: 'Hak cuti tahunan karyawan.',
      defaultAnnualQuota: 12,
      requiresBalance: true,
      requiresAttachment: false,
      isPaid: true,
      color: '#9B6B17',
    );
    final nextLeave = LeaveRequestItem(
      id: 'demo-2',
      leaveType: annual,
      startDate: DateTime(year, 8, 14),
      endDate: DateTime(year, 8, 14),
      totalWorkingDays: 1,
      durationLabel: '1 hari kerja',
      reason: 'Extend long weekend Hari Kemerdekaan.',
      status: 'pending',
      statusLabel: 'Menunggu Approval',
      canCancel: true,
      submittedAt: today.subtract(const Duration(days: 1)),
      createdAt: today.subtract(const Duration(days: 1)),
    );
    final lastLeave = LeaveRequestItem(
      id: 'demo-1',
      leaveType: annual,
      startDate: DateTime(year, 4, 10),
      endDate: DateTime(year, 4, 10),
      totalWorkingDays: 1,
      durationLabel: '1 hari kerja',
      reason: 'Keperluan keluarga.',
      status: 'approved',
      statusLabel: 'Disetujui',
      canCancel: false,
      reviewerName: 'Operational Director',
      reviewedAt: DateTime(year, 4, 8, 9, 30),
      submittedAt: DateTime(year, 4, 7, 14),
      createdAt: DateTime(year, 4, 7, 14),
    );

    return LeaveDashboardData(
      year: year,
      leaveTypes: [sick, emergency, marriage, maternity, annual],
      balance: LeaveBalanceSummary(
        year: year,
        leaveType: annual,
        entitledDays: 12,
        carriedOverDays: 0,
        adjustedDays: 0,
        usedDays: 1,
        pendingDays: 1,
        remainingDays: 10,
        expiresAt: DateTime(year, 12, 31),
      ),
      summary: LeaveDashboardSummary(
        currentLeave: null,
        currentLeaveReturnDate: null,
        lastLeave: lastLeave,
        nextLeave: nextLeave,
        approvedThisYear: 1,
        pendingCount: 1,
        rejectedThisYear: 0,
      ),
      requests: [nextLeave, lastLeave],
      approvalQueue: const [],
      upcomingRequests: [nextLeave],
      holidays: [
        LeaveHolidayItem(
          id: 'holiday-1',
          date: DateTime(year, 6, 1),
          name: 'Hari Lahir Pancasila',
          type: 'national',
          isJointLeave: false,
        ),
        LeaveHolidayItem(
          id: 'holiday-2',
          date: DateTime(year, 8, 17),
          name: 'Proklamasi Kemerdekaan',
          type: 'national',
          isJointLeave: false,
        ),
        LeaveHolidayItem(
          id: 'holiday-3',
          date: DateTime(year, 12, 25),
          name: 'Kelahiran Yesus Kristus',
          type: 'national',
          isJointLeave: false,
        ),
      ],
      calendar: [
        LeaveCalendarEvent(
          date: DateTime(year, 6, 1),
          title: 'Hari Lahir Pancasila',
          kind: 'holiday',
          color: '#9B6B17',
        ),
        LeaveCalendarEvent(
          date: DateTime(year, 8, 14),
          title: 'Tahunan(Cuti)',
          kind: 'leave_pending',
          color: '#B7791F',
        ),
        LeaveCalendarEvent(
          date: DateTime(year, 8, 17),
          title: 'Proklamasi Kemerdekaan',
          kind: 'holiday',
          color: '#9B6B17',
        ),
      ],
      longWeekends: [
        LongWeekendRecommendation(
          title: 'Ambil 1 hari cuti untuk long weekend',
          holidayName: 'Proklamasi Kemerdekaan',
          startDate: DateTime(year, 8, 14),
          endDate: DateTime(year, 8, 17),
          daysOff: 4,
          leaveDaysNeeded: 1,
          suggestedLeaveDates: [DateTime(year, 8, 14)],
        ),
        LongWeekendRecommendation(
          title: 'Long weekend siap dipakai',
          holidayName: 'Kelahiran Yesus Kristus',
          startDate: DateTime(year, 12, 24),
          endDate: DateTime(year, 12, 27),
          daysOff: 4,
          leaveDaysNeeded: 0,
          suggestedLeaveDates: const [],
        ),
      ],
      canApprove: false,
    );
  }
}
