# 「고르기」 탭 통합 — 적용 중 규칙 인라인 편집 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 「고르기」 탭 한 화면에서 "이미 숨긴 것"(적용 규칙)을 인라인 편집하고 "지금 고르는 중"(스테이징)을 함께 보여, 적용 규칙 수정을 위해 「숨긴 목록」 탭으로 넘어가던 동선을 없앤다.

**Architecture:** 표면(UI)·합성·배선만 추가 — 데이터(`ActiveSiteState.cards`)·편집 액션·라이브 적용 경로(`onRulesChanged` → `__infocutterRuntime.apply`, reload 불필요)는 이미 존재. 새 합성 위젯 `InfocutterPickTab`이 `context.watch<BlockRuleRepository>()`로 적용 상태를 읽어 단일 스크롤에 [접힘 가능한 적용 섹션][스테이징][고정 footer]을 그린다. 적용 카드 편집은 추출한 공용 `InfocutterStoredRuleActions`를 통해 repository를 변경하고, 커밋 시 `(cardId, createdAt)`로 최신 규칙을 재조회해 stale-target no-op을 막는다. 「숨긴 목록」은 `activeProfileId` 프로필의 카드만 숨겨 슬림화한다.

**Tech Stack:** Flutter, Provider (`context.watch`), flutter gen-l10n (en 템플릿 + ko), flutter_test 위젯 테스트, fvm.

**근거 스펙:** `apps/infocutter-app/docs/pick-tab-applied-rules-inline-edit.md` (v2).

**전제(검증된 사실):**
- 모든 명령은 `apps/infocutter-app`에서 `fvm flutter …`. analyze/test 게이트는 AGENTS.md.
- repository는 `infocutter_providers.dart`에서 `BlockRuleRepository`로 provide됨(Listenable). 소비는 `context.watch<BlockRuleRepository>()` (예: `infocutter_site_tab.dart:24`).
- 편집 액션 시그니처(모두 `BlockRuleRepository` 위, `block_rule_management.dart`):
  - `renameCard({required String profileId, required String cardId, required String cardName})`
  - `setCardEnabled({required String profileId, required String cardId, required bool enabled})`
  - `removeCard({required String profileId, required String cardId})`
  - `removeStoredRule({required String profileId, required StoredRule targetRule})`
  - `updateStoredRule({required String profileId, required StoredRule targetRule, String? selector, RuleMode? mode, String? frameScope})`
  - `buildActiveSiteState(Uri url) → ActiveSiteState`
- `ActiveSiteState { String? activeProfileId; List<SavedCard> cards; … }`
- `SavedCard { String cardId; String cardName; DateTime createdAt; bool enabled; List<String?> frameScopes; RuleMode mode; int ruleCount; List<StoredRule> rules; }`
- `StoredRule { String cardId; String cardName; String selector; RuleMode mode; DateTime createdAt; String? frameScope; }`
- `enum RuleMode { hide, unhide }`
- `isSameStoredRule(rule, target)`는 cardId+createdAt+frameScope+mode+selector 전부 비교 → 편집 후 캡처해 둔 target은 stale.
- 사이드바 DTO에 `InfocutterSidebarData.url`, `InfocutterSidebarActions.onRulesChanged`, `…onPreviewStoredRule` **이미 존재** → DTO 확장 불필요.

---

## File Structure

| 파일 | 책임 | 신규/수정 |
|---|---|---|
| `lib/l10n/app_en.arb`, `app_ko.arb` | 신규 문자열 키 | 수정 |
| `lib/infocutter/ui/infocutter_stored_rule_actions.dart` | 공용 적용-규칙 편집 액션(추출) | 신규 |
| `lib/infocutter/ui/infocutter_rule_manager.dart` (+ `_actions`) | `_RuleManagerActions` 제거하고 공용 액션 사용 + `activeProfileId` 카드 숨김 | 수정 |
| `lib/infocutter/applied_rule_lookup.dart` | `findRuleByIdentity(cards, cardId, createdAt)` 순수 헬퍼 | 신규 |
| `lib/infocutter/ui/infocutter_session_list.dart` | 스테이징 타일 공개 + `infocutterSessionCanApply` 헬퍼 추출 | 수정 |
| `lib/infocutter/ui/infocutter_applied_cards.dart` | 적용 섹션 + 적용 카드 타일(인라인 편집) | 신규 |
| `lib/infocutter/ui/infocutter_pick_tab.dart` | 「고르기」 합성(적용+스테이징+footer, 반응형 접힘, repository watch + 재조회 커밋) | 신규 |
| `lib/infocutter/ui/infocutter_sidebar_tabs.dart` | 「고르기」 탭 child를 `InfocutterPickTab`으로 교체 | 수정 |
| `lib/infocutter/infocutter_webview_coordinator.dart` | 프리뷰 종료 시 스테이징 하이라이트 복원 | 수정 |
| `test/infocutter/applied_rule_lookup_test.dart` | 헬퍼 테스트 | 신규 |
| `test/infocutter/infocutter_applied_cards_test.dart` | 적용 카드 위젯 테스트 | 신규 |
| `test/infocutter/infocutter_pick_tab_test.dart` | 합성/반응형/재조회 테스트 | 신규 |
| `test/infocutter/infocutter_rule_manager_slim_test.dart` | 슬림화 회귀 테스트 | 신규 |

---

## Task 1: l10n 키 추가

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ko.arb`

- [ ] **Step 1: en 템플릿에 키 추가**

`lib/l10n/app_en.arb`의 마지막 `}` 직전에 추가(끝 항목 뒤 콤마 유지):

```json
  "infocutterAlreadyHiddenSection": "Already hidden ({count})",
  "@infocutterAlreadyHiddenSection": {
    "placeholders": { "count": { "type": "int" } }
  },
  "infocutterPickingNowSection": "Picking now ({count})",
  "@infocutterPickingNowSection": {
    "placeholders": { "count": { "type": "int" } }
  },
  "infocutterAppliedEditsLiveHint": "Edits here apply to the page immediately",
  "infocutterDeleteRule": "Delete rule"
