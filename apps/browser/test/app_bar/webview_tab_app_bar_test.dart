import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/webview_tab_app_bar.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('address bar controller focuses and selects current url', (
    tester,
  ) async {
    final controller = WebViewTabAppBarController();
    final webViewModel = WebViewModel(
      url: WebUri('https://www.google.com/webhp'),
    )..tabIndex = 0;
    final windowModel = WindowModel()..addTab(webViewModel);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BrowserModel()),
          ChangeNotifierProvider<WebViewModel>.value(value: webViewModel),
          ChangeNotifierProvider<WindowModel>.value(value: windowModel),
          ListenableProvider<BlockRuleRepository>(
            create: (_) => InfocutterServiceBlockRuleRepository(
              InfocutterService(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                WebViewTabAppBar(controller: controller),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editableFinder = find.byType(EditableText);
    expect(editableFinder, findsOneWidget);
    var editable = tester.widget<EditableText>(editableFinder);
    expect(editable.focusNode.hasFocus, isFalse);

    controller.focusAddressField();
    await tester.pump();

    editable = tester.widget<EditableText>(editableFinder);
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, 'https://www.google.com/webhp');
    expect(
      editable.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 28),
    );
  });
}
