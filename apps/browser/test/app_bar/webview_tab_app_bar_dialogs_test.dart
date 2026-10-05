// webview_tab_app_bar_dialogs 리팩터용 회귀 그물.
//
// 다이얼로그들은 _WebViewTabAppBarState 의 private extension 이라 직접 부를 수
// 없다. 그래서 실제 사용자 경로 — 앱바의 ⋮ 메뉴에서 항목을 고른다 — 로 연다.
// 고정하는 것은 "메뉴 항목이 그 다이얼로그를 열고, 목록 항목 수가 모델과 같다".
// 추출 중 타일이 조용히 사라지면 여기서 잡힌다.
//
// 기존 test/app_bar/webview_tab_app_bar_test.dart 는 건드리지 않는다. 이 파일이
// 그 옆에 붙는 추가 그물이다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/webview_tab_app_bar.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/custom_popup_menu_item.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/favorite_model.dart';
import 'package:infocutter_app/models/web_archive_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/popup_menu_actions.dart';
import 'package:provider/provider.dart';

Widget _host(BrowserModel browserModel) {
  final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
    ..tabIndex = 0;
  final windowModel = WindowModel()..addTab(webViewModel);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BrowserModel>.value(value: browserModel),
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

/// ⋮ 메뉴를 열고 주어진 action 항목을 고른다. 항목 라벨은 로케일에 따라 달라지므로
/// PopupMenuItem 의 value 로 찾는다.
Future<void> _chooseMenuAction(WidgetTester tester, String action) async {
  // ⋮ 아이콘은 앱바에 둘 이상 있을 수 있어 아이콘이 아니라 버튼 타입으로 찾는다.
  await tester.tap(find.byType(PopupMenuButton<String>));
  await _settle(tester);

  final item = find.byWidgetPredicate(
    (widget) => widget is CustomPopupMenuItem<String> && widget.value == action,
  );
  expect(item, findsOneWidget);

  await tester.tap(item);
  await _settle(tester);
}

/// 앱바에는 끝나지 않는 애니메이션(로고)이 있어 pumpAndSettle 이 타임아웃한다.
/// 고정 시간만큼 펌프해서 다이얼로그 전환만 끝낸다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

FavoriteModel _favorite(String url, String title) =>
    FavoriteModel(url: WebUri(url), title: title);

WebArchiveModel _webArchive(String url, String title) => WebArchiveModel(
      timestamp: DateTime(2026, 3, 4),
      url: WebUri(url),
      title: title,
      path: '/tmp/$title.webarchive',
    );

void main() {
  testWidgets('즐겨찾기 다이얼로그가 즐겨찾기 수만큼 타일을 낸다', (tester) async {
    final browserModel = BrowserModel()
      ..addFavorite(_favorite('https://a.test/', '가'))
      ..addFavorite(_favorite('https://b.test/', '나'));

    await tester.pumpWidget(_host(browserModel));
    await _settle(tester);

    await _chooseMenuAction(tester, PopupMenuActions.FAVORITES);

    expect(find.byType(AlertDialog), findsOneWidget);
    // 즐겨찾기 2개 → ListTile 2개. 추출로 타일이 사라지면 여기서 잡힌다.
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('가'), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
  });

  testWidgets('즐겨찾기가 없으면 다이얼로그는 비어 있다', (tester) async {
    await tester.pumpWidget(_host(BrowserModel()));
    await _settle(tester);

    await _chooseMenuAction(tester, PopupMenuActions.FAVORITES);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('웹 아카이브 다이얼로그가 아카이브 수만큼 타일을 낸다', (tester) async {
    final browserModel = BrowserModel()
      ..addWebArchive('https://a.test/', _webArchive('https://a.test/', '보관가'))
      ..addWebArchive('https://b.test/', _webArchive('https://b.test/', '보관나'));

    await tester.pumpWidget(_host(browserModel));
    await _settle(tester);

    await _chooseMenuAction(tester, PopupMenuActions.WEB_ARCHIVES);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('보관가'), findsOneWidget);
    expect(find.text('보관나'), findsOneWidget);
  });

  testWidgets('히스토리 다이얼로그는 webViewController 가 없으면 빈 채로 뜬다', (tester) async {
    await tester.pumpWidget(_host(BrowserModel()));
    await _settle(tester);

    await _chooseMenuAction(tester, PopupMenuActions.HISTORY);

    // getCopyBackForwardList() 를 부를 컨트롤러가 없다 → snapshot 에 데이터가
    // 없어 빈 Container 만 남는다. 그래도 예외 없이 열려야 한다.
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('즐겨찾기 타일의 X 를 누르면 그 즐겨찾기가 사라진다', (tester) async {
    final browserModel = BrowserModel()
      ..addFavorite(_favorite('https://a.test/', '가'))
      ..addFavorite(_favorite('https://b.test/', '나'));

    await tester.pumpWidget(_host(browserModel));
    await _settle(tester);

    await _chooseMenuAction(tester, PopupMenuActions.FAVORITES);
    await tester.tap(find.byIcon(Icons.close).first);
    await _settle(tester);

    expect(browserModel.favorites.length, 1);
    expect(browserModel.favorites.single.title, '나');
  });
}
