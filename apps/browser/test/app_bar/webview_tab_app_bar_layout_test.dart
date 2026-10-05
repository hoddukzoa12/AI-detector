// 앱바 레이아웃 회귀 그물.
//
// 세 가지를 못 박는다.
//   1. 상태바 인셋 — AppBar 는 primary 가 기본 true 라 스스로 SafeArea 를
//      먹는다. 누가 primary:false 를 켜거나 MediaQuery 를 지우면 주소창이
//      시계 밑에 붙는다. 반대로 SafeArea 를 덧대면 인셋이 두 배가 된다.
//      둘 다 이 테스트가 잡는다.
//   2. leading 폭 — 하드코딩 130 은 데스크탑 4버튼 기준이라 모바일에서
//      주소창을 90 만큼 민다.
//   3. `⋮` 와 탭 카운터의 접근 가능한 이름(tooltip).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/browser_app_bar.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:provider/provider.dart';

const double _statusBarHeight = 47.0;

Widget _host({
  required BrowserModel browserModel,
  required WebViewModel webViewModel,
  required WindowModel windowModel,
}) {
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: _statusBarHeight),
        ),
        child: child!,
      ),
      home: Scaffold(
        appBar: BrowserAppBar(),
        body: const SizedBox.expand(key: Key('body')),
      ),
    ),
  );
}

({BrowserModel browser, WebViewModel webView, WindowModel window}) _models({
  bool homePageEnabled = false,
}) {
  final browserModel = BrowserModel();
  browserModel.updateSettings(
    browserModel.getSettings()..homePageEnabled = homePageEnabled,
  );
  final webViewModel = WebViewModel(url: WebUri('https://example.com/'))
    ..tabIndex = 0;
  final windowModel = WindowModel()..addTab(webViewModel);
  return (browser: browserModel, webView: webViewModel, window: windowModel);
}

void main() {
  // Util.isMobile() 은 defaultTargetPlatform 을 본다. variant 로 세팅해야
  // 프레임워크가 테스트 끝에 원복까지 해 준다.
  final iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

  testWidgets('앱바는 상태바 인셋만큼만 내려온다 (없어도, 두 번 들어가도 실패)', (tester) async {
    final models = _models();

    await tester.pumpWidget(
      _host(
        browserModel: models.browser,
        webViewModel: models.webView,
        windowModel: models.window,
      ),
    );
    await tester.pumpAndSettle();

    final appBarRect = tester.getRect(find.byType(AppBar));
    expect(appBarRect.top, 0.0);
    // 상태바 인셋 + 툴바 한 벌. 인셋이 빠지면 56, 두 번 들어가면 150.
    expect(appBarRect.height, kToolbarHeight + _statusBarHeight);

    // 주소창 텍스트는 상태바 아래에서 시작한다.
    final fieldRect = tester.getRect(find.byType(EditableText));
    expect(fieldRect.top, greaterThanOrEqualTo(_statusBarHeight));

    // 본문은 앱바 아래에서 시작한다 — 앱바가 본문을 덮지 않는다.
    final bodyRect = tester.getRect(find.byKey(const Key('body')));
    expect(bodyRect.top, greaterThanOrEqualTo(appBarRect.bottom));
  }, variant: iosOnly);

  testWidgets('모바일 leading 폭은 홈 버튼 한 개 몫만 잡는다', (tester) async {
    final models = _models(homePageEnabled: true);

    await tester.pumpWidget(
      _host(
        browserModel: models.browser,
        webViewModel: models.webView,
        windowModel: models.window,
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    // 홈 버튼 하나의 실제 폭(Material 최소 터치 타깃 48) + 좌우 margin 10.
    // 데스크탑용 130 을 그대로 쓰면 실패한다.
    expect(appBar.leadingWidth, kMinInteractiveDimension + 10.0);
    expect(appBar.titleSpacing, 0.0);
  }, variant: iosOnly);

  testWidgets('홈 버튼이 없으면 leading 슬롯을 아예 잡지 않는다', (tester) async {
    final models = _models();

    await tester.pumpWidget(
      _host(
        browserModel: models.browser,
        webViewModel: models.webView,
        windowModel: models.window,
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.leading, isNull);
    expect(appBar.leadingWidth, isNull);
    expect(appBar.titleSpacing, 10.0);
  }, variant: iosOnly);

  testWidgets('앱바의 ⋮ 는 하나뿐이고 브라우저 메뉴라는 이름을 갖는다', (tester) async {
    final models = _models();

    await tester.pumpWidget(
      _host(
        browserModel: models.browser,
        webViewModel: models.webView,
        windowModel: models.window,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppBar)),
    );
    final menuButton = tester.widget<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    );
    expect(menuButton.tooltip, l10n.a11yMoreMenu);
  }, variant: iosOnly);

  testWidgets('탭 카운터에 tooltip 이 붙는다', (tester) async {
    final models = _models();

    await tester.pumpWidget(
      _host(
        browserModel: models.browser,
        webViewModel: models.webView,
        windowModel: models.window,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppBar)),
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == l10n.a11yTabCount,
      ),
      findsOneWidget,
    );
  }, variant: iosOnly);
}
