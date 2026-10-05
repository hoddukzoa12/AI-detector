# 「고르기」 탭 통합 — 적용 중 규칙 인라인 편집

작성: 2026-06-14 · 상태: Draft v2 (설계 승인 + 4-렌즈 코드 비평 반영) · 구현 전

> v2 변경: 4개 독립 비평(아키텍처/UX/회귀/데이터)을 코드 근거로 반영. Q1~Q4 결론 확정, §4.4 배선 정정, 다중 규칙 카드를 주류로 재설정, 안정 식별/포커스 위험·프리뷰 하이라이트 충돌·다중 프로필 위험 추가.

## 1. 배경 / 문제

블록 차단 패널(가위)은 두 탭으로 나뉜다.

- **「고르기」** (`InfocutterSessionList`): 피커로 *이번에 새로 찍은* 카드(스테이징)만 보여주고, 한꺼번에 적용/취소.
- **「숨긴 목록」** (`InfocutterSiteTab` → `InfocutterRuleManager`): *이미 적용된* 규칙을 프로필 > 카드 > 규칙 트리로 관리.

이미 숨긴 블록을 살짝 고치려면 동선이 너무 깊다:
「고르기」 떠남 → 「숨긴 목록」 탭 → 프로필 펼침 → 카드 펼침 → 규칙 `⋮` 메뉴 → 다이얼로그.
일상 편집(이름 바꾸기, selector 조정, 켬/끔, 삭제)이 전부 탭 이동 + 중첩 펼침 + 모달 뒤에 있다.

## 2. 목표

「고르기」 한 화면에서 **"이미 숨긴 것"과 "지금 고르는 중"을 같이** 보고, 적용 중 규칙도 **그 자리에서 인라인 편집**(다이얼로그 없이). 「숨긴 목록」 탭은 고급/사이트 관리만 남기고 슬림화.

비목표(out of scope): 선택 범위를 부모로 키우는 depth 기능(별도 후속), 다른 모듈(키워드/워치/네트워크) 탭, 멀티 사이트 일괄 편집, 적용 카드 라이브 매칭 카운트(§4.5 — v1 보류).

## 3. 현재 코드 지도 (확인 완료)

| 요소 | 위치 | 역할 |
|---|---|---|
| 블록 패널 2탭 | `ui/infocutter_sidebar_tabs.dart` `_InfocutterBlockPanel` | 「고르기」/「숨긴 목록」 TabController, 탭 전환 시 피커 resume/pause |
| 스테이징 리스트 | `ui/infocutter_session_list.dart` | `SelectionCard` 카드 + 이름/selector 인라인 편집 + 다음 기준 + 적용/취소. 레이아웃 = `Column[Expanded(ListView.builder), Divider, footer]` |
| 적용 규칙 관리 | `ui/infocutter_site_tab.dart`, `ui/infocutter_rule_manager.dart` (+ `_actions`) | 프로필>카드>규칙 트리, 다이얼로그 편집 |
| 편집 액션 | `ui/infocutter_rule_manager_actions.dart` `_RuleManagerActions` | `repository.*` 래핑 + `onRulesChanged()` |
| 적용 데이터 | `models.dart` `ActiveSiteState` | `activeProfileId`(nullable) + `cards: List<SavedCard>` (현재 사이트 **첫 매칭** 프로필) |
| 사이트 상태 빌드 | `BlockRuleRepository.buildActiveSiteState(url)` → `infocutter_runtime_builder.dart` `_findProfileForUrlInSnapshot` | **첫 매칭 프로필 1개**만 반환 |
| 라이브 적용 런타임 | `__infocutterRuntime.apply` (`selector_engine.dart` renderNow + MutationObserver) | marker 속성으로 hide/unhide, apply마다 재렌더 → **reload 없이 라이브 반영** |
| content blocker | `content_blocker_factory.dart` | WebKit CSS hide. **frameScope!=null 규칙 제외**, navigation 때만 갱신(중복 fallback 레이어) |
| 라이브 매칭 카운트 | 피커 JS `countMatches` (`selector_engine.dart:901`) | `active` 상태 무관(스크립트 상시 주입). 단 `evaluateJavascript`는 **메인 프레임만** |
| 사이드바 DTO | `ui/infocutter_sidebar.dart` `InfocutterSidebarData/Actions` | `url`·`onRulesChanged`·`onPreviewStoredRule` **이미 존재**, 블록 패널까지 도달 |
| repository 제공 | `infocutter_providers.dart` `ListenableProxyProvider<…, BlockRuleRepository>` | `context.watch`로 소비, 변경 시 rebuild (site_tab이 그렇게 함) |