```

- [ ] **Step 2: ko에 동일 키 추가**

`lib/l10n/app_ko.arb`의 마지막 `}` 직전에 추가:

```json
  "infocutterAlreadyHiddenSection": "이미 숨긴 것 ({count})",
  "infocutterPickingNowSection": "지금 고르는 중 ({count})",
  "infocutterAppliedEditsLiveHint": "여기서 고치면 페이지에 바로 반영돼요",
  "infocutterDeleteRule": "규칙 삭제"
```

(ko는 placeholder 메타데이터 불필요 — 템플릿 en에만 둔다. 기존 ko 파일도 `@`키 없이 값만 두는 관례.)

- [ ] **Step 3: 코드 생성 + analyze**

Run: `fvm flutter gen-l10n && fvm flutter analyze`
Expected: gen-l10n 성공, `AppLocalizations.infocutterAlreadyHiddenSection(int)` 등 생성, analyze 0 issues (신규 키 미사용 경고는 없음).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ko.arb
git commit -m "i18n(infocutter-app): pick-tab applied-rules section strings"
```

---

## Task 2: `findRuleByIdentity` 순수 헬퍼 (재조회용)

stale-target 방지를 위해 커밋 시점에 최신 카드 목록에서 `(cardId, createdAt)`로 규칙을 다시 찾는다.

**Files:**
- Create: `lib/infocutter/applied_rule_lookup.dart`
- Test: `test/infocutter/applied_rule_lookup_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

```dart
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
  final t1 = DateTime.utc(2026, 1, 1);
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
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/infocutter/applied_rule_lookup_test.dart`
Expected: FAIL — `applied_rule_lookup.dart` / `findRuleByIdentity` 없음.

- [ ] **Step 3: 구현**

`lib/infocutter/applied_rule_lookup.dart`:

```dart
import 'package:infocutter_app/infocutter/models.dart';

/// Re-resolve a stored rule from the freshest [cards] by its stable identity
/// (cardId + createdAt), which survives selector/mode/frame edits. Used at
/// inline-edit commit time so a captured (stale) StoredRule never desyncs the
/// mutation target. Returns null if the rule is no longer present.
StoredRule? findRuleByIdentity(
  List<SavedCard> cards,
  String cardId,
  DateTime createdAt,
) {
  for (final card in cards) {
    if (card.cardId != cardId) continue;
    for (final rule in card.rules) {
      if (rule.createdAt == createdAt) return rule;
    }
  }
  return null;
}
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/infocutter/applied_rule_lookup_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/infocutter/applied_rule_lookup.dart test/infocutter/applied_rule_lookup_test.dart
git commit -m "feat(infocutter-app): findRuleByIdentity lookup for inline edit re-resolve"
```

---

## Task 3: 공용 `InfocutterStoredRuleActions` 추출 (동작 불변)

`_RuleManagerActions`(private, `part of`)를 공용 클래스로 추출해 적용-규칙 편집 액션을 「고르기」와 매니저가 공유한다. 동작·`onRulesChanged` 의미는 동일.

**Files:**
- Create: `lib/infocutter/ui/infocutter_stored_rule_actions.dart`
- Modify: `lib/infocutter/ui/infocutter_rule_manager.dart`
- Delete: `lib/infocutter/ui/infocutter_rule_manager_actions.dart` (내용을 신규 파일로 이동)

- [ ] **Step 1: 신규 공용 액션 파일 작성**

`lib/infocutter/ui/infocutter_stored_rule_actions.dart` — 기존 `_RuleManagerActions`와 동일 본문, 클래스명만 공개로:

```dart
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';

/// Presentation-layer glue that runs a block-rule mutation on the repository
/// and then fires onRulesChanged (live JS re-apply, no reload). Shared by the
/// 「고르기」 applied-cards section and the 「숨긴 목록」 rule manager so both edit
/// paths behave identically.
class InfocutterStoredRuleActions {
  const InfocutterStoredRuleActions({
    required this.repository,
    required this.onRulesChanged,
    this.onPreviewRule,
  });

  final BlockRuleRepository repository;
  final Future<void> Function()? onRulesChanged;
  final Future<void> Function(StoredRule rule)? onPreviewRule;

  bool get canPreviewRule => onPreviewRule != null;

  Future<void> previewRule(StoredRule rule) async {
    await onPreviewRule?.call(rule);
  }

  Future<void> createProfile({
    required String name,
    required List<String> matchers,
  }) =>
      _run(() => repository.upsertProfile(name: name, matchers: matchers));

  Future<void> deleteProfile(String profileId) =>
      _run(() => repository.deleteProfile(profileId));

  Future<void> importChromeJson(String raw) =>
      _run(() => repository.importChromeJson(raw));

  Future<void> removeCard({
    required String profileId,
    required String cardId,
  }) =>
      _run(() => repository.removeCard(profileId: profileId, cardId: cardId));

  Future<void> removeStoredRule({
    required String profileId,
    required StoredRule targetRule,
  }) =>
      _run(() => repository.removeStoredRule(
            profileId: profileId,
            targetRule: targetRule,
          ));

  Future<void> renameCard({
    required String profileId,
    required String cardId,
    required String cardName,
  }) =>
      _run(() => repository.renameCard(
            profileId: profileId,
            cardId: cardId,
            cardName: cardName,
          ));

  Future<void> renameProfile(String profileId, String name) =>
      _run(() => repository.renameProfile(profileId, name));

