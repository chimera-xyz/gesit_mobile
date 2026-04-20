import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/app.dart';

void main() {
  testWidgets('shows opening screen before login shell', (tester) async {
    await tester.pumpWidget(const GesitApp());

    expect(find.byKey(const ValueKey('opening-logo')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke SiGESIT'), findsOneWidget);
    expect(find.text('Internal Access'), findsOneWidget);
    expect(find.text('Masuk ke Workspace'), findsOneWidget);
    expect(find.text('atau'), findsOneWidget);
    expect(find.text('Butuh Bantuan Akses'), findsOneWidget);
  });
}
