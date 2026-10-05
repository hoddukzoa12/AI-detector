# Infocutter 옵션 페이지 탭 네비게이션 설계

- 날짜: 2026-05-30
- 상태: 승인됨 (구현 계획 대기)
- 베이스 브랜치: `feat/infocutter-modern-minimal-ui-20260530` (MR #45, 모던 미니멀 리디자인)
- 작업 브랜치: `feat/infocutter-options-tabs-20260530`

## 배경 / 문제

옵션 페이지(`public/options.html`)가 단일 스크롤 문서에 9개 `<section>`을 모두 쌓아두어
탐색이 어렵다. JS 컨트롤러(`src/options/index.ts`)도 1734줄 단일 파일이다.

`index.ts` 모듈화는 **별도 병렬 세션이 `refactor/infocutter-split-bloated-files-20260530`
브랜치에서 진행 중**이다 (추출 대상 모듈 파일은 생성됨, 단 `index.ts` 본체는 아직 미이동).
따라서 이번 작업은 코드 분리에 손대지 않고 **탭 UI만** 추가하여 그 리팩터링과 충돌하지 않는다.

## 목표

- 9개 섹션을 5개 탭으로 묶어 탐색성을 개선한다.
- 병렬 리팩터링과 **0충돌**: `index.ts` 무수정.
- MR #45의 모던 미니멀 디자인 톤을 계승한다.

## 비목표 (YAGNI)

- `index.ts` 모듈화 / 코드 분리 (병렬 세션 담당).
- 별도 HTML 파일로의 물리적 분리 (아래 "제약" 참고).
- 검색/필터 로직 변경 — 기존 `render()` 동작 그대로 둔다.
- 팝업(`popup.html`) 변경.

## 탭 구성 (5탭)

| 탭 | 포함 섹션 (기존 HTML 기준) |
| --- | --- |
| 선택자 규칙 | 프로필 추가, URL 매칭 테스트, 사이트 규칙 목록(`#site-list`/`#empty-state`) |
| 텍스트 블록 | 텍스트 기반 블록 숨김(생성/컨트롤), 텍스트 블록 목록(`#text-block-list`/empty) |
| 네트워크 필터 | AdGuard/ABP 필터 가져오기, 네트워크 규칙 목록(`#network-rule-list`/empty) |
| 템플릿 | 템플릿 서버 |
| 설정 / 상태 | 전역 상태(`#global-status`), 통계(`#summary`) |

전역 컨트롤(검색 `#search-input`, scope 필터 `#scope-filter`, 전역 끄기
`#toggle-global-button`, 새로고침 `#refresh-button`)은 탭바 위 **고정 헤더**에 둔다.
검색·scope·전역토글은 탭과 무관하게 항상 노출되며 동작은 변경하지 않는다.

## 제약 (반드시 충족)

1. **`elements.ts` 전수 조회 무결성** — `requiredElement(id, ...)`가 모듈 로드 시점에
   모든 섹션 요소를 조회하고 없으면 throw 한다. 따라서 모든 섹션은 DOM에 **그대로 남아야**
   하고, 비활성 탭은 CSS로 **hide만** 한다(요소 제거 금지). 이 때문에 물리적 멀티-HTML 분리는
   채택하지 않는다.
2. **`index.ts` 무접촉** — import 한 줄도 추가하지 않는다. 탭 모듈은 `options.html`에서
   별도 `<script type="module">`로 독립 로드한다.

## 변경 파일 (딱 3개)

### 1. `public/options.html`
- 상단에 고정 헤더(`<header>`): 타이틀 + 전역 컨트롤 4종 이동.
- `<nav role="tablist">`: 탭 버튼 5개 (`role="tab"`, `aria-selected`, `aria-controls`,
  `data-tab="selector|text|network|template|settings"`).
- 기존 9개 `<section>`을 5개 `<div role="tabpanel" id="panel-<key>" data-panel="<key>">`로 래핑.
  섹션 내부 마크업·ID는 **변경하지 않는다** (elements.ts 계약 유지).
- 본문 끝에 `<script type="module" src="src/options/tabs.js"></script>` 추가
  (기존 `index.js` 스크립트 태그는 유지).

### 2. `src/options/tabs.ts` (신규, 독립 모듈)
- `index.ts`를 import 하지 않는다.
- 동작:
  - `[role="tab"]` 클릭 → 해당 패널만 `.is-active`, 나머지 hide.
  - `aria-selected` 갱신, 키보드 접근성(←/→ 로 탭 이동, `tabindex` 관리).
  - 마지막 선택 탭을 `chrome.storage.local`(키 예: `infocutter:options-active-tab`)에
    저장하고 로드 시 복원. 저장값이 없거나 무효면 첫 탭("선택자 규칙").
- `chrome.storage` 접근 실패(예: 권한/컨텍스트 문제) 시 조용히 첫 탭으로 폴백.

### 3. `public/options.css`
- `.options__tablist`, `.options__tab`, `.options__tab[aria-selected="true"]`,
  `[role="tabpanel"]:not(.is-active) { display: none; }` 등 탭 스타일.
- MR #45의 토큰(`--accent`, `--surface`, `--border`, 라운드, 다크모드) 재사용.
- 활성 탭: accent 언더라인 또는 채움. 반응형(좁은 폭)에서 탭바 가로 스크롤 또는 래핑.

## 데이터 흐름

탭 전환은 **표시 전용**이다. `index.ts`의 `render()`/`scheduleRender()` 흐름과 storage
변경 리스너는 그대로 모든 패널의 콘텐츠를 렌더한다(숨겨진 패널 포함). `tabs.ts`는 어떤
패널이 보이는지만 제어하며 데이터/스토어를 건드리지 않는다.

## 에러 처리

- `tabs.ts`는 탭/패널 요소가 없으면(예: HTML 변경 누락) console 경고 후 무동작 — 페이지
  나머지 기능은 정상 동작해야 한다.
- `requiredElement`는 기존대로 누락 시 throw (계약 유지). 탭 래핑은 ID를 보존하므로 영향 없음.

## 테스트 / 검증

- `npm run pipe:check` (lint + typecheck + node:test) 통과.
- chrome-devtools MCP로 `dist/options.html` 로드 후:
  - 5개 탭 클릭 시 해당 패널만 노출되는지 스크린샷 확인 (라이트/다크).
  - 새로고침 후 마지막 탭 복원되는지 확인.
  - 기존 폼/목록 요소가 모두 존재하고 `elements.ts`가 throw하지 않는지(콘솔) 확인.
- no-comments 게이트: `tabs.ts`는 `// ...` 라인 주석 금지(블록 주석만), 컨벤션 준수.

## 시퀀싱 / 리스크

- 베이스를 MR #45 브랜치로 두어 새 탭 CSS가 모던 톤과 일관. #45 머지 후 자동 정합.
- 잔여 충돌 리스크: 병렬 리팩터링이 `options.html`을 건드리면 충돌 — 현재 그 브랜치는
  `options.html` 미변경 확인됨. 머지 순서상 탭 MR이 늦게 머지되면 표준 rebase로 해소.
