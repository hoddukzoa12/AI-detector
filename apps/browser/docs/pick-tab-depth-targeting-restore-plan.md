# 「고르기」 깊이(상위/하위) 타깃 복원 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** 스테이징 카드에서 선택한 요소를 **부모(넓히기)/자식(좁히기)** 로 범위 조절하는 기능 복원. 크롬 익스텐션의 refine UX(breadcrumb + 좁히기/넓히기)와 동일.

**배경(회귀):** `refactor/infocutter-quality-debt` 리팩터가 depth 타깃 UI를 제거. JS는 매 픽마다 `depthTargets`(조상 5단계, 각 selector·matchCount·라벨)를 Dart로 보내지만 `handlePickerResult`가 즉시 `SelectionCard`로 스테이징하며 **버림**. JS(`depthTargets`, `pickSelector`)·위젯(`InfocutterDepthTile`)은 살아있음. 복원 = 데이터를 카드에 보존 + 컨트롤 렌더 + 단계 변경 시 selector 교체.

**핵심 설계:** depth 데이터는 이미 전송됨 → 새 JS 불필요. 단계 변경 = 카드 selector/matchCount를 미리 계산된 `depthTargets[index]` 값으로 교체 + 세션 하이라이트 repaint(기존 메커니즘이 새 selector 위치로 박스 이동). countMatches 라운드트립 불필요(매치수 사전 계산됨).

**검증된 시그니처:**
- `SelectionCard`(`selection_session.dart:12`): id/name/selector/frameScope/matchCount/alternatives + copyWith/toJson.
- `SelectionSessionController`(`selection_session_controller.dart`): `stage({selector, name, frameScope, alternatives})`, `refine(id, sel)`, `_repaint(session)`, `_countMatches`.
- `PickerResult`(`selector_engine.dart:1045`): `depthTargets: List<PickerDepthTarget>`, `selectedDepthIndex: int`.
- `PickerDepthTarget`: index, label("현재 요소"/"부모 N단계"), selector, selectorCandidates, matchCount, …
- `handlePickerResult`(`infocutter_webview_coordinator.dart:118`) → `_selectionSession.stage(result.selector, name:, frameScope:, alternatives: _alternativesFor(result))`.
- 스테이징 타일 `InfocutterStagedCardTile`(`infocutter_session_list.dart:148`) 콜백: onRemove/onRefine/onRename. pick_tab(`infocutter_pick_tab.dart`)이 생성, sidebar actions에서 배선.
- 사이드바 DTO `InfocutterSidebarActions`(`infocutter_sidebar.dart:37`): onRefineSessionCard 등. webview_tab이 coordinator로 연결.
- 기존 l10n: `infocutterNarrowTarget`("대상 좁히기"), `infocutterWidenTarget`("대상 넓히기"), `infocutterTargetRange`("대상 범위"). 재사용.

---

## File Structure

| 파일 | 변경 |
|---|---|
| `lib/infocutter/selection_session.dart` | `CardDepthOption` 추가 + `SelectionCard.depthOptions`/`depthIndex` + `sessionSetDepthIndex` 순수 fn |
| `lib/infocutter/selection_session_controller.dart` | `stage`에 depth 인자 + `setDepthIndex` 메서드 |
| `lib/infocutter/infocutter_webview_coordinator.dart` | `handlePickerResult`에서 depthTargets→depthOptions 매핑 + `setSessionCardDepth` |
| `lib/infocutter/ui/infocutter_sidebar.dart` | `InfocutterSidebarActions.onSetSessionCardDepth` 추가 |
| `lib/webview_tab.dart` (actions 생성부) | onSetSessionCardDepth → coordinator.setSessionCardDepth |
| `lib/infocutter/ui/infocutter_pick_tab.dart` | `onSetSessionCardDepth` 파라미터 + 스테이징 타일에 전달 |
| `lib/infocutter/ui/infocutter_sidebar_tabs.dart` | pick_tab에 actions.onSetSessionCardDepth 전달 |
| `lib/infocutter/ui/infocutter_session_list.dart` | `InfocutterStagedCardTile`에 depth 컨트롤(breadcrumb+좁히기/넓히기) + onSetDepth 콜백 |
| tests | 모델/컨트롤러/타일 위젯 테스트 |

---

## Task D1: 모델 — CardDepthOption + SelectionCard depth 필드 + pure fn

**Files:** Modify `lib/infocutter/selection_session.dart`; Test `test/infocutter/selection_session_test.dart`(기존에 추가).

- [ ] **Step 1: 실패 테스트 추가** (`selection_session_test.dart`에 group 추가)

