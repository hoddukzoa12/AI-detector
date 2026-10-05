import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:infocutter_app/empty_tab.dart';
import 'package:infocutter_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native app launches and opens a start-page request', (
    tester,
  ) async {
    app.main(const []);

    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(EmptyTab), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    final searchField = find.byType(TextField).last;
    await tester.enterText(searchField, 'example.com');
    await tester.tap(find.byIcon(Icons.search).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(EmptyTab), findsNothing);
  });
}
