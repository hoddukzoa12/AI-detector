import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/app_bar/browser_bottom_action_bar.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:provider/provider.dart';

Widget _host(WindowModel windowModel, WebViewModel sharedModel) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => BrowserModel()),
      ChangeNotifierProvider<WebViewModel>.value(value: sharedModel),
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
      home: const Scaffold(
        body: SizedBox(),
        bottomNavigationBar: BrowserBottomActionBar(),
      ),
    ),
  );
}

({WindowModel window, WebViewModel shared, WebViewModel tab}) _models() {
  final windowModel = WindowModel();
  final tabModel = WebViewModel(url: WebUri('https://example.com/page'));
  windowModel.addTab(tabModel);
  return (
    window: windowModel,
    shared: WebViewModel(url: WebUri('https://example.com/page')),
    tab: tabModel,
  );
}

/// 플랫폼 override 는 테스트 본문이 끝나기 전에 반드시 되돌려야 한다
/// (flutter_test 가 본문 종료 시점에 foundation debug 변수를 검사한다).
Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('renders on mobile', (tester) async {
    await _onPlatform(TargetPlatform.iOS, () async {
      final models = _models();
      await tester.pumpWidget(_host(models.window, models.shared));
      await tester.pump();

      expect(find.byType(BottomAppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.content_cut), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  testWidgets('renders nothing on desktop', (tester) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      final models = _models();
      await tester.pumpWidget(_host(models.window, models.shared));
      await tester.pump();

      expect(find.byType(BottomAppBar), findsNothing);
      expect(find.byIcon(Icons.content_cut), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  testWidgets('button tooltips come from AppLocalizations', (tester) async {
    await _onPlatform(TargetPlatform.iOS, () async {
      final models = _models();
      await tester.pumpWidget(_host(models.window, models.shared));
      await tester.pump();

      final context = tester.element(find.byType(BrowserBottomActionBar));
      final l10n = AppLocalizations.of(context);

      for (final message in [
        l10n.a11yBack,
        l10n.a11yForward,
        l10n.infocutterPickBlockRemoveTab,
        l10n.infocutterKeywordBlockRemoveTab,
        l10n.infocutterAiRecommendRemoveTab,
        l10n.infocutterManageRemovedCategory,
      ]) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Tooltip && widget.message == message,
          ),
          findsOneWidget,
          reason: 'tooltip missing for "$message"',
        );
      }

      expect(find.bySemanticsLabel(l10n.a11yActionBar), findsOneWidget);
    });
  });

  testWidgets(
      'Infocutter buttons request panels on the CURRENT tab model, '
      'not the shared provider placeholder', (tester) async {
    await _onPlatform(TargetPlatform.iOS, () async {
      final models = _models();
      await tester.pumpWidget(_host(models.window, models.shared));
      await tester.pump();

      final currentTab = models.window.getCurrentWebViewModel()!;
      final expectations = <IconData, InfocutterPanelMode>{
        Icons.content_cut: InfocutterPanelMode.block,
        Icons.text_fields: InfocutterPanelMode.keyword,
        Icons.auto_awesome: InfocutterPanelMode.ai,
      };

      for (final entry in expectations.entries) {
        currentTab.infocutterPanelRequest.value = null;

        await tester.tap(find.byIcon(entry.key));
        await tester.pump();

        expect(currentTab.infocutterPanelRequest.value, entry.value);
      }

      expect(models.shared.infocutterPanelRequest.value, isNull);
    });
  });
}
