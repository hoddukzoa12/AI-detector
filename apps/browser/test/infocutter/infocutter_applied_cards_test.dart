import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_applied_cards.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

StoredRule _rule(String cardId, String selector, DateTime at,
        {RuleMode mode = RuleMode.hide, String? frame}) =>
    StoredRule(
      cardId: cardId,
      cardName: 'c',
      selector: selector,
      mode: mode,
      createdAt: at,
      frameScope: frame,
    );

SavedCard _card(String cardId, String name, List<StoredRule> rules,
        {bool enabled = true}) =>
    SavedCard(
      cardId: cardId,
      cardName: name,
      createdAt: rules.first.createdAt,
      enabled: enabled,
      frameScopes: rules.map((r) => r.frameScope).toSet().toList(),
      mode: rules.last.mode,
      ruleCount: rules.length,
      rules: rules,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<SavedCard> cards,
  void Function(String cardId, String name)? onRenameCard,
  void Function(String cardId, bool enabled)? onToggleCard,
  void Function(String cardId)? onDeleteCard,
  void Function(String cardId, DateTime createdAt, String selector)?
      onEditRuleSelector,
  void Function(String cardId, DateTime createdAt)? onToggleRuleMode,
  void Function(String cardId, DateTime createdAt)? onDeleteRule,
  void Function(StoredRule rule)? onPreviewRule,
}) async {
  await tester.binding.setSurfaceSize(const Size(440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: InfocutterAppliedCards(
            cards: cards,
            onRenameCard: onRenameCard ?? (_, __) {},
            onToggleCard: onToggleCard ?? (_, __) {},
            onDeleteCard: onDeleteCard ?? (_) {},
            onEditRuleSelector: onEditRuleSelector ?? (_, __, ___) {},
            onToggleRuleMode: onToggleRuleMode ?? (_, __) {},
            onDeleteRule: onDeleteRule ?? (_, __) {},
            onPreviewRule: onPreviewRule ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final t1 = DateTime.utc(2026);
  final t2 = DateTime.utc(2026, 1, 2);

  testWidgets('renders applied card name and each rule selector',
      (tester) async {
    await _pump(tester, cards: [
      _card('A', '광고', [_rule('A', '.ad', t1), _rule('A', '.banner', t2)]),
    ]);
    expect(find.text('.ad'), findsOneWidget);
    expect(find.text('.banner'), findsOneWidget);
    expect(find.widgetWithText(TextField, '광고'), findsOneWidget);
  });

  testWidgets('toggling the card switch fires onToggleCard', (tester) async {
    String? toggledId;
    bool? toggledValue;
    await _pump(
      tester,
      cards: [
        _card('A', '광고', [_rule('A', '.ad', t1)])
      ],
      onToggleCard: (id, v) {
        toggledId = id;
        toggledValue = v;
      },
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(toggledId, 'A');
    expect(toggledValue, false);
  });

  testWidgets('editing a rule selector commits on blur with stable identity',
      (tester) async {
    String? cardId;
    DateTime? at;
    String? selector;
    await _pump(
      tester,
      cards: [
        _card('A', '광고', [_rule('A', '.ad', t1), _rule('A', '.banner', t2)]),
      ],
      onEditRuleSelector: (c, a, s) {
        cardId = c;
        at = a;
        selector = s;
      },
    );
    await tester.enterText(find.widgetWithText(TextField, '.ad'), '.ad .inner');
    await tester.tap(find.widgetWithText(TextField, '.banner'));
    await tester.pumpAndSettle();
    expect(cardId, 'A');
    expect(at, t1);
    expect(selector, '.ad .inner');
  });

  testWidgets('mode icon toggles via onToggleRuleMode', (tester) async {
    DateTime? at;
    await _pump(
      tester,
      cards: [
        _card('A', '광고', [_rule('A', '.ad', t1)])
      ],
      onToggleRuleMode: (_, a) => at = a,
    );
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();
    expect(at, t1);
  });

  testWidgets('frame scope shows the main-frame label when null',
      (tester) async {
    await _pump(tester, cards: [
      _card('A', '광고', [_rule('A', '.ad', t1)])
    ]);
    expect(find.text('메인 프레임'), findsOneWidget);
  });

  testWidgets('single-rule card hides the per-rule delete button',
      (tester) async {
    await _pump(tester, cards: [
      _card('A', '광고', [_rule('A', '.ad', t1)])
    ]);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('multi-rule card shows a delete button per rule and fires it',
      (tester) async {
    String? cardId;
    DateTime? at;
    await _pump(
      tester,
      cards: [
        _card('A', '광고', [_rule('A', '.ad', t1), _rule('A', '.banner', t2)]),
      ],
      onDeleteRule: (c, a) {
        cardId = c;
        at = a;
      },
    );
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(cardId, 'A');
    expect(at, t1);
  });

  testWidgets('unhide rule renders visibility icon and toggles its mode',
      (tester) async {
    DateTime? at;
    await _pump(
      tester,
      cards: [
        _card('A', '광고', [_rule('A', '.ad', t1, mode: RuleMode.unhide)]),
      ],
      onToggleRuleMode: (_, a) => at = a,
    );
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsNothing);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();
    expect(at, t1);
  });

  testWidgets('didUpdateWidget resyncs fields when not focused',
      (tester) async {
    await _pump(tester, cards: [
      _card('A', '광고', [_rule('A', '.ad', t1)])
    ]);
    expect(find.widgetWithText(TextField, '광고'), findsOneWidget);
    expect(find.widgetWithText(TextField, '.ad'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InfocutterAppliedCards(
              cards: [
                _card('A', '배너', [_rule('A', '.ad .inner', t1)]),
              ],
              onRenameCard: (_, __) {},
              onToggleCard: (_, __) {},
              onDeleteCard: (_) {},
              onEditRuleSelector: (_, __, ___) {},
              onToggleRuleMode: (_, __) {},
              onDeleteRule: (_, __) {},
              onPreviewRule: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '배너'), findsOneWidget);
    expect(find.widgetWithText(TextField, '.ad .inner'), findsOneWidget);
  });
}
