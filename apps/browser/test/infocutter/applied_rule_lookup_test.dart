import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/applied_rule_lookup.dart';
import 'package:infocutter_app/infocutter/models.dart';

StoredRule _rule(String cardId, String selector, DateTime at) => StoredRule(
      cardId: cardId,
      cardName: 'c',
      selector: selector,
      mode: RuleMode.hide,
      createdAt: at,
    );

SavedCard _card(String cardId, List<StoredRule> rules) => SavedCard(
      cardId: cardId,
      cardName: 'c',
      createdAt: rules.first.createdAt,
      enabled: true,
      frameScopes: const [null],
      mode: RuleMode.hide,
      ruleCount: rules.length,
      rules: rules,
    );

void main() {
  final t1 = DateTime.utc(2026);
  final t2 = DateTime.utc(2026, 1, 2);

  test('finds the rule by cardId + createdAt regardless of selector value', () {
    final cards = [
      _card('A', [_rule('A', '.old', t1), _rule('A', '.other', t2)]),
    ];
    final found = findRuleByIdentity(cards, 'A', t1);
    expect(found, isNotNull);
    expect(found!.createdAt, t1);
    expect(found.selector, '.old');
  });

  test('returns null when no card/createdAt matches', () {
    final cards = [
      _card('A', [_rule('A', '.x', t1)]),
    ];
    expect(findRuleByIdentity(cards, 'B', t1), isNull);
    expect(findRuleByIdentity(cards, 'A', t2), isNull);
  });
}