  Future<void> setCardEnabled({
    required String profileId,
    required String cardId,
    required bool enabled,
  }) =>
      _run(() => repository.setCardEnabled(
            profileId: profileId,
            cardId: cardId,
            enabled: enabled,
          ));

  Future<void> setGlobalEnabled(bool value) =>
      _run(() => repository.setGlobalEnabled(value));

  Future<void> setProfileEnabled(String profileId, bool enabled) =>
      _run(() => repository.setProfileEnabled(profileId, enabled));

  Future<void> setProfileMatchers(String profileId, List<String> matchers) =>
      _run(() => repository.setProfileMatchers(profileId, matchers));

  Future<void> updateStoredRule({
    required String profileId,
    required StoredRule targetRule,
    String? selector,
    RuleMode? mode,
    String? frameScope,
  }) =>
      _run(() => repository.updateStoredRule(
            profileId: profileId,
            targetRule: targetRule,
            selector: selector,
            mode: mode,
            frameScope: frameScope,
          ));

  Future<void> _run(Future<void> Function() mutation) async {
    await mutation();
    await onRulesChanged?.call();
  }
}
```

(참고: `upsertProfile`/`deleteProfile`/`importChromeJson`/`renameProfile`/`setGlobalEnabled`/`setProfileMatchers`는 기존 `_RuleManagerActions`가 이미 호출하던 repository 메서드 그대로다.)

- [ ] **Step 2: 매니저가 신규 클래스를 쓰도록 수정**

`lib/infocutter/ui/infocutter_rule_manager.dart`:
1. `part 'infocutter_rule_manager_actions.dart';` 줄 삭제.
2. import 추가: `import 'package:infocutter_app/infocutter/ui/infocutter_stored_rule_actions.dart';`
3. 본문의 모든 `_RuleManagerActions` 식별자를 `InfocutterStoredRuleActions`로 교체(생성자 인자명은 동일: `onPreviewRule`/`repository`/`onRulesChanged`).
4. 기존 파일 삭제: `lib/infocutter/ui/infocutter_rule_manager_actions.dart`.

```bash
git rm apps/infocutter-app/lib/infocutter/ui/infocutter_rule_manager_actions.dart
```

- [ ] **Step 3: analyze + 기존 테스트로 회귀 확인**

Run: `fvm flutter analyze && fvm flutter test test/infocutter/infocutter_config_export_test.dart test/infocutter/infocutter_service_test.dart`
Expected: 0 issues, 기존 테스트 PASS (매니저 동작 불변).

- [ ] **Step 4: Commit**

```bash
git add -A apps/infocutter-app/lib/infocutter/ui
git commit -m "refactor(infocutter-app): extract public InfocutterStoredRuleActions"
```

---

## Task 4: 스테이징 타일 공개 + `infocutterSessionCanApply` 추출

`InfocutterPickTab`이 적용+스테이징을 **하나의 스크롤**에 그리려면 스테이징 타일과 적용-가능 판정을 재사용해야 한다(중첩 스크롤 충돌 방지). 동작·기존 테스트 불변.

**Files:**
- Modify: `lib/infocutter/ui/infocutter_session_list.dart`

- [ ] **Step 1: 타일 클래스 공개**

`_SessionCardTile` → `InfocutterStagedCardTile` (그리고 `_SessionCardTileState` → `_InfocutterStagedCardTileState`)로 이름만 변경. `InfocutterSessionList._cardList()`의 `_SessionCardTile(...)` 호출도 새 이름으로.

- [ ] **Step 2: 적용-가능 판정 공개 헬퍼 추출**

`InfocutterSessionList`의 `bool get _canApply => …` 를 파일 최상위 공개 함수로 추출하고 getter는 그걸 호출:

```dart
/// Every staged card must match something and not blanket the whole page
/// before the session can be committed.
bool infocutterSessionCanApply(List<SelectionCard> session) => session.every(
      (c) => c.matchCount >= 0 && !isOverlyBroadSelector(c.selector),
    );
```

그리고 `InfocutterSessionList` 내부:

```dart
  bool get _canApply => infocutterSessionCanApply(session);
