import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_pick_tab.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_block_rule_repository.dart';

void main() {
  final t1 = DateTime.utc(2026);
  final t2 = DateTime.utc(2026, 2);

  SelectionCard sessionCard(String id, String selector) => SelectionCard(
        id: id,
        name: id,
        selector: selector,
        frameScope: null,
        matchCount: 1,
      );

  ActiveSiteState state({
    String? profileId = 'P',
    List<StoredRule> rules = const [],
  }) {
    final cards = profileId == null || rules.isEmpty
        ? const <SavedCard>[]
        : [
            SavedCard(
              cardId: 'A',
              cardName: '광고',
              createdAt: rules.first.createdAt,
              enabled: true,
              frameScopes: rules.map((r) => r.frameScope).toList(),
              mode: rules.last.mode,
              ruleCount: rules.length,
              rules: rules,
            ),
          ];
    return ActiveSiteState(
      activeProfileId: profileId,
      activeProfileName: 'site',
      cardCount: cards.length,
      cards: cards,
      enabledExceptionCount: 0,
      enabledSelectorCount: rules.length,
      exceptionCount: 0,
      globalEnabled: true,
      hostname: 'example.com',
      matchers: const ['example.com'],
      profileEnabled: true,
      rules: const [],
      selectorCount: rules.length,
      updatedAt: t1,
      url: Uri.parse('https://example.com'),
    );
  }

  StoredRule rule(String selector,
          {DateTime? at, RuleMode mode = RuleMode.hide}) =>
      StoredRule(
        cardId: 'A',
        cardName: '광고',
        selector: selector,
        mode: mode,
        createdAt: at ?? t1,
      );

  ActiveSiteState oneRule(String selector) => state(rules: [rule(selector)]);

  Future<void> pump(
    WidgetTester tester, {
    required FakeBlockRuleRepository repo,
    List<SelectionCard> session = const [],
    Size size = const Size(440, 900),
  }) async {
    await tester.pumpWidget(
      ListenableProvider<BlockRuleRepository>.value(
        value: repo,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(
              body: InfocutterPickTab(
                url: Uri.parse('https://example.com'),
                session: session,
                onRemoveSessionCard: (_) {},
                onRefineSessionCard: (_, __) {},
                onRenameSessionCard: (_, __) {},
                onApplySession: () {},
                onCancelSession: () {},
                onRulesChanged: () async {},
                onPreviewStoredRule: (_) async {},
                onSetSessionCardDepth: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('narrow screen collapses the applied section by default',
      (tester) async {
    final repo = FakeBlockRuleRepository(oneRule('.ad'));
    await pump(tester, repo: repo);
    expect(find.textContaining('이미 숨긴 것'), findsOneWidget);
    expect(find.text('.ad'), findsNothing);
    await tester.tap(find.textContaining('이미 숨긴 것'));
    await tester.pumpAndSettle();
    expect(find.text('.ad'), findsOneWidget);
  });

  testWidgets('wide screen expands the applied section by default',
      (tester) async {
    final repo = FakeBlockRuleRepository(oneRule('.ad'));
    await pump(tester, repo: repo, size: const Size(900, 900));
    expect(find.text('.ad'), findsOneWidget);
  });

  testWidgets('wide screen header tap collapses the applied section',
      (tester) async {
    // T1: override the responsive default (expanded) by tapping the header.
    final repo = FakeBlockRuleRepository(oneRule('.ad'));
    await pump(tester, repo: repo, size: const Size(900, 900));
    expect(find.text('.ad'), findsOneWidget);
    await tester.tap(find.textContaining('이미 숨긴 것'));
    await tester.pumpAndSettle();
    expect(find.text('.ad'), findsNothing);
  });

  testWidgets('selector edit commits via updateStoredRule with a fresh target',
      (tester) async {
    final repo = FakeBlockRuleRepository(oneRule('.ad'));
    await pump(tester, repo: repo, size: const Size(900, 900));
    await tester.enterText(find.widgetWithText(TextField, '.ad'), '.ad .inner');
    await tester.tap(find.widgetWithText(TextField, '광고'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdate?.profileId, 'P');
    expect(repo.lastUpdate?.targetRule.createdAt, t1);
    expect(repo.lastUpdate?.selector, '.ad .inner');
  });

  testWidgets('footer apply button gates on a non-empty session',
      (tester) async {
    // T2: empty session hides the apply footer; one staged card shows it.
    final emptyRepo = FakeBlockRuleRepository(oneRule('.ad'));
    await pump(tester, repo: emptyRepo);
    expect(find.byType(FilledButton), findsNothing);

    final repo = FakeBlockRuleRepository(oneRule('.ad'));
    await pump(tester, repo: repo, session: [sessionCard('s1', '.banner')]);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.textContaining('전체 적용'), findsOneWidget);
  });

  testWidgets('null active profile hides the applied section', (tester) async {
    // T3: no active profile → no applied section, but staging hint still shows.
    final repo = FakeBlockRuleRepository(state(profileId: null));
    await pump(tester, repo: repo, size: const Size(900, 900));
    expect(find.textContaining('이미 숨긴 것'), findsNothing);
    expect(find.textContaining('지금 고르는 중'), findsOneWidget);
    expect(find.text('페이지에서 지울 요소를 클릭해 담으세요'), findsOneWidget);
  });

  testWidgets('mode toggle and delete re-resolve the fresh target',
      (tester) async {
    // T4: two rules so the per-rule delete icon is shown; both edit paths must
    // route through _withFreshRule and hit the fake with the fresh target.
    final repo = FakeBlockRuleRepository(
      state(rules: [rule('.ad', at: t1), rule('.promo', at: t2)]),
    );
    await pump(tester, repo: repo, size: const Size(900, 900));

    // Toggle the first rule's mode (hide -> unhide).
    await tester.tap(find.byIcon(Icons.visibility_off).first);
    await tester.pumpAndSettle();
    expect(repo.lastUpdate?.profileId, 'P');
    expect(repo.lastUpdate?.targetRule.createdAt, t1);
    expect(repo.lastUpdate?.mode, RuleMode.unhide);

    // Delete the second rule.
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(repo.lastRemove?.profileId, 'P');
    expect(repo.lastRemove?.targetRule.createdAt, t2);
  });
}
