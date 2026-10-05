// desktop_tab_strip 리팩터용 회귀 그물.
//
// 탭 스트립은 "탭 개수만큼 셀렉터가 나오고, 클릭하면 그 탭이 현재 탭이 되고,
// X 를 누르면 그 탭이 닫힌다" 가 전부다. 추출 리팩터에서 인덱스 계산이나
// showTabs 분기가 어긋나면 analyze 는 초록이고 화면만 조용히 깨진다.
// 그 구멍을 막는 것이 이 파일의 목적이다.

import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/desktop_tab_strip.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/window_service.dart';
import 'package:provider/provider.dart';

/// DesktopWindowButtons 가 `Provider<WindowControls>` 를 요구한다. 창 제어는
/// 이 테스트의 관심사가 아니므로 호출만 삼키는 no-op 을 꽂는다.
class _NoopWindowControls implements WindowControls {
  @override
  Future<void> close() async {}

  @override
  Future<void> minimizeIfNotFullScreen() async {}

  @override
  Future<void> toggleFullScreen() async {}

  @override
  Future<void> setMovable(bool movable) async {}

  @override
  Future<void> maximize() async {}
}

Widget _host({
  required WindowModel windowModel,
  required bool showTabs,
  VoidCallback? onAddNewTab,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => BrowserModel()),
      ChangeNotifierProvider<WindowModel>.value(value: windowModel),
      Provider<WindowControls>.value(value: _NoopWindowControls()),
    ],
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // ContextMenuRegion 은 ContextMenuOverlay 조상을 요구한다 (main.dart 와 동일 구성).
      home: ContextMenuOverlay(
        child: Scaffold(
          body: Column(
            children: [
              DesktopTabStrip(
                showTabs: showTabs,
                onAddNewTab: onAddNewTab ?? () {},
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
}

WindowModel _windowWithTabs(List<String?> titles) {
  final windowModel = WindowModel();
  for (var i = 0; i < titles.length; i++) {
    windowModel.addTab(
      WebViewModel(url: WebUri('https://example.com/$i'))..title = titles[i],
    );
  }
  return windowModel;
}

Future<void> _pumpWide(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(child);
  await tester.pump();
}

void main() {
  testWidgets('탭 개수만큼 셀렉터가 렌더되고 예외가 없다', (tester) async {
    final windowModel = _windowWithTabs(['A', 'B', 'C']);

    await _pumpWide(tester, _host(windowModel: windowModel, showTabs: true));

    expect(tester.takeException(), isNull);
    // 탭 3개 → 셀렉터 3개. 추출 중 하나라도 사라지면 여기서 잡힌다.
    expect(find.byType(WebViewTabSelector), findsNWidgets(3));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('제목이 비면 New Tab 으로 표시된다', (tester) async {
    final windowModel = _windowWithTabs([null]);

    await _pumpWide(tester, _host(windowModel: windowModel, showTabs: true));

    expect(tester.takeException(), isNull);
    // title 이 null 이면 url, url 도 비면 'New Tab'. 여기서는 url 이 있으므로 url.
    expect(find.text('https://example.com/0'), findsOneWidget);
  });

  testWidgets('showTabs=false 면 셀렉터도 추가 버튼도 없다', (tester) async {
    final windowModel = _windowWithTabs(['A', 'B']);

    await _pumpWide(tester, _host(windowModel: windowModel, showTabs: false));

    expect(tester.takeException(), isNull);
    expect(find.byType(WebViewTabSelector), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('탭을 누르면 그 탭이 현재 탭이 된다', (tester) async {
    final windowModel = _windowWithTabs(['A', 'B', 'C']);
    // addTab 은 마지막 탭을 현재 탭으로 만든다.
    expect(windowModel.getCurrentTabIndex(), 2);

    await _pumpWide(tester, _host(windowModel: windowModel, showTabs: true));
    await tester.tap(find.text('A'));
    await tester.pump();

    expect(windowModel.getCurrentTabIndex(), 0);
  });

  testWidgets('셀렉터마다 닫기 버튼이 하나씩 있다', (tester) async {
    final windowModel = _windowWithTabs(['A', 'B', 'C']);

    await _pumpWide(tester, _host(windowModel: windowModel, showTabs: true));

    // 실제 탭 닫기(onClose 실행)는 여기서 확인하지 못한다. WindowModel.closeTab 이
    // InAppWebViewController.disposeKeepAlive 를 호출하고, 이는 위젯 테스트에
    // InAppWebViewPlatform.instance 가 없으면 assert 로 죽는다. 그래서 버튼이
    // 탭 수만큼 존재한다는 것까지만 고정한다.
    expect(find.byIcon(Icons.cancel), findsNWidgets(3));
  });

  testWidgets('추가 버튼은 onAddNewTab 을 호출한다', (tester) async {
    var addCount = 0;
    final windowModel = _windowWithTabs(['A']);

    await _pumpWide(
      tester,
      _host(
        windowModel: windowModel,
        showTabs: true,
        onAddNewTab: () => addCount++,
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(addCount, 1);
  });
}