핵심: 데이터(`ActiveSiteState.cards`)·편집 액션·라이브 적용 경로가 **이미 다 존재**. 신규는 표면(UI) + 합성 + 액션 가시성 공개.

## 4. 설계

### 4.1 「고르기」 탭 — 적용 섹션(접힘) + 스테이징 + 고정 footer

새 위젯 `ui/infocutter_pick_tab.dart`가 레이아웃을 소유한다 (기존 `InfocutterSessionList`를 다른 스크롤에 끼우면 unbounded-height 충돌 → 합성 위젯이 직접 구성).

```
 [ 고르기 ]   숨긴 목록
 ┌──────────────────────────────┐
 │ ▸ 이미 숨긴 것 (N)   [펼치기] │ ← 기본 접힘, 개수 칩. 펼치면 적용 카드
 │   "여기 수정은 즉시 반영"     │
 ├──────────────────────────────┤
 │ 지금 고르는 중 (M)            │ ← 스크롤 영역
 │   [스테이징 카드들…]          │
 ├──────────────────────────────┤
 │ [ 새로 고른 M개 적용 ] [취소] │ ← footer 고정(스크롤 밖), M>0 일 때만
 └──────────────────────────────┘
```

- **"이미 숨긴 것" 기본 상태는 화면 폭 반응형** + 개수 칩(N), 언제나 수동 토글 가능. 넓은 화면(데스크탑/태블릿, 기존 width 브레이크포인트 재사용)은 **기본 펼침**(편집 즉시 접근), 좁은 화면(폰 ~92% 폭)은 **기본 접힘**(편집 필드 가득한 긴 스크롤이 키보드와 겹쳐 픽-적용 주 흐름을 묻는 것 방지). 양쪽 요구를 모두 충족.
- **스테이징 + 적용/취소 footer는 항상 보이게 고정**(스크롤 밖, 현재 session_list가 `Expanded+Divider+footer`로 하던 방식 유지). 적용 게이팅(`_canApply`)·M==0 시 footer 숨김 보존.
- `activeProfileId == null`(활성 프로필 없음) → "이미 숨긴 것" 섹션 자체 숨김 → 스테이징/안내만.
- 둘 다 비면: 기존 "탭해서 고르세요" 안내(`infocutterSessionPickHint`).

### 4.2 적용 카드 타일 — 다중 규칙을 1차 케이스로

단위 = `SavedCard`. **주 케이스는 카드 1개 안에 규칙 N개**(한 페이지에서 여러 개 찍으면 같은 기본 카드명으로 묶여 `addRule`이 한 카드에 누적 — `coordinator:130` + `rule_mutations:17`). 단일 규칙은 그 특수 케이스로 취급(역순 주의).

**카드 헤더 (카드 단위)**
- 이름: 인라인 `TextField`, blur commit → `renameCard(profileId, cardId, name)`
- 켬/끔: `Switch` → `setCardEnabled(profileId, cardId, enabled)`
- 삭제: 확인(`showInfocutterDeleteConfirmation`) → `removeCard(profileId, cardId)`
- 배지: **번호/색 배지 재사용 금지**. 스테이징의 번호색 배지는 on-page 하이라이트와 lockstep(`kInfocutterSessionColors`)이라 적용 카드에 쓰면 없는 하이라이트를 암시함 → 적용 카드는 중립 아이콘 배지(차분).

**규칙 행 (규칙마다, 카드 안 `rules`)**
- selector: 인라인 `TextField`, blur commit → `updateStoredRule(selector:)`
- 모드: hide↔unhide 토글을 **기존 아이콘 어휘 재사용**(`visibility_off`/`visibility`, 48dp 아이콘 버튼) → `updateStoredRule(mode:)`. 새 칩 만들지 않음.
- frameScope: 기본은 **읽기 전용 메타 라벨**("메인 프레임" / origin). 인라인 상시 필드 금지(대부분 null·불투명 문자열·거의 안 고침). 편집은 탭 시 노출 또는 기존 다이얼로그 유지.
- 규칙별 삭제(규칙 ≥2): `removeStoredRule(targetRule:)`
- 🔍 위치 표시(프리뷰): §5.1 충돌 처리 전제. "대표 규칙" = 단일 규칙/단일 프레임 카드면 그 규칙, 다중이면 `rules[0]` 또는 카드 단위 프리뷰 생략.

