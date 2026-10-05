import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_block_rule_repository.dart';

SelectionCard _card(String id, String name, String selector, int matchCount) =>
    SelectionCard(
      id: id,
      name: name,
      selector: selector,
      frameScope: null,
      matchCount: matchCount,
    );

void main() {
  test('module registry covers every sidebar panel mode once', () {
    final registeredModes = infocutterModules.map((module) => module.mode);

    expect(registeredModes, unorderedEquals(InfocutterPanelMode.values));
    expect(registeredModes.toSet().length, InfocutterPanelMode.values.length);
    for (final mode in InfocutterPanelMode.values) {
      expect(infocutterModuleForMode(mode).mode, mode);
    }
  });

  testWidgets('block mode renders the staged session as numbered cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(
        mode: InfocutterPanelMode.block,
        session: [
          _card('a', '광고', 'article.card', 2),
          _card('b', '추천', '.reco', 5),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The scissors panel exposes both halves of hiding as tabs.
    expect(find.text('고르기'), findsOneWidget);
    expect(find.text('숨긴 목록'), findsOneWidget);
    // The "고르기" tab is the default and shows the staged session.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('article.card'), findsOneWidget);
    expect(find.text('.reco'), findsOneWidget);
    expect(find.text('전체 적용 (2)'), findsOneWidget);
  });

  testWidgets('sidebar header renders the app logo asset', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(mode: InfocutterPanelMode.block, session: const []),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/icon/icon.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('apply + cancel wire through to the session actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var applied = false;
    var cancelled = false;

    await tester.pumpWidget(
      _harness(
        mode: InfocutterPanelMode.block,
        session: [_card('a', '광고', 'article.card', 2)],
        onApplySession: () => applied = true,
        onCancelSession: () => cancelled = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('전체 적용 (1)'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(applied, isTrue);
    expect(cancelled, isTrue);
  });

  testWidgets('an empty block session shows the click-to-stage hint',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(mode: InfocutterPanelMode.block, session: const []),
    );
    await tester.pumpAndSettle();

    expect(find.text('페이지에서 지울 요소를 클릭해 담으세요'), findsOneWidget);
  });
}

Widget _harness({
  required InfocutterPanelMode mode,
  required List<SelectionCard> session,
  VoidCallback? onApplySession,
  VoidCallback? onCancelSession,
}) {
  return ListenableProvider<BlockRuleRepository>.value(
      // The 「고르기」 tab now renders InfocutterPickTab, which watches the
      // repository for the current-site applied rules. activeProfileId is null
      // here so the "이미 숨긴 것" section stays hidden and these tests keep
      // asserting only the staged-session behaviour.
      value: FakeBlockRuleRepository(_emptyActiveSiteState()),
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              InfocutterSidebar(
                data: InfocutterSidebarData(
                  mode: mode,
                  session: session,
                  url: Uri.parse('https://example.com/news/1'),
                ),
                actions: InfocutterSidebarActions(
                  onAnalyzeAiCurrentPage: () async => const <AiPageCandidate>[],
                  onApplySession: onApplySession ?? () {},
                  onCancelSession: onCancelSession ?? () {},
                  onCaptureDetectionEvidence: (_) async {},
                  onCaptureEvidence: () async {},
                  onClose: () {},
                  onNetworkFiltersChanged: () async {},
                  onPausePicker: () async {},
                  onPreviewStoredRule: (_) async {},
                  onRefineSessionCard: (_, __) {},
                  onRemoveSessionCard: (_) {},
                  onRenameSessionCard: (_, __) {},
                  onResumePicker: () async {},
                  onRulesChanged: () async {},
                  onSetSessionCardDepth: (_, __) {},
                  onStartBlockPicker: () async {},
                  onWatchChanged: () async {},
                ),
              ),
            ],
          ),
        ),
      ));
}

ActiveSiteState _emptyActiveSiteState() => ActiveSiteState(
      activeProfileId: null,
      activeProfileName: null,
      cardCount: 0,
      cards: const [],
      enabledExceptionCount: 0,
      enabledSelectorCount: 0,
      exceptionCount: 0,
      globalEnabled: true,
      hostname: 'example.com',
      matchers: const [],
      profileEnabled: true,
      rules: const [],
      selectorCount: 0,
      updatedAt: DateTime.utc(2026),
      url: Uri.parse('https://example.com/news/1'),
    );
