import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/connection_status_controller.dart';

void main() {
  group('ConnectionStatusController', () {
    test(
      'reports online when the backend health endpoint is reachable',
      () async {
        var internetProbeCalled = false;
        final controller = ConnectionStatusController(
          backendProbe: (_, _) async => true,
          internetProbe: (_) async {
            internetProbeCalled = true;
            return false;
          },
          checkInterval: const Duration(hours: 1),
        );
        addTearDown(controller.dispose);

        controller.start('http://localhost:8000');
        final issue = await controller.checkNow();

        expect(issue, ConnectionIssue.none);
        expect(controller.hasIssue, isFalse);
        expect(internetProbeCalled, isFalse);
      },
    );

    test(
      'reports offline when backend and public internet are unreachable',
      () async {
        final controller = ConnectionStatusController(
          backendProbe: (_, _) async => false,
          internetProbe: (_) async => false,
          checkInterval: const Duration(hours: 1),
        );
        addTearDown(controller.dispose);

        controller.start('http://localhost:8000');
        final issue = await controller.checkNow();

        expect(issue, ConnectionIssue.offline);
        expect(controller.issue, ConnectionIssue.offline);
      },
    );

    test(
      'reports server unavailable when public internet works but backend fails',
      () async {
        final controller = ConnectionStatusController(
          backendProbe: (_, _) async => false,
          internetProbe: (_) async => true,
          checkInterval: const Duration(hours: 1),
        );
        addTearDown(controller.dispose);

        controller.start('http://localhost:8000');
        final issue = await controller.checkNow();

        expect(issue, ConnectionIssue.serverUnavailable);
        expect(controller.issue, ConnectionIssue.serverUnavailable);
      },
    );
  });
}
