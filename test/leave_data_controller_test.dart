import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/leave_data_controller.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSessionController sessionController;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    sessionController = AppSessionController(apiClient: GesitApiClient());
    await sessionController.syncSession(_buildSession(), notify: false);
  });

  tearDown(() {
    sessionController.dispose();
  });

  test('loads leave dashboard data from API', () async {
    final controller = LeaveDataController(
      sessionController: sessionController,
      apiClient: GesitApiClient(
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/leaves');
          return _jsonResponse(_leaveDashboardPayload());
        }),
      ),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.usingFallback, isFalse);
    expect(controller.dashboard.balance.remainingDays, 8);
    expect(controller.dashboard.staffOptions.single.name, 'Backup Staff');
    expect(controller.dashboard.summary.currentLeave?.id, '9');
    expect(
      controller.dashboard.summary.currentLeaveReturnDate,
      DateTime(2026, 5, 18),
    );
    expect(controller.dashboard.requests, hasLength(1));
    expect(controller.dashboard.approvalQueue.single.requesterName, 'Maya Ops');
    expect(controller.dashboard.longWeekends.single.daysOff, 4);
    expect(
      controller.estimateWorkingDays(
        DateTime(2026, 5, 10),
        DateTime(2026, 5, 13),
      ),
      3,
    );
    expect(
      controller.estimateWorkingDays(
        DateTime(2026, 8, 14),
        DateTime(2026, 8, 17),
      ),
      1,
    );
  });
}

AppSession _buildSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'employee-1',
      name: 'Employee',
      email: 'employee@example.com',
      roles: ['Employee'],
      permissions: ['view leave dashboard', 'request leave'],
      department: 'IT',
    ),
    apiBaseUrl: 'https://gesit.example.com',
    cookies: const {'gesit_session': 'cookie-1'},
    rememberSession: true,
    authenticatedAt: DateTime.parse('2026-05-10T10:00:00.000Z'),
  );
}

Map<String, dynamic> _leaveDashboardPayload() {
  return {
    'year': 2026,
    'leave_types': [
      {
        'id': 1,
        'code': 'annual',
        'name': 'Tahunan(Cuti)',
        'description': 'Hak cuti tahunan.',
        'default_annual_quota': 12,
        'requires_balance': true,
        'requires_attachment': false,
        'is_paid': true,
        'color': '#9B6B17',
      },
    ],
    'staff_options': [
      {
        'id': 22,
        'name': 'Backup Staff',
        'email': 'backup@example.com',
        'department': 'Operations',
        'role_label': 'Employee',
      },
    ],
    'balance': {
      'year': 2026,
      'leave_type': {'id': 1, 'code': 'annual', 'name': 'Tahunan(Cuti)'},
      'entitled_days': 12,
      'carried_over_days': 0,
      'adjusted_days': 0,
      'used_days': 3,
      'pending_days': 1,
      'remaining_days': 8,
      'expires_at': '2026-12-31',
    },
    'summary': {
      'current_leave': {
        'id': 9,
        'leave_type': {'id': 1, 'code': 'annual', 'name': 'Tahunan(Cuti)'},
        'start_date': '2026-05-11',
        'end_date': '2026-05-13',
        'total_working_days': 3,
        'duration_label': '3 hari kerja',
        'reason': 'Keperluan keluarga.',
        'status': 'approved',
        'status_label': 'Disetujui',
        'can_cancel': false,
      },
      'current_leave_return_date': '2026-05-18',
      'last_leave': null,
      'next_leave': null,
      'approved_this_year': 2,
      'pending_count': 1,
      'rejected_this_year': 0,
    },
    'requests': [
      {
        'id': 10,
        'leave_type': {'id': 1, 'code': 'annual', 'name': 'Tahunan(Cuti)'},
        'start_date': '2026-08-14',
        'end_date': '2026-08-14',
        'total_working_days': 1,
        'duration_label': '1 hari kerja',
        'reason': 'Extend long weekend.',
        'status': 'pending',
        'status_label': 'Menunggu Approval',
        'can_cancel': true,
      },
    ],
    'approval_queue': [
      {
        'id': 11,
        'requester_name': 'Maya Ops',
        'requester_department': 'Operations',
        'replacement_user_id': 22,
        'replacement_name': 'Backup Staff',
        'replacement_department': 'Operations',
        'leave_type': {'id': 1, 'code': 'annual', 'name': 'Tahunan(Cuti)'},
        'start_date': '2026-08-18',
        'end_date': '2026-08-18',
        'total_working_days': 1,
        'duration_label': '1 hari kerja',
        'reason': 'Keperluan keluarga.',
        'status': 'pending',
        'status_label': 'Menunggu Approval',
        'can_cancel': false,
        'current_pending_step': {
          'id': 201,
          'step_number': 2,
          'step_key': 'replacement_approval',
          'step_name': 'Persetujuan Staff Pengganti',
          'actor_type': 'user',
          'actor_value': '22',
          'actor_label': 'Backup Staff',
          'status': 'pending',
          'config_snapshot': {'requires_signature': true},
        },
        'approval_steps': [
          {
            'id': 200,
            'step_number': 1,
            'step_key': 'requester_signature',
            'step_name': 'Tanda Tangan Pemohon',
            'actor_type': 'requester',
            'actor_label': 'Maya Ops',
            'status': 'approved',
            'config_snapshot': {'requires_signature': true},
          },
          {
            'id': 201,
            'step_number': 2,
            'step_key': 'replacement_approval',
            'step_name': 'Persetujuan Staff Pengganti',
            'actor_type': 'user',
            'actor_value': '22',
            'actor_label': 'Backup Staff',
            'status': 'pending',
            'config_snapshot': {'requires_signature': true},
          },
        ],
        'available_actions': [
          {
            'action': 'approve_leave',
            'step_number': 2,
            'step_name': 'Persetujuan Staff Pengganti',
            'actor_label': 'Backup Staff',
            'label': 'Setujui sebagai Staff Pengganti',
            'reject_label': 'Tolak',
            'notes_placeholder': 'Tambahkan catatan jika diperlukan.',
            'requires_signature': true,
            'can_reject': true,
          },
        ],
        'pdf_preview_url': '/api/leaves/requests/11/pdf/stream',
        'pdf_download_url': '/api/leaves/requests/11/pdf/download',
        'can_preview_pdf': true,
      },
    ],
    'upcoming_requests': [],
    'holidays': [
      {
        'id': 3,
        'date': '2026-08-17',
        'name': 'Proklamasi Kemerdekaan',
        'type': 'national',
        'is_joint_leave': false,
      },
    ],
    'calendar': [],
    'long_weekends': [
      {
        'title': 'Ambil 1 hari cuti untuk long weekend',
        'holiday_name': 'Proklamasi Kemerdekaan',
        'start_date': '2026-08-14',
        'end_date': '2026-08-17',
        'days_off': 4,
        'leave_days_needed': 1,
        'suggested_leave_dates': ['2026-08-14'],
      },
    ],
    'can_approve': true,
  };
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}
