import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/selection_session_controller.dart';

void main() {
  late ValueNotifier<List<SelectionCard>> session;
  late List<List<SelectionCard>> repaints;
  late SelectionSessionController controller;
  var idSeq = 0;

  setUp(() {
    idSeq = 0;
    session = ValueNotifier<List<SelectionCard>>(const []);
    repaints = [];
    controller = SelectionSessionController(
      session: session,
      // count = length of the selector string, so assertions are deterministic
      countMatches: (selector) async => selector.length,
      repaintHighlights: (cards) async => repaints.add(cards),
      newCardId: (seq) => 'card-${idSeq++}',
    );
  });

  test('stage adds a numbered card with a computed match count + repaints',
      () async {
    await controller.stage(
      '.ad',
      name: 'Ads',
      options: const StageOptions(alternatives: ['.ad', '.x']),
    );
    expect(session.value, hasLength(1));
    final card = session.value.single;
    expect(card.selector, '.ad');
    expect(card.name, 'Ads');
    expect(card.matchCount, '.ad'.length);
    expect(card.alternatives, ['.ad', '.x']);
    expect(repaints.last, session.value);
  });

  test('staging an already-staged selector toggles it off', () async {
    await controller.stage('.ad', name: 'Ads');
    await controller.stage('.promo', name: 'Promo');
    expect(session.value.map((c) => c.selector), ['.ad', '.promo']);

    await controller.stage('.ad', name: 'Ads again');
    expect(session.value.map((c) => c.selector), ['.promo']);
  });

  test('blank selector is ignored', () async {
    await controller.stage('   ', name: 'x');
    expect(session.value, isEmpty);
    expect(repaints, isEmpty);
  });

  test('refine updates one card selector + recomputes the match count',
      () async {
    await controller.stage('.ad', name: 'Ads');
    final id = session.value.single.id;
    await controller.refine(id, '.ad .inner');
    expect(session.value.single.selector, '.ad .inner');
    expect(session.value.single.matchCount, '.ad .inner'.length);
  });

  test('rename updates the card name without a repaint', () async {
    await controller.stage('.ad', name: 'Ads');
    repaints.clear();
    controller.rename(session.value.single.id, 'Banners');
    expect(session.value.single.name, 'Banners');
    expect(repaints, isEmpty);
  });

  test('remove drops the card + repaints', () async {
    await controller.stage('.ad', name: 'Ads');
    final id = session.value.single.id;
    await controller.remove(id);
    expect(session.value, isEmpty);
    expect(repaints.last, isEmpty);
  });

  test('clear empties the session + repaints', () async {
    await controller.stage('.ad', name: 'Ads');
    await controller.clear();
    expect(session.value, isEmpty);
    expect(repaints.last, isEmpty);
  });

  test('apply saves every card, clears the session, repaints, returns applied',
      () async {
    await controller.stage('.ad', name: 'Ads');
    await controller.stage('.promo', name: 'Promo');
    final saved = <SelectionCard>[];

    final applied = await controller.apply((card) async => saved.add(card));

    expect(saved.map((c) => c.selector), ['.ad', '.promo']);
    expect(applied.map((c) => c.selector), ['.ad', '.promo']);
    expect(session.value, isEmpty);
    expect(repaints.last, isEmpty);
  });

  group('depth', () {
    test('stage stores depthOptions + depthIndex on the card', () async {
      await controller.stage(
        '.ad',
        name: '광고',
        options: StageOptions(depthOptions: const [
          CardDepthOption(
            label: '현재 요소',
            selector: '.ad',
            matchCount: 1,
            alternatives: ['.ad'],
          ),
          CardDepthOption(
            label: '부모 1단계',
            selector: 'div.card',
            matchCount: 3,
            alternatives: ['div.card'],
          ),
        ]),
      );
      expect(session.value, hasLength(1));
      final card = session.value.single;
      expect(card.depthOptions, hasLength(2));
      expect(card.depthIndex, 0);
    });

    test('setDepthIndex swaps selector/matchCount without calling countMatches',
        () async {
      await controller.stage(
        '.ad',
        name: '광고',
        options: StageOptions(depthOptions: const [
          CardDepthOption(
            label: '현재 요소',
            selector: '.ad',
            matchCount: 1,
            alternatives: ['.ad'],
          ),
          CardDepthOption(
            label: '부모 1단계',
            selector: 'div.card',
            matchCount: 3,
            alternatives: ['div.card'],
          ),
        ]),
      );

      // Record session state after stage(); setDepthIndex must not call countMatches.
      final sessionAfterStage = session.value;
      repaints.clear();

      // Rebuild the controller with a counting wrapper to track post-stage calls.
      // Instead, we capture calls via a fresh local counter and replace controller.
      // Simpler: reconstruct around a counter that starts at 0 for the new epoch.
      var extraCalls = 0;
      final trackingController = SelectionSessionController(
        session: session,
        countMatches: (selector) async {
          extraCalls++;
          return selector.length;
        },
        repaintHighlights: (cards) async => repaints.add(cards),
        newCardId: (seq) => 'card-${idSeq++}',
      );
      // session already has the staged card; id is captured before reset.
      final cardId = sessionAfterStage.single.id;

      await trackingController.setDepthIndex(cardId, 1);

      expect(extraCalls, 0, reason: 'setDepthIndex must not call countMatches');
      final updatedCard = session.value.single;
      expect(updatedCard.selector, 'div.card');
      expect(updatedCard.matchCount, 3);
      expect(updatedCard.depthIndex, 1);
      expect(repaints, isNotEmpty);
    });
  });
}
