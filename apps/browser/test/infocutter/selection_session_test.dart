import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';

SelectionCard card(String id, String selector, {String? scope}) =>
    SelectionCard(
      id: id,
      name: selector,
      selector: selector,
      frameScope: scope,
      matchCount: 1,
    );

void main() {
  test('toggle adds a new selector and removes a matching one', () {
    var s = <SelectionCard>[];
    s = sessionToggle(s, card('a', '.ad'));
    s = sessionToggle(s, card('b', '.promo'));
    expect(s.map((c) => c.selector), ['.ad', '.promo']);

    // toggling an entry with the same selector+scope removes it
    s = sessionToggle(s, card('c', '.ad'));
    expect(s.map((c) => c.selector), ['.promo']);
  });

  test('same selector in a different frame scope is a distinct card', () {
    var s = <SelectionCard>[];
    s = sessionToggle(s, card('a', '.ad'));
    s = sessionToggle(s, card('b', '.ad', scope: 'https://frame/x'));
    expect(s, hasLength(2));
  });

  test('removeById drops the matching card', () {
    final s = [card('a', '.ad'), card('b', '.promo')];
    expect(sessionRemove(s, 'a').map((c) => c.id), ['b']);
    expect(sessionRemove(s, 'missing'), s);
  });

  test('updateSelector edits one card in place', () {
    final s = [card('a', '.ad'), card('b', '.promo')];
    final out = sessionUpdateSelector(s, 'a', '.ad .inner', matchCount: 3);
    expect(out.firstWhere((c) => c.id == 'a').selector, '.ad .inner');
    expect(out.firstWhere((c) => c.id == 'a').matchCount, 3);
    expect(out.firstWhere((c) => c.id == 'b').selector, '.promo');
  });

  test('rename keeps the old name when blank', () {
    final s = [card('a', '.ad')];
    expect(sessionRename(s, 'a', 'Ads').single.name, 'Ads');
    expect(sessionRename(s, 'a', '   ').single.name, '.ad');
  });

  test('toJson exposes the card fields', () {
    final j = card('a', '.ad', scope: 'https://f/x').toJson();
    expect(j, containsPair('id', 'a'));
    expect(j, containsPair('selector', '.ad'));
    expect(j, containsPair('frameScope', 'https://f/x'));
    expect(j, containsPair('matchCount', 1));
  });

  test(
      'toJson includes depthOptions as a list of maps with label/selector/matchCount',
      () {
    const c = SelectionCard(
      id: 'x',
      name: 'test',
      selector: '.ad',
      frameScope: null,
      matchCount: 1,
      depthOptions: [
        CardDepthOption(label: '현재 요소', selector: '.ad', matchCount: 1),
        CardDepthOption(label: '부모 1단계', selector: 'div.card', matchCount: 5),
      ],
    );
    final j = c.toJson();
    final opts = j['depthOptions'] as List;
    expect(opts, hasLength(2));
    expect((opts[1] as Map)['selector'], 'div.card');
    expect((opts[1] as Map)['label'], '부모 1단계');
    expect((opts[1] as Map)['matchCount'], 5);
    expect(j, containsPair('depthIndex', 0));
  });

  test('isOverlyBroadSelector flags page-wide selectors', () {
    for (final s in ['html', 'body', ':root', '*', ' HTML ', 'body ', '']) {
      expect(isOverlyBroadSelector(s), isTrue, reason: 'should flag "$s"');
    }
    for (final s in ['.ad', 'div.card', 'article', '#main .item']) {
      expect(isOverlyBroadSelector(s), isFalse, reason: 'should allow "$s"');
    }
  });

  test('alternatives round-trip through copyWith and toJson', () {
    const c = SelectionCard(
      id: 'a',
      name: 'Ads',
      selector: '.ad',
      frameScope: null,
      matchCount: 2,
      alternatives: ['.ad', '.banner'],
    );
    expect(c.alternatives, ['.ad', '.banner']);
    // copyWith keeps alternatives unless overridden
    expect(c.copyWith(selector: '.banner').alternatives, ['.ad', '.banner']);
    expect(c.toJson(), containsPair('alternatives', ['.ad', '.banner']));
    // default is an empty list
    expect(card('b', '.x').alternatives, isEmpty);
  });

  group('depth options', () {
    SelectionCard cardWithDepth() => const SelectionCard(
          id: 'a',
          name: '광고',
          selector: '.ad',
          frameScope: null,
          matchCount: 1,
          depthOptions: [
            CardDepthOption(
                label: '현재 요소',
                selector: '.ad',
                matchCount: 1,
                alternatives: ['.ad']),
            CardDepthOption(
                label: '부모 1단계',
                selector: 'div.card',
                matchCount: 3,
                alternatives: ['div.card']),
          ],
        );

    test(
        'sessionSetDepthIndex swaps selector/matchCount/depthIndex/alternatives',
        () {
      final out = sessionSetDepthIndex([cardWithDepth()], 'a', 1);
      expect(out.single.selector, 'div.card');
      expect(out.single.matchCount, 3);
      expect(out.single.depthIndex, 1);
      expect(out.single.alternatives, ['div.card']);
    });

    test('sessionSetDepthIndex ignores an out-of-range index', () {
      final out = sessionSetDepthIndex([cardWithDepth()], 'a', 5);
      expect(out.single.selector, '.ad');
      expect(out.single.depthIndex, 0);
    });

    test('sessionSetDepthIndex ignores an unknown id', () {
      final out = sessionSetDepthIndex([cardWithDepth()], 'zzz', 1);
      expect(out.single.selector, '.ad');
    });
  });
}
