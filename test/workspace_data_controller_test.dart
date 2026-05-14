import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/workspace_data_controller.dart';
import 'package:gesit_app/src/models/app_models.dart';
import 'package:gesit_app/src/models/session_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkspaceDataController actionable tasks lane', () {
    late AppSessionController sessionController;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      sessionController = AppSessionController(apiClient: GesitApiClient());
    });

    tearDown(() {
      sessionController.dispose();
    });

    test(
      'hides fallback actionable lane for users without approval permission',
      () async {
        await sessionController.syncSession(_buildSession(), notify: false);
        final controller = WorkspaceDataController(
          sessionController: sessionController,
        );
        addTearDown(controller.dispose);

        expect(controller.pendingActionCount, greaterThan(0));
        expect(controller.canShowActionableTasksLane, isFalse);
      },
    );

    test(
      'shows actionable lane when backend assigns an approval action',
      () async {
        await sessionController.syncSession(_buildSession(), notify: false);
        final controller = WorkspaceDataController(
          sessionController: sessionController,
          apiClient: GesitApiClient(
            httpClient: MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path, '/api/form-submissions');

              return _jsonResponse({
                'submissions': [
                  _submissionJson(
                    id: 42,
                    availableActions: [
                      {
                        'action': 'approve',
                        'step_name': 'Approval IT',
                        'label': 'Setujui',
                      },
                    ],
                  ),
                ],
              });
            }),
          ),
        );
        addTearDown(controller.dispose);

        await controller.refreshTasks();

        expect(controller.pendingActionCount, 1);
        expect(controller.canShowActionableTasksLane, isTrue);
      },
    );

    test('maps procurement items as structured submission fields', () async {
      await sessionController.syncSession(_buildSession(), notify: false);
      final controller = WorkspaceDataController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/form-submissions');

            return _jsonResponse({
              'submissions': [
                _submissionJson(
                  id: 43,
                  formFields: [
                    {
                      'id': 'items',
                      'label': 'Daftar Barang / Software',
                      'type': 'procurement_items',
                    },
                  ],
                  formData: {
                    'items': [
                      {
                        'description': 'SSD 512GB',
                        'quantity': 1,
                        'unit_price': 1800000,
                        'amount': 1800000,
                        'specifications': 'NVMe Gen 4 untuk workstation.',
                      },
                    ],
                  },
                ),
              ],
            });
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.refreshTasks();

      expect(controller.tasksError, isNull);
      final task = controller.tasks.single;
      final field = task.formFields.single;

      expect(field.label, 'Daftar Barang / Software');
      expect(field.isProcurementItems, isTrue);
      expect(field.value, contains('SSD 512GB'));
      expect(field.value, contains('1.800.000'));
      expect(field.procurementItems, hasLength(1));
      expect(field.procurementItems.single.description, 'SSD 512GB');
      expect(field.procurementItems.single.quantity, 1);
      expect(field.procurementItems.single.unitPrice, 1800000);
      expect(
        field.procurementItems.single.specifications,
        'NVMe Gen 4 untuk workstation.',
      );
    });

    test('uses backend form category when adapting forms', () async {
      await sessionController.syncSession(_buildSession(), notify: false);
      final controller = WorkspaceDataController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/forms');

            return _jsonResponse({
              'forms': [
                {
                  'id': 12,
                  'slug': 'reimbursement-biaya-berobat',
                  'name': 'Reimbursement Biaya Berobat',
                  'description': 'Pengajuan penggantian biaya berobat.',
                  'is_active': true,
                  'submissions_count': 0,
                  'form_config': {
                    'category': 'Reimbursement',
                    'fields': [
                      {
                        'id': 'amount',
                        'label': 'Jumlah (Rp.)',
                        'type': 'number',
                        'required': true,
                      },
                      {
                        'id': 'receipt_attachment',
                        'label': 'Lampiran Kwitansi/Resep',
                        'type': 'file',
                        'required': true,
                        'multiple': true,
                        'max_files': 5,
                        'accepted_mimes': ['pdf', 'jpg', 'jpeg', 'png'],
                      },
                    ],
                  },
                  'workflow': {
                    'name': 'Reimbursement Biaya Berobat',
                    'workflow_config': {
                      'steps': [
                        {'name': 'Review Accounting', 'actor_type': 'role'},
                        {
                          'name': 'Persetujuan Direktur HR',
                          'actor_type': 'role',
                        },
                      ],
                    },
                  },
                },
              ],
            });
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.refreshForms();

      expect(controller.forms, hasLength(1));
      expect(controller.forms.single.category, 'Reimbursement');
      expect(controller.forms.single.title, 'Reimbursement Biaya Berobat');
      expect(controller.forms.single.etaLabel, '2 tahap approval');
      final attachmentField = controller.forms.single.fields.last;
      expect(attachmentField.allowsMultipleFiles, isTrue);
      expect(attachmentField.maxFiles, 5);
      expect(attachmentField.acceptedFileTypes, contains('pdf'));
    });

    test('adds pending leave approvals to actionable tasks', () async {
      await sessionController.syncSession(
        _buildApproverSession(),
        notify: false,
      );
      expect(sessionController.session!.user.canApproveLeave, isTrue);
      final requestedPaths = <String>[];
      final controller = WorkspaceDataController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            requestedPaths.add(request.url.path);

            if (request.url.path == '/api/form-submissions') {
              return _jsonResponse({'submissions': <Map<String, dynamic>>[]});
            }

            if (request.url.path == '/api/leaves') {
              return _jsonResponse(_leaveDashboardPayload());
            }

            return http.Response('Not found', 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.refreshTasks();

      expect(controller.tasksError, isNull);
      expect(requestedPaths, contains('/api/leaves'));
      final task = controller.tasks.single;

      expect(controller.pendingActionCount, 1);
      expect(controller.canShowActionableTasksLane, isTrue);
      expect(task.isLeave, isTrue);
      expect(task.lane, TaskLane.actionable);
      expect(task.title, 'Tahunan(Cuti)');
      expect(task.requester, 'Maya Ops');
      expect(task.workflowLabel, 'Approval Cuti');
      expect(task.summary, contains('18 Mei 2026'));
      expect(task.requiresSignature, isTrue);
      expect(task.currentApprovalStepId, 201);
      expect(
        task.availableActions.single.label,
        'Setujui sebagai Staff Pengganti',
      );
      expect(task.availableActions.single.rejectLabel, 'Tolak');
      expect(task.timelineSteps, hasLength(2));
      expect(
        task.pdfPreviewUrl,
        'https://gesit.example.com/api/leaves/requests/11/pdf/stream',
      );
    });

    test('loads leave approval tasks without submission permission', () async {
      await sessionController.syncSession(
        _buildLeaveOnlyApproverSession(),
        notify: false,
      );
      final session = sessionController.session!;
      final requestedPaths = <String>[];
      final controller = WorkspaceDataController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            requestedPaths.add(request.url.path);

            if (request.url.path == '/api/leaves') {
              return _jsonResponse(_leaveDashboardPayload());
            }

            return http.Response('Forbidden', 403);
          }),
        ),
      );
      addTearDown(controller.dispose);

      expect(session.user.canApproveLeave, isFalse);
      expect(session.user.canAccessTasks, isTrue);
      expect(session.shellModules, contains(AppShellModule.tasks));

      await controller.refreshTasks();

      expect(controller.tasksError, isNull);
      expect(requestedPaths, ['/api/leaves']);
      expect(controller.tasks.single.isLeave, isTrue);
      expect(controller.canShowActionableTasksLane, isTrue);
    });

    test('approves leave task with step signature', () async {
      await sessionController.syncSession(
        _buildLeaveOnlyApproverSession(),
        notify: false,
      );
      final requestedPaths = <String>[];
      final controller = WorkspaceDataController(
        sessionController: sessionController,
        apiClient: GesitApiClient(
          browserManagedCookies: false,
          httpClient: MockClient((request) async {
            requestedPaths.add('${request.method} ${request.url.path}');

            if (request.method == 'GET' && request.url.path == '/api/leaves') {
              return _jsonResponse(_leaveDashboardPayload());
            }

            if (request.method == 'POST' &&
                request.url.path ==
                    '/api/leaves/approval-steps/201/signature') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['signature_data'], 'data:image/png;base64,abc123');
              return _jsonResponse({
                'success': true,
                'signature': {'id': 77},
              });
            }

            if (request.method == 'POST' &&
                request.url.path == '/api/leaves/requests/11/approve') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['signature_id'], '77');
              expect(body['reviewer_notes'], 'Catatan aman.');
              return _jsonResponse({
                'success': true,
                'request': {
                  ..._leaveRequestPayload(),
                  'status': 'approved',
                  'status_label': 'Disetujui',
                  'available_actions': <Map<String, dynamic>>[],
                },
              });
            }

            return http.Response('Not found', 404);
          }),
        ),
      );
      addTearDown(controller.dispose);

      await controller.refreshTasks();
      final result = await controller.approveTask(
        task: controller.tasks.single,
        notes: 'Catatan aman.',
        signatureDataUrl: 'data:image/png;base64,abc123',
      );

      expect(result.workflowStatus, TaskSubmissionStatus.leaveApproved);
      expect(
        requestedPaths,
        contains('POST /api/leaves/approval-steps/201/signature'),
      );
      expect(requestedPaths, contains('POST /api/leaves/requests/11/approve'));
    });
  });
}

