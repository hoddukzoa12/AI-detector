import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_rule_manager.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';

import 'fakes/fake_block_rule_repository.dart';

void main() {
  final t0 = DateTime.utc(2026);

  final cardA = ProfileCard(
    id: 'cardA',
    name: '광고카드',
    enabled: true,
    createdAt: t0,
    updatedAt: t0,
  );

  final ruleA = StoredRule(
    cardId: 'cardA',
    cardName: '광고카드',
    selector: '.ad',
    mode: RuleMode.hide,
    createdAt: t0,
  );

  final profileA = RuleProfile(
    id: 'A',
    name: 'A프로필',
    enabled: true,
    matchers: ['https://example.com/*'],
    cards: [cardA],
    rules: [ruleA],
    updatedAt: t0,
  );

  final cardB = ProfileCard(
    id: 'cardB',
    name: 'B카드',
    enabled: true,
    createdAt: t0,
    updatedAt: t0,
  );

  final ruleB = StoredRule(
    cardId: 'cardB',
    cardName: 'B카드',
    selector: '.banner',
    mode: RuleMode.hide,
    createdAt: t0,
  );

  final profileB = RuleProfile(
    id: 'B',
    name: 'B프로필',
    enabled: true,
    matchers: ['https://example.com/*'],
    cards: [cardB],
    rules: [ruleB],
    updatedAt: t0,
  );

  // The fake's buildActiveSiteState will return activeProfileId='A' because
  // profileA is first in the list and matches 'example.com'.
  late FakeBlockRuleRepository fake;

  setUp(() {
    fake = FakeBlockRuleRepository(
      // positional _state is only used when _profiles is empty; supply a
      // minimal placeholder (won't be used since profiles is non-empty).
      ActiveSiteState(
        activeProfileId: 'A',
        activeProfileName: 'A프로필',
        cardCount: 0,
        cards: const [],
        enabledExceptionCount: 0,
        enabledSelectorCount: 0,
        exceptionCount: 0,
        globalEnabled: true,
        hostname: 'example.com',
        matchers: const ['https://example.com/*'],
        profileEnabled: true,
        rules: const [],
        selectorCount: 0,
        updatedAt: t0,
        url: Uri.parse('https://example.com/'),
      ),
      profiles: [profileA, profileB],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ListenableProvider<BlockRuleRepository>.value(
        value: fake,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: InfocutterRuleManager(
                currentSiteOnly: true,
                url: Uri.parse('https://example.com/'),
                repository: fake,
                onRulesChanged: () async {},
                onPreviewRule: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'active profile (A) hides its cards and shows hint; other profile (B) shows cards normally',
    (tester) async {
      await pump(tester);

      // Expand Profile A
      await tester.tap(find.text('A프로필'));
      await tester.pumpAndSettle();

      // Active profile's cards must NOT be shown
      expect(find.text('광고카드'), findsNothing);
      // Hint text must appear
      expect(
        find.text("이 프로필의 카드는 '고르기' 탭에서 편집합니다"),
        findsOneWidget,
      );

      // Expand Profile B
      await tester.tap(find.text('B프로필'));
      await tester.pumpAndSettle();

      // Other profile's cards must still be shown
      expect(find.text('B카드'), findsOneWidget);
    },
  );
}
