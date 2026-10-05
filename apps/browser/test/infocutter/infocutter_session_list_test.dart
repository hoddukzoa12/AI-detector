import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_session_list.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

SelectionCard _card(
  String id,
  String name,
  String selector,
  int matchCount, {
  List<String> alternatives = const [],
}) =>
    SelectionCard(
      id: id,
      name: name,
      selector: selector,
      frameScope: null,
      matchCount: matchCount,
      alternatives: alternatives,
    );

SelectionCard _cardWithDepth(
  String id,
  String name,
  String selector,
  int matchCount, {
  required List<CardDepthOption> depthOptions,
  int depthIndex = 0,
}) =>
    SelectionCard(
      id: id,
      name: name,
      selector: selector,
      frameScope: null,
      matchCount: matchCount,
      depthOptions: depthOptions,
      depthIndex: depthIndex,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<SelectionCard> session,
  void Function(String id)? onRemove,
  void Function(String id, String selector)? onRefine,
  void Function(String id, String name)? onRename,
  VoidCallback? onApply,
  VoidCallback? onCancel,
  void Function(String id, int index)? onSetDepth,
}) async {
  await tester.binding.setSurfaceSize(const Size(440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InfocutterSessionList(
          session: session,
          onRemove: onRemove ?? (_) {},
          onRefine: onRefine ?? (_, __) {},
          onRename: onRename ?? (_, __) {},
          onApply: onApply ?? () {},
          onCancel: onCancel ?? () {},
          onSetDepth: onSetDepth,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a single [InfocutterStagedCardTile] directly for depth-control tests.
Future<void> _pumpTile(
  WidgetTester tester, {
  required SelectionCard card,
  void Function(int index)? onSetDepth,
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
          child: Material(
            child: InfocutterStagedCardTile(
              index: 0,
              card: card,
              onRemove: () {},
              onRefine: (_) {},
              onRename: (_) {},
              onSetDepth: onSetDepth,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty session shows the click-to-stage hint', (tester) async {
    await _pump(tester, session: const []);
    expect(find.text('페이지에서 지울 요소를 클릭해 담으세요'), findsOneWidget);
  });

  testWidgets('renders a numbered card per staged selection', (tester) async {
    await _pump(tester, session: [
      _card('a', '광고', '.ad', 2),
      _card('b', '추천', '.reco', 5),
    ]);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('.ad'), findsOneWidget);
    expect(find.text('.reco'), findsOneWidget);
    expect(find.text('매치 2개'), findsOneWidget);
    expect(find.text('매치 5개'), findsOneWidget);
  });

  testWidgets('remove button fires onRemove with the card id', (tester) async {
    String? removed;
    await _pump(
      tester,
      session: [_card('a', '광고', '.ad', 2)],
      onRemove: (id) => removed = id,
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(removed, 'a');
  });

  testWidgets('apply button shows the count and fires onApply', (tester) async {
    var applied = false;
    await _pump(
      tester,
      session: [_card('a', '광고', '.ad', 2), _card('b', '추천', '.reco', 5)],
      onApply: () => applied = true,
    );
    expect(find.text('전체 적용 (2)'), findsOneWidget);
    await tester.tap(find.text('전체 적용 (2)'));
    await tester.pumpAndSettle();
    expect(applied, isTrue);
  });

  testWidgets('apply is disabled + warns when a card hides the whole page',
      (tester) async {
    var applied = false;
    await _pump(
      tester,
      session: [_card('a', '전체', 'body', 9999)],
      onApply: () => applied = true,
    );
    expect(find.text('전체 페이지를 가립니다'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '전체 적용 (1)'),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.text('전체 적용 (1)'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(applied, isFalse);
  });

  testWidgets('apply is disabled when a card has an invalid match count',
      (tester) async {
    await _pump(tester, session: [_card('a', 'x', '.bad', -1)]);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '전체 적용 (1)'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('cancel button fires onCancel', (tester) async {
    var cancelled = false;
    await _pump(
      tester,
      session: [_card('a', '광고', '.ad', 2)],
      onCancel: () => cancelled = true,
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
  });

  testWidgets('next-selector swaps to the next alternative via onRefine',
      (tester) async {
    String? refinedId;
    String? refinedSelector;
    await _pump(
      tester,
      session: [
        _card('a', '광고', '.ad', 2, alternatives: ['.ad', '.banner']),
      ],
      onRefine: (id, selector) {
        refinedId = id;
        refinedSelector = selector;
      },
    );
    await tester.tap(find.text('다음 기준'));
    await tester.pumpAndSettle();
    expect(refinedId, 'a');
    expect(refinedSelector, '.banner');
  });

  testWidgets('editing the selector field commits via onRefine on submit',
      (tester) async {
    String? refinedSelector;
    await _pump(
      tester,
      session: [_card('a', '광고', '.ad', 2)],
      onRefine: (id, selector) => refinedSelector = selector,
    );
    await tester.enterText(find.widgetWithText(TextField, '.ad'), '.ad .inner');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(refinedSelector, '.ad .inner');
  });

  testWidgets('next-selector does not clobber a hand-edited custom selector',
      (tester) async {
    var refineCalls = 0;
    await _pump(
      tester,
      session: [
        _card('a', '광고', '.custom', 2, alternatives: ['.ad', '.banner']),
      ],
      onRefine: (_, __) => refineCalls++,
    );
    await tester.tap(find.text('다음 기준'));
    await tester.pumpAndSettle();
    // '.custom' is not one of the alternatives, so cycling must be a no-op.
    expect(refineCalls, 0);
  });

  testWidgets('a selector edit commits when the field loses focus',
      (tester) async {
    String? refinedId;
    String? refined;
    await _pump(
      tester,
      session: [_card('a', '광고', '.ad', 2), _card('b', '추천', '.reco', 5)],
      onRefine: (id, selector) {
        refinedId = id;
        refined = selector;
      },
    );
    await tester.enterText(find.widgetWithText(TextField, '.ad'), '.ad .x');
    // Move focus to another card's field; the edited field blurs and commits.
    await tester.tap(find.widgetWithText(TextField, '.reco'));
    await tester.pumpAndSettle();
    expect(refinedId, 'a');
    expect(refined, '.ad .x');
  });

  // ── depth / range control ────────────────────────────────────────────────

  final twoDepthOptions = [
    const CardDepthOption(
      label: '현재 요소',
      selector: '.item',
      matchCount: 3,
    ),
    const CardDepthOption(
      label: '부모 1단계',
      selector: '.list',
      matchCount: 1,
    ),
  ];

  testWidgets('depth control renders option labels when 2+ depthOptions',
      (tester) async {
    await _pumpTile(
      tester,
      card:
          _cardWithDepth('a', '광고', '.item', 3, depthOptions: twoDepthOptions),
      onSetDepth: (_) {},
    );
    expect(find.text('현재 요소'), findsOneWidget);
    expect(find.text('부모 1단계'), findsOneWidget);
  });

  testWidgets('tapping 대상 넓히기 fires onSetDepth with depthIndex + 1',
      (tester) async {
    int? calledWith;
    await _pumpTile(
      tester,
      card:
          _cardWithDepth('a', '광고', '.item', 3, depthOptions: twoDepthOptions),
      onSetDepth: (i) => calledWith = i,
    );
    await tester.tap(find.text('대상 넓히기'));
    await tester.pumpAndSettle();
    expect(calledWith, 1);
  });

  testWidgets('대상 좁히기 is disabled at depthIndex == 0', (tester) async {
    await _pumpTile(
      tester,
      card:
          _cardWithDepth('a', '광고', '.item', 3, depthOptions: twoDepthOptions),
      onSetDepth: (_) {},
    );
    // Find the narrow button and verify onPressed is null (disabled).
    final narrowButtons = tester
        .widgetList<TextButton>(find.widgetWithText(TextButton, '대상 좁히기'))
        .toList();
    expect(narrowButtons, isNotEmpty);
    expect(narrowButtons.first.onPressed, isNull);
  });

  testWidgets('대상 넓히기 is disabled at the last depthIndex', (tester) async {
    await _pumpTile(
      tester,
      card: _cardWithDepth('a', '광고', '.list', 1,
          depthOptions: twoDepthOptions, depthIndex: 1),
      onSetDepth: (_) {},
    );
    final widenButtons = tester
        .widgetList<TextButton>(find.widgetWithText(TextButton, '대상 넓히기'))
        .toList();
    expect(widenButtons, isNotEmpty);
    expect(widenButtons.first.onPressed, isNull);
  });

  testWidgets('no range control when depthOptions has 0 entries',
      (tester) async {
    await _pumpTile(
      tester,
      card: _card('a', '광고', '.ad', 2),
      onSetDepth: (_) {},
    );
    expect(find.text('대상 범위'), findsNothing);
  });

  testWidgets('no range control when depthOptions has exactly 1 entry',
      (tester) async {
    await _pumpTile(
      tester,
      card: _cardWithDepth('a', '광고', '.ad', 2, depthOptions: [
        const CardDepthOption(label: '현재 요소', selector: '.ad', matchCount: 2),
      ]),
      onSetDepth: (_) {},
    );
    expect(find.text('대상 범위'), findsNothing);
  });
}