AppSession _buildSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'employee-1',
      name: 'Employee',
      email: 'employee@example.com',
      roles: ['Employee'],
      permissions: ['view submissions', 'view forms'],
      department: 'IT',
    ),
    apiBaseUrl: 'https://gesit.example.com',
    cookies: const {'gesit_session': 'cookie-1'},
    rememberSession: true,
    authenticatedAt: DateTime.parse('2026-04-21T10:00:00.000Z'),
  );
}

AppSession _buildApproverSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'director-1',
      name: 'Director',
      email: 'director@example.com',
      roles: ['Operational Director'],
      permissions: [
        'view submissions',
        'view forms',
        'view leave dashboard',
        'approve leave requests',
      ],
      department: 'Operational',
    ),
    apiBaseUrl: 'https://gesit.example.com',
    cookies: const {'gesit_session': 'cookie-1'},
    rememberSession: true,
    authenticatedAt: DateTime.parse('2026-05-10T10:00:00.000Z'),
  );
}

AppSession _buildLeaveOnlyApproverSession() {
  return AppSession(
    user: const AuthenticatedUser(
      id: 'leave-approver-1',
      name: 'Leave Approver',
      email: 'leave.approver@example.com',
      roles: ['Employee'],
      permissions: ['view leave dashboard'],
      department: 'Operational',
    ),
    apiBaseUrl: 'https://gesit.example.com',
    cookies: const {'gesit_session': 'cookie-1'},
    rememberSession: true,
    authenticatedAt: DateTime.parse('2026-05-10T10:00:00.000Z'),
  );
}