```dart
  group('depth options', () {
    SelectionCard cardWithDepth() => const SelectionCard(
          id: 'a',
          name: '광고',
          selector: '.ad',
          frameScope: null,
          matchCount: 1,
          depthIndex: 0,
          depthOptions: [
            CardDepthOption(label: '현재 요소', selector: '.ad', matchCount: 1, alternatives: ['.ad']),
            CardDepthOption(label: '부모 1단계', selector: 'div.card', matchCount: 3, alternatives: ['div.card']),
          ],
        );

    test('sessionSetDepthIndex swaps selector/matchCount/depthIndex/alternatives', () {
      final out = sessionSetDepthIndex([cardWithDepth()], 'a', 1);
      expect(out.single.selector, 'div.card');
      expect(out.single.matchCount, 3);
      expect(out.single.depthIndex, 1);
      expect(out.single.alternatives, ['div.card']);
    });

    test('sessionSetDepthIndex ignores out-of-range index', () {
      final out = sessionSetDepthIndex([cardWithDepth()], 'a', 5);
      expect(out.single.selector, '.ad');
      expect(out.single.depthIndex, 0);
    });
  });
```

- [ ] **Step 2: run → FAIL** `fvm flutter test test/infocutter/selection_session_test.dart`

- [ ] **Step 3: implement** in `selection_session.dart`:

```dart
/// One ancestor-chain level for a staged card's range control: the JS picker
/// sends the whole chain (current element + parents) with each level's selector
/// and precomputed match count. Picking a level just swaps the card's selector.
@immutable
class CardDepthOption {
  const CardDepthOption({
    required this.label,
    required this.selector,
    required this.matchCount,
    this.alternatives = const [],
  });

  final String label; // "현재 요소", "부모 1단계", …
  final String selector;
  final int matchCount;
  final List<String> alternatives;
}
```
Add to `SelectionCard`: `final List<CardDepthOption> depthOptions;` (ctor `this.depthOptions = const []`), `final int depthIndex;` (ctor `this.depthIndex = 0`). Add both to `copyWith` (`List<CardDepthOption>? depthOptions, int? depthIndex`) and pass through; add `'depthIndex': depthIndex` to `toJson` (skip depthOptions in json — internal). Then:

```dart
/// Set a card's active depth level: swap its selector/matchCount/alternatives to
/// the chosen ancestor and record the index. No-op for unknown id / empty
/// options / out-of-range index.
List<SelectionCard> sessionSetDepthIndex(
  List<SelectionCard> session,
  String id,
  int index,
) =>
    session.map((card) {
      if (card.id != id) return card;
      if (index < 0 || index >= card.depthOptions.length) return card;
      final option = card.depthOptions[index];
      return card.copyWith(
        selector: option.selector,
        matchCount: option.matchCount,
        alternatives: option.alternatives,
        depthIndex: index,
      );
    }).toList();
```

