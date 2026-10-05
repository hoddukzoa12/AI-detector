// webview_tab_app_bar 보강 그물 (기존 webview_tab_app_bar_test.dart 는 수정 금지,
// 이 파일이 별도 보강).
//
// 고정하는 것:
//  - 앱바가 예외 없이 렌더되고 AppBar 하나만 낸다
//  - ⋮ 메뉴 항목 수가 PopupMenuActions.choices 와 1:1 (+ 퀵액션 행 1)
//  - 주소창이 모델의 url 변화를 따라간다 (포커스가 없을 때)
// 메뉴 구성이나 _syncSearchController 분기가 추출 중 어긋나면 여기서 잡힌다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/webview_tab_app_bar.dart';
import 'package:infocutter_app/custom_popup_menu_item.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/popup_menu_actions.dart';
import 'package:provider/provider.dart';

/// 앱바에는 끝나지 않는 애니메이션(로고)이 있어 pumpAndSettle 이 타임아웃한다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _host(WebViewModel webViewModel) {
  final windowModel = WindowModel()..addTab(webViewModel);

  return MultiProvider(
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
          children: const [
            WebViewTabAppBar(),
            Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('앱바가 예외 없이 렌더된다', (tester) async {
    final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
      ..tabIndex = 0;

    await tester.pumpWidget(_host(webViewModel));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
  });

  testWidgets('⋮ 메뉴 항목 수가 PopupMenuActions.choices 와 일치한다', (tester) async {
    final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
      ..tabIndex = 0;

    await tester.pumpWidget(_host(webViewModel));
    await _settle(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await _settle(tester);

    // 메뉴 = 퀵액션 행 1개 + choices 각각 1개. 항목을 의도적으로 더하거나 뺐다면
    // 같은 커밋에서 이 기대값도 함께 고친다.
    expect(
      find.byType(CustomPopupMenuItem<String>),
      findsNWidgets(PopupMenuActions.choices.length + 1),
    );
    // value 가 붙은 항목(=선택 가능한 action)은 choices 와 1:1.
    final actionItems = tester
        .widgetList<CustomPopupMenuItem<String>>(
          find.byType(CustomPopupMenuItem<String>),
        )
        .where((item) => item.value != null)
        .map((item) => item.value)
        .toList();
    expect(actionItems, PopupMenuActions.choices);
  });

  testWidgets('주소창이 모델의 url 변화를 따라간다', (tester) async {
    final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
      ..tabIndex = 0;

    await tester.pumpWidget(_host(webViewModel));
    await _settle(tester);

    var editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'https://example.com/');

    webViewModel.url = WebUri('https://other.test/page');
    await tester.pump();

    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'https://other.test/page');
  });

  testWidgets('url 이 null 이 되면 주소창이 비워진다', (tester) async {
    final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
      ..tabIndex = 0;

    await tester.pumpWidget(_host(webViewModel));
    await _settle(tester);

    webViewModel.url = null;
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '');
  });
}