```

- [ ] **Step 3: analyze + 기존 세션 리스트 테스트 회귀**

Run: `fvm flutter analyze && fvm flutter test test/infocutter/infocutter_session_list_test.dart`
Expected: 0 issues, 기존 11 테스트 모두 PASS (렌더 출력 불변).

- [ ] **Step 4: Commit**

```bash
git add apps/infocutter-app/lib/infocutter/ui/infocutter_session_list.dart
git commit -m "refactor(infocutter-app): expose staged tile + session-can-apply helper"
```

---

## Task 5: 적용 카드 위젯 `InfocutterAppliedCards` (인라인 편집)

순수 presentational 위젯 — 데이터(`cards`) + 콜백((cardId/createdAt) 식별)만 받는다. `InfocutterSessionList`와 동일하게 Provider 없이 테스트.

**Files:**
- Create: `lib/infocutter/ui/infocutter_applied_cards.dart`
- Test: `test/infocutter/infocutter_applied_cards_test.dart`

- [ ] **Step 1: 실패 위젯 테스트 작성**

```dart
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
  final t1 = DateTime.utc(2026, 1, 1);
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
      cards: [_card('A', '광고', [_rule('A', '.ad', t1)], enabled: true)],
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
    // Blur by tapping the other rule's field.
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
      cards: [_card('A', '광고', [_rule('A', '.ad', t1)])],
      onToggleRuleMode: (_, a) => at = a,
    );
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();
    expect(at, t1);
  });

  testWidgets('frame scope shows the main-frame label when null', (tester) async {
    await _pump(tester, cards: [_card('A', '광고', [_rule('A', '.ad', t1)])]);
    expect(find.text('메인 프레임'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/infocutter/infocutter_applied_cards_test.dart`
Expected: FAIL — `infocutter_applied_cards.dart` 없음.

- [ ] **Step 3: 구현**

`lib/infocutter/ui/infocutter_applied_cards.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// The "이미 숨긴 것" section: applied block cards for the current site,
/// fully inline-editable. Pure presentational widget — takes data + callbacks
/// keyed by stable identity (cardId / rule createdAt) so the parent can
/// re-resolve fresh targets at commit time. Edits here apply to the page
/// immediately via the parent's onRulesChanged path (no reload).
class InfocutterAppliedCards extends StatelessWidget {
  const InfocutterAppliedCards({
    required this.cards,
    required this.onRenameCard,
    required this.onToggleCard,
    required this.onDeleteCard,
    required this.onEditRuleSelector,
    required this.onToggleRuleMode,
    required this.onDeleteRule,
    required this.onPreviewRule,
    super.key,
  });

  final List<SavedCard> cards;
  final void Function(String cardId, String name) onRenameCard;
  final void Function(String cardId, bool enabled) onToggleCard;
  final void Function(String cardId) onDeleteCard;
  final void Function(String cardId, DateTime createdAt, String selector)
      onEditRuleSelector;
  final void Function(String cardId, DateTime createdAt) onToggleRuleMode;
  final void Function(String cardId, DateTime createdAt) onDeleteRule;
  final void Function(StoredRule rule) onPreviewRule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final card in cards)
          _AppliedCardTile(
            key: ValueKey('applied-${card.cardId}'),
            card: card,
            onRename: (name) => onRenameCard(card.cardId, name),
            onToggle: (enabled) => onToggleCard(card.cardId, enabled),
            onDelete: () => onDeleteCard(card.cardId),
            onEditSelector: (createdAt, selector) =>
                onEditRuleSelector(card.cardId, createdAt, selector),
            onToggleMode: (createdAt) =>
                onToggleRuleMode(card.cardId, createdAt),
            onDeleteRule: (createdAt) => onDeleteRule(card.cardId, createdAt),
            onPreview: onPreviewRule,
          ),
      ],
    );
  }
}

class _AppliedCardTile extends StatefulWidget {
  const _AppliedCardTile({
    required this.card,
    required this.onRename,
    required this.onToggle,
    required this.onDelete,
    required this.onEditSelector,
    required this.onToggleMode,
    required this.onDeleteRule,
    required this.onPreview,
    super.key,
  });

  final SavedCard card;
  final void Function(String name) onRename;
  final void Function(bool enabled) onToggle;
  final VoidCallback onDelete;
  final void Function(DateTime createdAt, String selector) onEditSelector;
  final void Function(DateTime createdAt) onToggleMode;
  final void Function(DateTime createdAt) onDeleteRule;
  final void Function(StoredRule rule) onPreview;

  @override
  State<_AppliedCardTile> createState() => _AppliedCardTileState();
}