**식별/포커스 안정성 (필수)** — StoredRule엔 안정 id가 없고 편집은 풀 값 매칭(`isSameStoredRule`).
- 규칙 행 위젯 키 = `(cardId, createdAt)` 기반(편집해도 안정 — `createdAt`은 update에서 유지). import 등 동일 타임스탬프 충돌 시 카드 내 index 보조.
- 커밋 시 **캡처해 둔 stale `targetRule`을 쓰지 말고**, 최신 `ActiveSiteState`에서 `(cardId, createdAt)`로 규칙을 재조회해 mutation에 넘긴다(연속 편집이 무시되는 silent no-op 방지).
- `_SessionCardTile`의 `didUpdateWidget` 포커스 가드(`!hasFocus`일 때만 컨트롤러 갱신) + blur commit 패턴을 그대로 이식. `context.watch` rebuild가 편집 중 필드를 덮지 않게.

### 4.3 「숨긴 목록」 탭 슬림화 — 프로필 소유권 명확화

- 남김: 전체 토글(`globalEnabled`), 사이트 지표, **프로필** 관리(생성/이름/매처/켬끔/삭제), JSON 가져오기·내보내기.
- 뺌: **`activeProfileId`에 해당하는 정확히 그 프로필**의 카드/규칙 드릴다운(→ 「고르기」가 소유).
- 유지: 그 외 사이트에 매칭되는 **모든** 프로필(enabled/disabled 무관)의 카드/규칙 — 매니저에 그대로. (위험: 두 enabled 프로필이 매칭되면 content blocker는 둘 다 적용하지만 「고르기」는 첫 프로필만 보여줌 → 두 번째 프로필을 매니저에서도 빼면 두 탭 모두에서 편집 불가가 됨. 그래서 **정확히 activeProfileId만** 제외.)
- 일반(단일 프로필) 케이스: 「숨긴 목록」 = 프로필 설정 + import/export + 지표만 → 깔끔.

### 4.4 구조 / 파일 (정정)

- **이미 있는 것 재사용**: `InfocutterSidebarData.url`, `InfocutterSidebarActions.onRulesChanged`, `…onPreviewStoredRule`는 **이미 블록 패널에 도달**(SiteTab에 그대로 전달 중). → DTO 확장 불필요. 「고르기」 합성 위젯에 그대로 forward.
- **repository는 `context.watch<BlockRuleRepository>()`로** 위젯 안에서 획득(SiteTab과 동일). DTO/생성자로 스냅샷 주입 금지(스냅샷은 session 변경 때만 rebuild → 인라인 편집 미반영).
- **액션 추출**: `_RuleManagerActions`(private, part-of) → 공용 `ui/infocutter_stored_rule_actions.dart`(public class, no part-of). 가시성만 공개, 동작·`onRulesChanged` 의미 동일. `application/`이 아닌 `ui/`에 둠(UI 콜백 `onPreviewRule`/`onRulesChanged` 보유 = presentation glue, 도메인 아님). import 방향 ui→application 정상, 사이클 없음.
- **신규 위젯**: `ui/infocutter_applied_cards.dart`(적용 섹션 + 적용 카드 타일, StatefulWidget, §4.2 안정성 패턴), `ui/infocutter_pick_tab.dart`(접힘 적용 섹션 + 스테이징 + 고정 footer 합성). 스테이징 타일은 자체 스크롤 위젯이 아니라 children로 재사용 가능하게 정리.
- **갱신 경로**: 인라인 편집 → 공용 액션 → `repository.*` → `onRulesChanged()` → `__infocutterRuntime.apply`(reload 없음). (Q1 결론, §7.)
- **l10n**: 신규 키 — `app_en.arb`(템플릿) + `app_ko.arb` 둘만 존재(ja 없음). 섹션 헤더("이미 숨긴 것"/"지금 고르는 중"), "여기 수정은 즉시 반영" 안내, 접힘/펼침 라벨. 모드/프레임/삭제/이름은 기존 키 재사용(`infocutterRuleModeHide/Unhide`, `infocutterMainFrame`, `infocutterFrameScope`, `infocutterDelete`, `infocutterCardName`, `infocutterSelector`, `infocutterSavedRules`).

### 4.5 매칭 카운트 — v1은 정적 `ruleCount` (라이브 보류)

- 적용 카드/규칙에 **라이브 카운트 미표시**. 대신 정적 `SavedCard.ruleCount`("규칙 N개")만.
- 이유: (1) `evaluateJavascript`는 메인 프레임만 → `frameScope!=null` 규칙은 틀린 0/-1 → 기존 UI가 빨강 "invalid selector"로 오표시. (2) 배칭 없음 → N규칙 = N직렬 라운드트립이 매 편집마다 재실행, content blocker 갱신 후 즉시 stale.
- 후속(별도): `countMatchesMany(selectors[])` 배치 JS 추가 + frameScope==null·지연(섹션 펼칠 때만) 조건으로 라이브 카운트 도입.
- 참고: "피커 활성 중에만 카운트 가능"은 사실이 아님(스크립트 상시 주입). 보류 사유는 프레임/배칭 문제일 뿐.

