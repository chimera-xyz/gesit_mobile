import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/connection_status_controller.dart';
import 'package:gesit_app/src/widgets/connection_status_gate.dart';

void main() {
  group('ConnectionLostScreen', () {
    testWidgets('renders the offline PNG mascot and copy', (tester) async {
      await _pumpConnectionLostScreen(tester, issue: ConnectionIssue.offline);

      expect(find.text('Kamu sedang offline'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(
        _firstAssetImageName(tester),
        'assets/illustrations/mascot-offline-sad.png',
      );
      expect(_hasMaterialColor(tester, const Color(0xFFF8F6F7)), isTrue);
    });

    testWidgets('renders the server unavailable PNG mascot and copy', (
      tester,
    ) async {
      await _pumpConnectionLostScreen(
        tester,
        issue: ConnectionIssue.serverUnavailable,
      );

      expect(find.text('Koneksi ke server terputus'), findsOneWidget);
      expect(find.text('SERVER'), findsOneWidget);
      expect(
        _firstAssetImageName(tester),
        'assets/illustrations/mascot-server-confused.png',
      );
      expect(_hasMaterialColor(tester, const Color(0xFFFFFEFE)), isTrue);
    });
  });
}

Future<void> _pumpConnectionLostScreen(
  WidgetTester tester, {
  required ConnectionIssue issue,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ConnectionLostScreen(issue: issue, checking: false, onRetry: () {}),
    ),
  );
}

String? _firstAssetImageName(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image).first);
  final provider = image.image;
  return provider is AssetImage ? provider.assetName : null;
}

bool _hasMaterialColor(WidgetTester tester, Color color) {
  return tester
      .widgetList<Material>(find.byType(Material))
      .any((material) => material.color == color);
}