Map<String, dynamic> _submissionJson({
  required int id,
  List<Map<String, dynamic>> availableActions = const [],
  List<Map<String, dynamic>> formFields = const [],
  Map<String, dynamic> formData = const <String, dynamic>{},
}) {
  return {
    'id': id,
    'current_status': 'pending_it',
    'created_at': '2026-04-21T10:15:00.000Z',
    'user': {'name': 'Employee'},
    'form': {
      'id': 7,
      'name': 'Form Internal',
      'workflow': {
        'name': 'Workflow Approval',
        'workflow_config': {
          'steps': [
            {'name': 'Approval IT', 'actor_type': 'role'},
          ],
        },
      },
      'form_config': {'fields': formFields},
    },
    'available_actions': availableActions,
    'approval_steps': <Map<String, dynamic>>[],
    'form_data': formData,
  };
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
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
    'balance': {
      'year': 2026,
      'leave_type': {'id': 1, 'code': 'annual', 'name': 'Tahunan(Cuti)'},
      'entitled_days': 12,
      'carried_over_days': 0,
      'adjusted_days': 0,
      'used_days': 0,
      'pending_days': 0,
      'remaining_days': 12,
      'expires_at': '2026-12-31',
    },
    'summary': {
      'last_leave': null,
      'next_leave': null,
      'approved_this_year': 0,
      'pending_count': 0,
      'rejected_this_year': 0,
    },
    'requests': <Map<String, dynamic>>[],
    'approval_queue': [_leaveRequestPayload()],
    'upcoming_requests': <Map<String, dynamic>>[],
    'holidays': <Map<String, dynamic>>[],
    'calendar': <Map<String, dynamic>>[],
    'long_weekends': <Map<String, dynamic>>[],
    'can_approve': true,
  };
}

Map<String, dynamic> _leaveRequestPayload() {
  return {
    'id': 11,
    'requester_name': 'Maya Ops',
    'requester_department': 'Operations',
    'replacement_user_id': 22,
    'replacement_name': 'Backup Staff',
    'replacement_department': 'Operations',
    'leave_type': {'id': 1, 'code': 'annual', 'name': 'Tahunan(Cuti)'},
    'start_date': '2026-05-18',
    'end_date': '2026-05-18',
    'total_working_days': 1,
    'duration_label': '1 hari kerja',
    'reason': 'Keperluan keluarga.',
    'status': 'pending',
    'status_label': 'Menunggu Approval',
    'can_cancel': false,
    'current_pending_actor_label': 'Backup Staff',
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
        'approver': {'name': 'Maya Ops'},
        'status': 'approved',
        'notes': 'Diajukan dan ditandatangani pemohon.',
        'approved_at': '2026-05-10T10:15:00.000Z',
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
        'notes_required': false,
        'can_reject': true,
        'requires_signature': true,
        'can_edit_form': false,
      },
    ],
    'pdf_preview_url': '/api/leaves/requests/11/pdf/stream',
    'pdf_download_url': '/api/leaves/requests/11/pdf/download',
    'can_preview_pdf': true,
    'submitted_at': '2026-05-10T10:15:00.000Z',
  };
}
