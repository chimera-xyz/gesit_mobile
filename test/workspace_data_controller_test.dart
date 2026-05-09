import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_session_controller.dart';
import 'package:gesit_app/src/data/gesit_api_client.dart';
import 'package:gesit_app/src/data/workspace_data_controller.dart';
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
