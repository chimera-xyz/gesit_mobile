import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/models/session_models.dart';

void main() {
  group('AppSession.bottomNavigationModules', () {
    test('uses meeting in the former forms slot when meeting is available', () {
      final session = _buildSession(
        permissions: const ['view submissions', 'view forms'],
      );

      expect(session.bottomNavigationModules, const [
        AppShellModule.home,
        AppShellModule.tasks,
        AppShellModule.meeting,
        AppShellModule.chat,
        AppShellModule.profile,
      ]);
      expect(session.shellModules, contains(AppShellModule.forms));
    });

    test('omits forms from the bottom nav even when forms are accessible', () {
      final session = _buildSession(permissions: const ['view forms']);

      expect(session.bottomNavigationModules, const [
        AppShellModule.home,
        AppShellModule.meeting,
        AppShellModule.chat,
        AppShellModule.profile,
      ]);
      expect(session.shellModules, contains(AppShellModule.forms));
    });
  });
}

AppSession _buildSession({required List<String> permissions}) {
  return AppSession(
    user: AuthenticatedUser(
      id: '1',
      name: 'GESIT User',
      email: 'user@example.com',
      roles: const ['employee'],
      permissions: permissions,
    ),
    apiBaseUrl: 'http://127.0.0.1:8000',
    cookies: const {},
    rememberSession: true,
    authenticatedAt: DateTime(2026, 5, 18),
  );
}