## 5. 엣지/결정

1. **프리뷰 ↔ 스테이징 하이라이트 충돌 (구현 전 필수 수정)**: `previewStoredRule`는 단일 on-page 하이라이트 채널을 공유하고 종료 시 `finally`에서 전부 `[]`로 지움 + "peek"(모든 차단 요소 임시 노출) 토글. 지금은 탭이 갈려 안 부딪히지만 같은 탭에 두면 스테이징 번호 하이라이트가 사라짐. → 프리뷰 종료 후 **현재 스테이징 세션 하이라이트 복원**(repaintHighlights 재호출) 또는 프리뷰 전용 레이어 분리. peek가 스테이징 중 적절한지도 결정.
2. **피커 활성 중 인라인 편집**: 사이드바 텍스트 편집은 페이지 탭과 무관(스테이징 카드가 이미 동일). 단 §4.2 포커스 가드 필수.
3. **다중 매칭 프로필**: 「고르기」는 첫(active) 프로필만; 그 외는 「숨긴 목록」(§4.3). 두 번째 enabled 프로필 라이브 반영은 reload-only일 수 있음 — 매니저 편집은 그대로 동작.
4. **frameScope 규칙**: content blocker 제외 → JS 런타임만. 백그라운드/오프스크린 서브프레임은 런타임 없을 수 있음(기존 MEMORY 이슈). 라이브 효과는 메인/활성 프레임 한정 — 문서화로 수용.
5. **활성 프로필 없음**: "이미 숨긴 것" 숨김 → 스테이징 + 안내.

## 6. 테스트

- 위젯: seeded repository(**규칙 2개+인 카드** = 실제 피커 산출물)로 「고르기」 적용 섹션 렌더 → 펼침/접힘, 이름/selector 인라인 커밋이 `updateStoredRule`/`renameCard` 호출, 모드 아이콘 토글, 규칙/카드 삭제, 스테이징 공존, footer 게이팅.
- 포커스 회귀: 한 필드 편집→다른 필드로 이동 시 커밋 발생해도 포커스/커서 유지, 연속 편집이 silent no-op 안 됨.
- 다중 프로필 회귀: 두 enabled 프로필이 매칭되는 사이트 → 프로필 A는 「고르기」, 프로필 B는 슬림 「숨긴 목록」에 여전히 편집 가능, 어느 쪽도 누락 없음.
- 프리뷰 회귀: 적용 카드 프리뷰 종료 후 스테이징 번호 하이라이트 복원 확인.
- 수동(macOS run, AGENTS.md 검증 규칙): 실제 사이트에서 적용 규칙 selector 인라인 수정 → **reload 없이** 페이지 반영, 모드 토글, 삭제 확인.

## 7. 결론 / 열린 질문

**Q1 — 편집 후 reload 필요? → 아니오(닫힘).** 3-렌즈 코드 검증: `onRulesChanged`(reload 없음) → `__infocutterRuntime.apply`가 marker+MutationObserver로 매 apply 재렌더 → `frameScope==null` hide/unhide 규칙은 라이브 반영. 「숨긴 목록」이 이미 같은 경로라 신규 회귀 없음. WebKit content blocker는 navigation까지 lag하는 중복 fallback(기존 동작, 수용).

**Q2 — 라이브 매칭 카운트? → v1 보류(정적 ruleCount).** §4.5. 프레임/배칭 문제. 배치 JS는 후속.

**Q3 — 적용 vs 스테이징 시각 구분? → 의도적 구분.** 적용 = 중립 아이콘 배지·차분·즉시 반영(섹션 헤더에 "여기 수정은 즉시 반영"); 스테이징 = 번호색 배지 + 적용/취소. 번호색 배지는 스테이징 전용(on-page 하이라이트 매핑).

**Q4 — "이미 숨긴 것" 기본 상태? → 화면 폭 반응형.** 넓은 화면 기본 펼침, 폰 기본 접힘, 개수 칩 + 수동 토글, 스테이징/footer 고정. (§4.1)

**확정된 결정 (사용자 승인)**
- D1 = **화면 폭 반응형**. 데스크탑/태블릿 펼침(편집 즉시 접근, 원래 불만 해소), 폰 접힘(키보드 겹침 방지). 기존 width 브레이크포인트 재사용.
- D2 = **커밋 시 재조회**. 인라인 편집 커밋 시 최신 `ActiveSiteState`에서 `(cardId, createdAt)`로 규칙 재조회 후 mutation 호출. 공유 `updateStoredRule` 매칭 로직은 무수정(매니저 영향 없음).
