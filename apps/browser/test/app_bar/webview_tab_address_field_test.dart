// 주소창에는 신원(자물쇠)과 주소만 남는다. 인포커터 동작 버튼은 하단
// 액션바(browser_bottom_action_bar_test.dart)로 내려갔다.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/app_bar/webview_tab_address_field.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:provider/provider.dart';

Widget _host({
  required TextEditingController controller,
  required FocusNode focusNode,
}) {
  final windowModel = WindowModel();
  windowModel.addTab(WebViewModel(url: WebUri('https://www.example.com/page')));

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BrowserModel>.value(value: BrowserModel()),
      ChangeNotifierProvider<WebViewModel>.value(value: WebViewModel()),
      ChangeNotifierProvider<WindowModel>.value(value: windowModel),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: Scaffold(
        body: WebViewTabAddressField(
          searchController: controller,
          focusNode: focusNode,
          onShowUrlInfo: () {},
          onOpenUrlInNewTab: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('carries no Infocutter action buttons any more', (tester) async {
    await tester.pumpWidget(_host(
      controller: TextEditingController(text: 'https://www.example.com/page'),
      focusNode: FocusNode(),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.content_cut), findsNothing);
    expect(find.byIcon(Icons.text_fields), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('collapses the address while unfocused', (tester) async {
    await tester.pumpWidget(_host(
      controller: TextEditingController(text: 'https://www.example.com/page'),
      focusNode: FocusNode(),
    ));
    await tester.pump();

    expect(find.byType(InputDecorator), findsWidgets);
    final rendered = tester.widget<Text>(
      find.byWidgetPredicate((widget) => widget is Text && widget.data == null),
    );
    expect(rendered.textSpan?.toPlainText(), 'example.com/page');
  });

  testWidgets('shows the full URL and selects it once focused', (tester) async {
    final controller =
        TextEditingController(text: 'https://www.example.com/page');
    final focusNode = FocusNode();

    await tester
        .pumpWidget(_host(controller: controller, focusNode: focusNode));
    await tester.pump();

    await tester.tap(find.byType(WebViewTabAddressField));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(controller.text, 'https://www.example.com/page');
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, controller.text.length);
  });

  testWidgets('keeps the security icon reachable as a prefix', (tester) async {
    await tester.pumpWidget(_host(
      controller: TextEditingController(text: 'https://www.example.com/page'),
      focusNode: FocusNode(),
    ));
    await tester.pump();

    // isSecure 가 false 인 기본 모델이므로 info_outline 이 뜬다.
    expect(find.byIcon(Icons.info_outline), findsWidgets);
  });
}