- [ ] **Step 4: run → PASS** + `fvm flutter analyze` (0 issues; mind `avoid_redundant_argument_values` — don't pass defaults).
- [ ] **Step 5: commit** `feat(infocutter-app): SelectionCard depth options model`

## Task D2: 컨트롤러 — stage depth 인자 + setDepthIndex

**Files:** Modify `selection_session_controller.dart`; Test `test/infocutter/selection_session_controller_test.dart`.

- [ ] **Step 1: 실패 테스트** — stage with depthOptions persists them; setDepthIndex swaps selector + repaints. (Use the test's existing fake countMatches/repaint capture; assert the repainted session's card.selector == the chosen level, and that setDepthIndex does NOT call countMatches — it uses the precomputed matchCount.)
- [ ] **Step 2: run → FAIL**
- [ ] **Step 3: implement**:
  - `stage(...)` gains `List<CardDepthOption> depthOptions = const [], int depthIndex = 0`; set them on the `SelectionCard`.
  - New:
```dart
  /// Switch a staged card to a different ancestor depth (parent/child). Uses the
  /// precomputed per-level match count, so no JS round-trip; repaints so the
  /// on-page highlight box moves to the new range.
  Future<void> setDepthIndex(String id, int index) async {
    _session.value = sessionSetDepthIndex(_session.value, id, index);
    await _repaint(_session.value);
  }
```
- [ ] **Step 4: run → PASS** + analyze
- [ ] **Step 5: commit** `feat(infocutter-app): session controller setDepthIndex`

## Task D3: 코디네이터 — depthTargets 매핑 + setSessionCardDepth

**Files:** Modify `infocutter_webview_coordinator.dart`.

- [ ] **Step 1:** in `handlePickerResult`, build depth options from the result and pass to `stage` (only when >1 level):
```dart
    final depthOptions = result.depthTargets.length > 1
        ? result.depthTargets
            .map((t) => CardDepthOption(
                  label: t.label,
                  selector: t.selector,
                  matchCount: t.matchCount,
                  alternatives: t.selectorCandidates,
                ))
            .toList()
        : const <CardDepthOption>[];
    await _selectionSession.stage(
      result.selector,
      name: _sidebarSession.defaultCardName(url),
      frameScope: result.frameScope,
      alternatives: _alternativesFor(result),
      depthOptions: depthOptions,
      depthIndex: depthOptions.isEmpty
          ? 0
          : result.selectedDepthIndex.clamp(0, depthOptions.length - 1),
    );
```
  (import `CardDepthOption` from selection_session.dart if not already.)
- [ ] **Step 2:** add method:
```dart
  Future<void> setSessionCardDepth(String id, int index) =>
      _selectionSession.setDepthIndex(id, index);
```
- [ ] **Step 3:** analyze + run coordinator-adjacent tests. commit `feat(infocutter-app): stage depth options + setSessionCardDepth`

## Task D4: 배선 — sidebar action + webview_tab

**Files:** Modify `infocutter_sidebar.dart` (`InfocutterSidebarActions`), `webview_tab.dart` (actions construction).

- [ ] **Step 1:** add `final void Function(String id, int index) onSetSessionCardDepth;` to `InfocutterSidebarActions` (required). Update ALL construction sites: `webview_tab.dart` → `onSetSessionCardDepth: (id, i) => <coordinator>.setSessionCardDepth(id, i),` (mirror onRefineSessionCard). And the sidebar TEST harness (`infocutter_sidebar_test.dart` `_harness`) → add `onSetSessionCardDepth: (_, __) {},`.
- [ ] **Step 2:** analyze (catches every missing construction site). commit `feat(infocutter-app): wire onSetSessionCardDepth action`

## Task D5: UI — 스테이징 타일 depth 컨트롤 (breadcrumb + 좁히기/넓히기)

**Files:** Modify `infocutter_session_list.dart` (`InfocutterStagedCardTile`), `infocutter_pick_tab.dart`, `infocutter_sidebar_tabs.dart`; Test `infocutter_session_list_test.dart`.

- [ ] **Step 1: 실패 위젯 테스트** — a staged card with 2 depthOptions renders a breadcrumb showing both labels ("현재 요소","부모 1단계"); tapping "대상 넓히기" fires onSetDepth(1); the narrow button is disabled at index 0; widen disabled at last. (Extend the existing `_pump` to pass a card with depthOptions + onSetDepth.)
- [ ] **Step 2: run → FAIL**
- [ ] **Step 3: implement**:
  - `InfocutterStagedCardTile` gains `final void Function(int index)? onSetDepth;`.
  - Below the existing `_metaRow`, when `widget.card.depthOptions.length > 1` and `onSetDepth != null`, render a depth control: a `Wrap` of `ChoiceChip`/`InputChip` per option (label, selected = `card.depthIndex`, onSelected → `onSetDepth(i)`), plus two `TextButton.icon`: `infocutterNarrowTarget` (enabled when `depthIndex>0` → `onSetDepth(depthIndex-1)`) and `infocutterWidenTarget` (enabled when `depthIndex < depthOptions.length-1` → `onSetDepth(depthIndex+1)`). Current chip highlighted (selected). Use `infocutterTargetRange` as the section label.
  - `InfocutterPickTab`: add `final void Function(String id, int index) onSetSessionCardDepth;` param; pass `onSetDepth: (i) => onSetSessionCardDepth(session[idx].id, i)` to the staged tile.
  - `infocutter_sidebar_tabs.dart`: pass `onSetSessionCardDepth: widget.actions.onSetSessionCardDepth` to `InfocutterPickTab`.
- [ ] **Step 4: run → PASS** + analyze + `dart format`
- [ ] **Step 5: commit** `feat(infocutter-app): depth (parent/child) range control on staged cards`

## Task D6: 검증

- [ ] `fvm dart format --output=none --set-exit-if-changed <touched files>` → clean
- [ ] `fvm flutter analyze` → 0 issues
- [ ] `fvm flutter test` → all green
- [ ] manual macOS: pick an element → staged card shows breadcrumb + 좁히기/넓히기 → 넓히기 grows the on-page highlight to the parent, selector + 매치수 update; 좁히기 returns. Apply persists the chosen level.

## 범위 밖
- 적용된 카드의 depth 조절(적용 후엔 인라인 selector 직접 편집으로 충분).
- hover 중 depth 이동(크롬도 미지원 — Tab은 형제 순환만). 본 작업은 픽 후 카드 단위만.
- en/ja용 breadcrumb 라벨 번역(JS depthLabel이 한글 고정 — 기존 한계, 별도).