class _AppliedCardTileState extends State<_AppliedCardTile> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card.cardName);
    _nameFocus = FocusNode()..addListener(_commitNameOnBlur);
  }

  void _commitNameOnBlur() {
    if (_nameFocus.hasFocus) return;
    final text = _nameController.text.trim();
    if (text.isNotEmpty && text != widget.card.cardName) widget.onRename(text);
  }

  @override
  void didUpdateWidget(covariant _AppliedCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync from a repository-driven rebuild, but never while editing.
    if (widget.card.cardName != oldWidget.card.cardName &&
        !_nameFocus.hasFocus &&
        widget.card.cardName != _nameController.text) {
      _nameController.text = widget.card.cardName;
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_commitNameOnBlur);
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.card.enabled
                      ? Icons.visibility_off
                      : Icons.visibility_off_outlined,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.infocutterCardName,
                      border: const OutlineInputBorder(),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: widget.onRename,
                  ),
                ),
                Switch(
                  value: widget.card.enabled,
                  onChanged: widget.onToggle,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.infocutterDelete,
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            for (final rule in widget.card.rules)
              _AppliedRuleRow(
                key: ValueKey(
                  'rule-${rule.cardId}-${rule.createdAt.microsecondsSinceEpoch}',
                ),
                rule: rule,
                onEditSelector: (selector) =>
                    widget.onEditSelector(rule.createdAt, selector),
                onToggleMode: () => widget.onToggleMode(rule.createdAt),
                onDelete: widget.card.rules.length > 1
                    ? () => widget.onDeleteRule(rule.createdAt)
                    : null,
                onPreview: () => widget.onPreview(rule),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppliedRuleRow extends StatefulWidget {
  const _AppliedRuleRow({
    required this.rule,
    required this.onEditSelector,
    required this.onToggleMode,
    required this.onPreview,
    this.onDelete,
    super.key,
  });

  final StoredRule rule;
  final void Function(String selector) onEditSelector;
  final VoidCallback onToggleMode;
  final VoidCallback onPreview;
  final VoidCallback? onDelete;

  @override
  State<_AppliedRuleRow> createState() => _AppliedRuleRowState();
}

class _AppliedRuleRowState extends State<_AppliedRuleRow> {
  late final TextEditingController _selectorController;
  late final FocusNode _selectorFocus;

  @override
  void initState() {
    super.initState();
    _selectorController = TextEditingController(text: widget.rule.selector);
    _selectorFocus = FocusNode()..addListener(_commitSelectorOnBlur);
  }

  void _commitSelectorOnBlur() {
    if (_selectorFocus.hasFocus) return;
    final text = _selectorController.text.trim();
    if (text.isNotEmpty && text != widget.rule.selector) {
      widget.onEditSelector(text);
    }
  }

  @override
  void didUpdateWidget(covariant _AppliedRuleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rule.selector != oldWidget.rule.selector &&
        !_selectorFocus.hasFocus &&
        widget.rule.selector != _selectorController.text) {
      _selectorController.text = widget.rule.selector;
    }
  }

  @override
  void dispose() {
    _selectorFocus.removeListener(_commitSelectorOnBlur);
    _selectorFocus.dispose();
    _selectorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isHide = widget.rule.mode == RuleMode.hide;
    final frameLabel = widget.rule.frameScope == null
        ? l10n.infocutterMainFrame
        : '${l10n.infocutterFrameScope}: ${widget.rule.frameScope}';
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _selectorController,
                  focusNode: _selectorFocus,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l10n.infocutterSelector,
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: widget.onEditSelector,
                ),
              ),
              IconButton(
                icon: Icon(isHide ? Icons.visibility_off : Icons.visibility),
                tooltip: isHide
                    ? l10n.infocutterRuleModeHide
                    : l10n.infocutterRuleModeUnhide,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onToggleMode,
              ),
              IconButton(
                icon: const Icon(Icons.center_focus_strong),
                tooltip: l10n.infocutterSelectedTarget,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onPreview,
              ),
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.infocutterDeleteRule,
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text(
              frameLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
```

(참고: `infocutterSelectedTarget`는 기존 키 "선택한 대상". 프리뷰 버튼 tooltip로 재사용. frameScope 편집은 v1 비포함 — 읽기 전용 라벨. 필요 시 후속에서 ⋮ 메뉴+다이얼로그 추가.)

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/infocutter/infocutter_applied_cards_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/infocutter-app/lib/infocutter/ui/infocutter_applied_cards.dart test/infocutter/infocutter_applied_cards_test.dart
git commit -m "feat(infocutter-app): inline-editable applied-cards section widget"
```

---

## Task 6: 합성 위젯 `InfocutterPickTab`

repository를 watch → 적용 상태를 읽어 [반응형 접힘 적용 섹션][스테이징][고정 footer]를 단일 스크롤로 구성. 커밋 시 `findRuleByIdentity`로 재조회.

**Files:**
- Create: `lib/infocutter/ui/infocutter_pick_tab.dart`
- Test: `test/infocutter/infocutter_pick_tab_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

Provider로 fake `BlockRuleRepository`를 주입한다. `BlockRuleRepository`는 `BlockRuleReader`(Listenable) 구현이므로 `ChangeNotifier`를 섞은 fake를 만든다. 테스트는 (a) 적용 카드 렌더, (b) 좁은 화면 기본 접힘 / 넓은 화면 기본 펼침, (c) selector 인라인 커밋이 fresh target으로 `updateStoredRule` 호출(재조회)을 검증.

```dart
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
  final t1 = DateTime.utc(2026, 1, 1);

  ActiveSiteState _state({required String selector}) => ActiveSiteState(
        activeProfileId: 'P',
        activeProfileName: 'site',
        cardCount: 1,
        cards: [
          SavedCard(
            cardId: 'A',
            cardName: '광고',
            createdAt: t1,
            enabled: true,
            frameScopes: const [null],
            mode: RuleMode.hide,
            ruleCount: 1,
            rules: [
              StoredRule(
                cardId: 'A',
                cardName: '광고',
                selector: selector,
                mode: RuleMode.hide,
                createdAt: t1,
              ),
            ],
          ),
        ],
        enabledExceptionCount: 0,
        enabledSelectorCount: 1,
        exceptionCount: 0,
        globalEnabled: true,
        hostname: 'example.com',
        matchers: const ['example.com'],
        profileEnabled: true,
        rules: const [],
        selectorCount: 1,
        updatedAt: t1,
        url: Uri.parse('https://example.com'),
      );

  Future<void> _pump(
    WidgetTester tester, {
    required FakeBlockRuleRepository repo,
    List<SelectionCard> session = const [],
    Size size = const Size(440, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<BlockRuleRepository>.value(
        value: repo,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('narrow screen collapses the applied section by default',
      (tester) async {
    final repo = FakeBlockRuleRepository(_state(selector: '.ad'));
    await _pump(tester, repo: repo, size: const Size(440, 900));
    // Header shows count, selector hidden until expanded.
    expect(find.textContaining('이미 숨긴 것'), findsOneWidget);
    expect(find.text('.ad'), findsNothing);
    await tester.tap(find.textContaining('이미 숨긴 것'));
    await tester.pumpAndSettle();
    expect(find.text('.ad'), findsOneWidget);
  });

  testWidgets('wide screen expands the applied section by default',
      (tester) async {
    final repo = FakeBlockRuleRepository(_state(selector: '.ad'));
    await _pump(tester, repo: repo, size: const Size(900, 900));
    expect(find.text('.ad'), findsOneWidget);
  });

  testWidgets('selector edit commits via updateStoredRule with a fresh target',
      (tester) async {
    final repo = FakeBlockRuleRepository(_state(selector: '.ad'));
    await _pump(tester, repo: repo, size: const Size(900, 900));
    await tester.enterText(
        find.widgetWithText(TextField, '.ad'), '.ad .inner');
    await tester.tap(find.widgetWithText(TextField, '광고'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdate?.profileId, 'P');
    expect(repo.lastUpdate?.targetRule.createdAt, t1);
    expect(repo.lastUpdate?.selector, '.ad .inner');
  });
}
```

- [ ] **Step 2: fake repository 작성**

`test/infocutter/fakes/fake_block_rule_repository.dart` — `BlockRuleRepository` 추상 멤버를 최소 구현(이번 테스트가 쓰는 것만 동작, 나머지는 `noSuchMethod`로 무해 처리). `BlockRuleRepository`의 정확한 추상 멤버는 구현 시 `lib/infocutter/application/block_rules/block_rule_repository.dart`를 열어 맞춘다.

```dart
import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';

class RecordedUpdate {
  RecordedUpdate(this.profileId, this.targetRule, this.selector);
  final String profileId;
  final StoredRule targetRule;
  final String? selector;
}

/// Minimal fake: returns a fixed ActiveSiteState and records updateStoredRule.
/// Unimplemented members throw via noSuchMethod — keep the test exercising only
/// buildActiveSiteState + updateStoredRule.
class FakeBlockRuleRepository extends ChangeNotifier
    with FakeBlockRuleRepositoryMixin
    implements BlockRuleRepository {
  FakeBlockRuleRepository(this._state);
  ActiveSiteState _state;
  RecordedUpdate? lastUpdate;

  @override
  ActiveSiteState buildActiveSiteState(Uri url) => _state;

  @override
  Future<RuleProfile?> updateStoredRule({
    required String profileId,
    required StoredRule targetRule,
    String? selector,
    RuleMode? mode,
    String? frameScope,
  }) async {
    lastUpdate = RecordedUpdate(profileId, targetRule, selector);
    notifyListeners();
    return null;
  }
}

mixin FakeBlockRuleRepositoryMixin {
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
```

(구현 시: `implements BlockRuleRepository`로 인해 미구현 멤버는 컴파일 에러가 날 수 있다. 그 경우 `noSuchMethod`만으로는 부족하므로, `BlockRuleRepository`가 추상 클래스이고 멤버가 많다면 위 mixin의 `noSuchMethod` 패턴으로 충분해야 한다. 컴파일 에러가 나는 멤버만 시그니처 stub을 추가한다 — `=> super.noSuchMethod(...)` 형태.)

- [ ] **Step 3: 실패 확인**

Run: `fvm flutter test test/infocutter/infocutter_pick_tab_test.dart`
Expected: FAIL — `infocutter_pick_tab.dart` / `InfocutterPickTab` 없음.

- [ ] **Step 4: 구현**

`lib/infocutter/ui/infocutter_pick_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/applied_rule_lookup.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_applied_cards.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_session_list.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_stored_rule_actions.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// The unified 「고르기」 tab: a collapsible "이미 숨긴 것" (applied rules, inline
/// editable) above "지금 고르는 중" (the staging session), with the apply/cancel
/// footer pinned. Applied edits go straight to the repository via the shared
/// InfocutterStoredRuleActions and reflect live (onRulesChanged, no reload).
class InfocutterPickTab extends StatefulWidget {
  const InfocutterPickTab({
    required this.url,
    required this.session,
    required this.onRemoveSessionCard,
    required this.onRefineSessionCard,
    required this.onRenameSessionCard,
    required this.onApplySession,
    required this.onCancelSession,
    required this.onRulesChanged,
    required this.onPreviewStoredRule,
    super.key,
  });

  final Uri url;
  final List<SelectionCard> session;
  final void Function(String id) onRemoveSessionCard;
  final void Function(String id, String selector) onRefineSessionCard;
  final void Function(String id, String name) onRenameSessionCard;
  final VoidCallback onApplySession;
  final VoidCallback onCancelSession;
  final Future<void> Function() onRulesChanged;
  final Future<void> Function(StoredRule rule) onPreviewStoredRule;

  @override
  State<InfocutterPickTab> createState() => _InfocutterPickTabState();
}

class _InfocutterPickTabState extends State<InfocutterPickTab> {
  bool? _appliedExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.watch<BlockRuleRepository>();
    final siteState = repository.buildActiveSiteState(widget.url);
    final actions = InfocutterStoredRuleActions(
      repository: repository,
      onRulesChanged: widget.onRulesChanged,
      onPreviewRule: widget.onPreviewStoredRule,
    );
    final profileId = siteState.activeProfileId;
    final appliedCards = profileId == null ? const <SavedCard>[] : siteState.cards;

    final width = MediaQuery.sizeOf(context).width;
    final expanded = _appliedExpanded ?? (width >= 620);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              if (appliedCards.isNotEmpty) ...[
                _appliedHeader(context, l10n, appliedCards.length, expanded),
                if (expanded)
                  InfocutterAppliedCards(
                    cards: appliedCards,
                    onRenameCard: (cardId, name) => actions.renameCard(
                        profileId: profileId!, cardId: cardId, cardName: name),
                    onToggleCard: (cardId, enabled) => actions.setCardEnabled(
                        profileId: profileId!,
                        cardId: cardId,
                        enabled: enabled),
                    onDeleteCard: (cardId) async {
                      await actions.removeCard(
                          profileId: profileId!, cardId: cardId);
                    },
                    onEditRuleSelector: (cardId, createdAt, selector) =>
                        _commitRule(repository, actions, profileId!, cardId,
                            createdAt, selector: selector),
                    onToggleRuleMode: (cardId, createdAt) {
                      final rule = findRuleByIdentity(
                          repository.buildActiveSiteState(widget.url).cards,
                          cardId,
                          createdAt);
                      if (rule == null) return;
                      actions.updateStoredRule(
                        profileId: profileId!,
                        targetRule: rule,
                        mode: rule.mode == RuleMode.hide
                            ? RuleMode.unhide
                            : RuleMode.hide,
                      );
                    },
                    onDeleteRule: (cardId, createdAt) {
                      final rule = findRuleByIdentity(
                          repository.buildActiveSiteState(widget.url).cards,
                          cardId,
                          createdAt);
                      if (rule == null) return;
                      actions.removeStoredRule(
                          profileId: profileId!, targetRule: rule);
                    },
                    onPreviewRule: (rule) => actions.previewRule(rule),
                  ),
                const Divider(height: 24),
              ],
              _stagingHeader(context, l10n, widget.session.length),
              if (widget.session.isEmpty)
                _stagingEmptyHint(context, l10n)
              else
                for (var i = 0; i < widget.session.length; i++)
                  InfocutterStagedCardTile(
                    key: ValueKey(widget.session[i].id),
                    index: i,
                    card: widget.session[i],
                    onRemove: () =>
                        widget.onRemoveSessionCard(widget.session[i].id),
                    onRefine: (selector) => widget.onRefineSessionCard(
                        widget.session[i].id, selector),
                    onRename: (name) =>
                        widget.onRenameSessionCard(widget.session[i].id, name),
                  ),
            ],
          ),
        ),
        if (widget.session.isNotEmpty) ...[
          const Divider(height: 1),
          _footer(context, l10n),
        ],
      ],
    );
  }

  void _commitRule(
    BlockRuleRepository repository,
    InfocutterStoredRuleActions actions,
    String profileId,
    String cardId,
    DateTime createdAt, {
    String? selector,
  }) {
    final rule = findRuleByIdentity(
        repository.buildActiveSiteState(widget.url).cards, cardId, createdAt);
    if (rule == null) return;
    actions.updateStoredRule(
        profileId: profileId, targetRule: rule, selector: selector);
  }

  Widget _appliedHeader(
    BuildContext context,
    AppLocalizations l10n,
    int count,
    bool expanded,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _appliedExpanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.infocutterAlreadyHiddenSection(count),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                l10n.infocutterAppliedEditsLiveHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      );

  Widget _stagingHeader(
    BuildContext context,
    AppLocalizations l10n,
    int count,
  ) =>
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l10n.infocutterPickingNowSection(count),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      );

  Widget _stagingEmptyHint(BuildContext context, AppLocalizations l10n) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            l10n.infocutterSessionPickHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );

  Widget _footer(BuildContext context, AppLocalizations l10n) {
    final canApply = infocutterSessionCanApply(widget.session);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!canApply)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.infocutterFixSelectorsToApply,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canApply ? widget.onApplySession : null,
                  icon: const Icon(Icons.check),
                  label: Text(
                      l10n.infocutterSessionApplyAll(widget.session.length)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onCancelSession,
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 통과 확인**

Run: `fvm flutter test test/infocutter/infocutter_pick_tab_test.dart`
Expected: PASS (3 tests). fake가 컴파일 안 되면 Step 2 주석대로 누락 멤버 stub 보강.

- [ ] **Step 6: Commit**

```bash
git add apps/infocutter-app/lib/infocutter/ui/infocutter_pick_tab.dart test/infocutter/infocutter_pick_tab_test.dart test/infocutter/fakes/fake_block_rule_repository.dart
git commit -m "feat(infocutter-app): InfocutterPickTab composing applied + staging"
```

---

## Task 7: 「고르기」 탭 child를 `InfocutterPickTab`으로 교체

**Files:**
- Modify: `lib/infocutter/ui/infocutter_sidebar_tabs.dart:67-74`

- [ ] **Step 1: TabBarView 첫 child 교체**

`_InfocutterBlockPanel.build`의 `TabBarView` 첫 child `InfocutterSessionList(...)`를 다음으로 교체:

```dart
              InfocutterPickTab(
                url: widget.data.url,
                session: widget.data.session,
                onRemoveSessionCard: widget.actions.onRemoveSessionCard,
                onRefineSessionCard: widget.actions.onRefineSessionCard,
                onRenameSessionCard: widget.actions.onRenameSessionCard,
                onApplySession: widget.actions.onApplySession,
                onCancelSession: widget.actions.onCancelSession,
                onRulesChanged: widget.actions.onRulesChanged,
                onPreviewStoredRule: widget.actions.onPreviewStoredRule,
              ),
```

`infocutter_sidebar.dart`의 import 목록에 `infocutter_pick_tab.dart` 추가(part 파일이 참조하므로 부모 라이브러리 파일에 import).

- [ ] **Step 2: analyze**

Run: `fvm flutter analyze`
Expected: 0 issues. (`InfocutterSessionList`가 더 이상 「고르기」에서 안 쓰여도 위젯/테스트는 유지 — Task 4에서 타일/헬퍼만 재사용.)

- [ ] **Step 3: Commit**

```bash
git add apps/infocutter-app/lib/infocutter/ui/infocutter_sidebar.dart apps/infocutter-app/lib/infocutter/ui/infocutter_sidebar_tabs.dart
git commit -m "feat(infocutter-app): wire InfocutterPickTab into the 고르기 tab"
```

---

## Task 8: 「숨긴 목록」 슬림화 — `activeProfileId` 프로필 카드 숨김

매니저가 「고르기」 소유 프로필(`activeProfileId`)의 카드/규칙을 다시 보여주지 않게 한다. **그 외 매칭 프로필은 그대로 유지**(두 번째 enabled 프로필 실종 방지).

**Files:**
- Modify: `lib/infocutter/ui/infocutter_rule_manager.dart`
- Test: `test/infocutter/infocutter_rule_manager_slim_test.dart`

- [ ] **Step 1: 회귀 테스트 작성 (먼저 동작 정의)**

두 개의 매칭 프로필(A=active, B=other)을 가진 repository로 `InfocutterRuleManager(currentSiteOnly: true)`를 렌더 → A의 카드 펼침 영역은 안 보이고 B는 보임. (Provider로 fake repository 주입; `buildActiveSiteState`가 A.id를 activeProfileId로 반환.)

```dart
// test/infocutter/infocutter_rule_manager_slim_test.dart
// (fake repository는 Task 6 fake를 확장: profiles getter + buildActiveSiteState.)
// A 프로필의 카드명 '광고카드'는 매니저에서 안 보이고,
// B 프로필명 'B프로필'과 그 카드 'B카드'는 보여야 한다.
```

(구현 시 정확한 위젯 트리는 `_ProfileEditor`/`_CardEditor` 렌더 구조에 맞춰 `find.text('광고카드')`=findsNothing, `find.text('B카드')`=findsOneWidget 으로 단언.)

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/infocutter/infocutter_rule_manager_slim_test.dart`
Expected: FAIL — 현재는 A의 카드도 보임.

- [ ] **Step 3: 구현 — 활성 프로필의 카드만 숨김**

`InfocutterRuleManager`에 url로 activeProfileId를 구해, 그 프로필은 카드/규칙 children을 렌더하지 않게 한다. `_buildProfiles`에서 `_ProfileEditor`에 `hideCards: profile.id == activeProfileId` 플래그 전달:

```dart
// build() 안, profiles 계산 직후:
final activeProfileId = repository.buildActiveSiteState(url).activeProfileId;
```
```dart
// _buildProfiles(...) 에서:
(profile) => _ProfileEditor(
  actions: actions,
  profile: profile,
  hideCards: profile.id == activeProfileId,
),
```
`_ProfileEditor`에 `final bool hideCards;`(기본 false) 추가하고 `build`의 `children`에서:
```dart
children: [
  _buildProfileActions(context, l10n),
  if (!hideCards) ..._buildCards(cards, l10n)
  else Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(l10n.infocutterAppliedEditsLiveHint),
  ),
],
```
(활성 프로필 카드는 「고르기」에서 편집한다는 힌트만 남긴다.)

- [ ] **Step 4: 통과 + 기존 매니저 동작 회귀**

Run: `fvm flutter test test/infocutter/infocutter_rule_manager_slim_test.dart test/infocutter/infocutter_config_export_test.dart`
Expected: PASS. 프로필 관리/ import-export/ B프로필 카드 편집 유지.

- [ ] **Step 5: Commit**

```bash
git add apps/infocutter-app/lib/infocutter/ui/infocutter_rule_manager.dart test/infocutter/infocutter_rule_manager_slim_test.dart
git commit -m "feat(infocutter-app): slim 숨긴 목록 — hide active profile cards (now in 고르기)"
```

---

## Task 9: 프리뷰 ↔ 스테이징 하이라이트 충돌 수정

같은 탭에 적용 카드 프리뷰와 스테이징 하이라이트가 공존 → 프리뷰 종료 시 전부 지워 스테이징 번호 하이라이트가 사라짐. 종료 시 **스테이징 세션 하이라이트를 복원**한다.

**Files:**
- Modify: `lib/infocutter/infocutter_webview_coordinator.dart:230-236`

- [ ] **Step 1: finally 블록에서 복원으로 교체**

`previewStoredRule`의 `finally`에서:

```dart
    } finally {
      if (sequence == _previewSequence) {
        await _clearPreviewStyle(controller);
        await _setRuntimePeek(controller, enabled: false);
        // Restore the staged session's on-page numbered highlights instead of
        // clearing all highlights — the preview now shares the 「고르기」 tab with
        // live staged cards, so a blanket clear would wipe their badges.
        await _selectionSession.refreshHighlights();
      }
    }
