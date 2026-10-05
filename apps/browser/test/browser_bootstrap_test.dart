import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/browser.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.dalsoop.infocutter.intent_data'),
      (call) async {
        if (call.method == 'getIntentData') return null;
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.dalsoop.infocutter.intent_data'),
      null,
    );
  });

  testWidgets('Browser shows bootstrap splash before restore finishes',
      (tester) async {
    final browserModel = BrowserModel();
    final windowModel = WindowModel();
    final webViewModel = WebViewModel();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BrowserModel>.value(value: browserModel),
          ChangeNotifierProvider<WindowModel>.value(value: windowModel),
          ChangeNotifierProvider<WebViewModel>.value(value: webViewModel),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Browser(),
        ),
      ),
    );

    // 첫 프레임: 복원 전 스플래시 (흰 빈 화면 아님)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // restore + mocked getIntentData 완료 후 EmptyTab 등 렌더
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
