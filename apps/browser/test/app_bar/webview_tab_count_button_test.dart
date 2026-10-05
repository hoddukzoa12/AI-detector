// webview_tab_count_button 리팩터용 회귀 그물.
//
// 이 버튼은 (1) 열린 탭 수를 숫자로 보여주고 (2) 탭하면 탭 스크롤러를 열고
// (3) 길게 누르면 탭 메뉴를 띄워 선택을 콜백으로 흘린다. 메뉴 구성이나
// 선택 분기가 추출 중에 어긋나도 analyze 는 초록이다. 그 구멍을 막는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/webview_tab_count_button.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/tab_popup_menu_actions.dart';
import 'package:provider/provider.dart';

WindowModel _windowWithTabs(int count) {
  final windowModel = WindowModel();
  for (var i = 0; i < count; i++) {
    windowModel.addTab(WebViewModel(url: WebUri('https://example.com/$i')));
  }
  return windowModel;
}

Widget _host({
  required BrowserModel browserModel,
  required WindowModel windowModel,
  VoidCallback? onAddNewTab,
  VoidCallback? onAddNewIncognitoTab,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BrowserModel>.value(value: browserModel),
      ChangeNotifierProvider<WindowModel>.value(value: windowModel),
    ],
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: WebViewTabCountButton(
            onAddNewTab: onAddNewTab ?? () {},
            onAddNewIncognitoTab: onAddNewIncognitoTab ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('열린 탭 수를 숫자로 보여준다', (tester) async {
    final windowModel = _windowWithTabs(3);

    await tester.pumpWidget(
      _host(browserModel: BrowserModel(), windowModel: windowModel),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('탭이 늘면 숫자도 따라 는다', (tester) async {
    final windowModel = _windowWithTabs(1);

    await tester.pumpWidget(
      _host(browserModel: BrowserModel(), windowModel: windowModel),
    );
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    windowModel.addTab(WebViewModel(url: WebUri('https://example.com/new')));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('탭하면 탭 스크롤러가 열린다', (tester) async {
    final browserModel = BrowserModel();
    final windowModel = _windowWithTabs(2);
    expect(browserModel.showTabScroller, isFalse);

    await tester.pumpWidget(
      _host(browserModel: browserModel, windowModel: windowModel),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(browserModel.showTabScroller, isTrue);
  });

  testWidgets('탭이 하나도 없으면 탭해도 스크롤러가 열리지 않는다', (tester) async {
    final browserModel = BrowserModel();
    final windowModel = _windowWithTabs(0);

    await tester.pumpWidget(
      _host(browserModel: browserModel, windowModel: windowModel),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(browserModel.showTabScroller, isFalse);
  });

  testWidgets('길게 누르면 탭 메뉴가 항목 수만큼 뜬다', (tester) async {
    final windowModel = _windowWithTabs(2);

    await tester.pumpWidget(
      _host(browserModel: BrowserModel(), windowModel: windowModel),
    );
    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // TabPopupMenuActions.choices 와 1:1. 항목을 의도적으로 더하거나 뺐다면
    // 같은 커밋에서 이 기대값도 함께 고친다.
    expect(
      find.byType(PopupMenuItem<String>),
      findsNWidgets(TabPopupMenuActions.choices.length),
    );
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('메뉴에서 새 탭을 고르면 onAddNewTab 이 호출된다', (tester) async {
    var addCount = 0;
    var incognitoCount = 0;
    final windowModel = _windowWithTabs(2);

    await tester.pumpWidget(
      _host(
        browserModel: BrowserModel(),
        windowModel: windowModel,
        onAddNewTab: () => addCount++,
        onAddNewIncognitoTab: () => incognitoCount++,
      ),
    );
    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(addCount, 1);
    expect(incognitoCount, 0);
  });

  testWidgets('메뉴에서 시크릿 탭을 고르면 onAddNewIncognitoTab 이 호출된다', (tester) async {
    var addCount = 0;
    var incognitoCount = 0;
    final windowModel = _windowWithTabs(2);

    await tester.pumpWidget(
      _host(
        browserModel: BrowserModel(),
        windowModel: windowModel,
        onAddNewTab: () => addCount++,
        onAddNewIncognitoTab: () => incognitoCount++,
      ),
    );
    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    expect(incognitoCount, 1);
    expect(addCount, 0);
  });
}