```

(기존 `applyInfocutterSessionHighlights(controller, const [])` 줄을 제거하고 위 `refreshHighlights()`로 대체. 스테이징이 비어 있으면 `refreshHighlights`가 빈 목록을 칠해 사실상 clear와 동일.)

- [ ] **Step 2: analyze + 좌표/회귀 빌드 확인**

Run: `fvm flutter analyze && fvm flutter test test/infocutter/selection_session_controller_test.dart`
Expected: 0 issues, 기존 테스트 PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/infocutter-app/lib/infocutter/infocutter_webview_coordinator.dart
git commit -m "fix(infocutter-app): restore staged highlights after stored-rule preview"
```

---

## Task 10: 전체 검증 + 수동 실행

**Files:** (없음 — 게이트)

- [ ] **Step 1: 포맷/정적 분석**

Run: `dart format --output=none --set-exit-if-changed . && fvm flutter analyze`
Expected: 포맷 변경 없음, 0 issues.

- [ ] **Step 2: 전체 테스트**

Run: `fvm flutter test`
Expected: 전부 PASS (신규 4 파일 포함).

- [ ] **Step 3: 수동 실행 (AGENTS.md 검증 규칙)**

Run: `fvm flutter run -d macos`
확인:
- 「고르기」 탭에 "이미 숨긴 것"(데스크탑=펼침) + "지금 고르는 중" 동시 표시.
- 적용 카드 selector 인라인 수정 → **reload 없이** 페이지 반영. 이름 변경·켬/끔·삭제·모드 토글 동작.
- 적용 규칙 🔍 프리뷰 종료 후 스테이징 번호 하이라이트 유지.
- 「숨긴 목록」 탭: 활성 프로필 카드는 숨고 힌트만, 프로필 관리/import-export 유지.

- [ ] **Step 4: 최종 커밋 (스펙+플랜 포함)**

```bash
git add apps/infocutter-app/docs/pick-tab-applied-rules-inline-edit.md apps/infocutter-app/docs/pick-tab-applied-rules-inline-edit-plan.md
git commit -m "docs(infocutter-app): pick-tab applied-rules inline-edit spec + plan"
```

---

## 미해결/후속 (이번 범위 밖)

- 적용 카드 **라이브 매칭 카운트**: 배치 JS(`countMatchesMany`) + frameScope==null·지연 로딩으로 후속(스펙 §4.5).
- frameScope **인라인 편집**: v1은 읽기 전용 라벨. 필요 시 ⋮ 메뉴 + 다이얼로그 후속.
- 선택 범위 **부모로 키우기(depth)**: 잠자는 인프라 그대로, 별도 기능.
