# Infocutter 옵션 탭 네비게이션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 옵션 페이지의 9개 섹션을 5개 탭으로 묶어 한 HTML 안에서 show/hide 한다.

**Architecture:** 모든 섹션을 DOM에 유지하고 비활성 탭만 `hidden`으로 숨긴다. 독립 모듈 `src/options/tabs.ts`가 `options.html`에서 별도 로드되어 탭 전환·접근성·마지막 탭 기억을 담당하며, `index.ts`는 일절 건드리지 않는다(병렬 리팩터링과 0충돌).

**Tech Stack:** TypeScript → tsc, Manifest V3 content/options, `chrome.storage.local`, node:test, chrome-devtools MCP.

**Spec:** `docs/superpowers/specs/2026-05-30-options-tabs-design.md`

**작업 디렉터리:** `vibecode-chrome-extension-infocutter/` (모든 경로는 이 디렉터리 기준)
**브랜치:** `feat/infocutter-options-tabs-20260530` (이미 체크아웃됨, base = MR #45 redesign)

---

## File Structure

- Create: `src/options/tabs.ts` — 탭 컨트롤러 + 순수 헬퍼 `resolveActiveTab`. `index.ts` import 없음.
- Modify: `tests/selector.test.ts` — `resolveActiveTab` 단위 테스트 2개 추가 (별도 러너 설정 불필요).
- Modify: `public/options.html` — 헤더/탭바/5개 패널로 재구성 + `tabs.js` 스크립트 태그.
- Modify: `public/options.css` — 탭바/패널 스타일 (MR #45 토큰 재사용).

> 섹션 내부 마크업과 모든 `id` 는 변경 금지 (`elements.ts` 의 `requiredElement` 계약 유지).

---

### Task 1: 순수 헬퍼 `resolveActiveTab` (TDD)

**Files:**
- Create: `src/options/tabs.ts`
- Test: `tests/selector.test.ts` (기존 파일에 추가)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/selector.test.ts` 상단 import 블록 마지막 줄 아래에 추가:

```ts
import { resolveActiveTab } from "../src/options/tabs.js";
```

같은 파일 맨 끝에 추가:

```ts
void test("resolveActiveTab keeps a stored key when it is valid", () => {
  assert.equal(
    resolveActiveTab("network", ["selector", "network", "template"]),
    "network"
  );
});

void test("resolveActiveTab falls back to the first key when stored is missing or invalid", () => {
  assert.equal(resolveActiveTab(null, ["selector", "text"]), "selector");
  assert.equal(resolveActiveTab("bogus", ["selector", "text"]), "selector");
  assert.equal(resolveActiveTab(undefined, ["selector", "text"]), "selector");
});
```

- [ ] **Step 2: 테스트가 실패(컴파일 실패)하는지 확인**

Run: `npm run pipe:build`
Expected: FAIL — `Cannot find module '../src/options/tabs.js'` 또는 tsc 에러 (tabs.ts 없음).

- [ ] **Step 3: 최소 구현 — tabs.ts 생성 (헬퍼만)**

`src/options/tabs.ts`:

```ts
const ACTIVE_TAB_STORAGE_KEY = "infocutter:options-active-tab";

export function resolveActiveTab(
  stored: string | null | undefined,
  validKeys: readonly string[]
): string {
  if (stored && validKeys.includes(stored)) {
    return stored;
  }
  return validKeys[0] ?? "";
}

export { ACTIVE_TAB_STORAGE_KEY };
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `npm run pipe:test`
Expected: PASS — 신규 테스트 2개 포함 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add vibecode-chrome-extension-infocutter/src/options/tabs.ts vibecode-chrome-extension-infocutter/tests/selector.test.ts
git commit -m "feat(infocutter): add resolveActiveTab tab-state helper"
```

---

### Task 2: 탭 DOM 컨트롤러 (tabs.ts 완성)

**Files:**
- Modify: `src/options/tabs.ts`

검증은 Task 5의 chrome-devtools MCP 에서 수행한다(DOM/`chrome.storage` 의존이라 단위 테스트 비대상). 여기서는 타입/빌드 그린만 확인한다.

- [ ] **Step 1: tabs.ts 를 아래 전체 내용으로 교체**

`src/options/tabs.ts`:

```ts
const ACTIVE_TAB_STORAGE_KEY = "infocutter:options-active-tab";

export function resolveActiveTab(
  stored: string | null | undefined,
  validKeys: readonly string[]
): string {
  if (stored && validKeys.includes(stored)) {
    return stored;
  }
  return validKeys[0] ?? "";
}

function readStoredTab(): Promise<string | null> {
  return new Promise((resolve) => {
    try {
      chrome.storage.local.get(ACTIVE_TAB_STORAGE_KEY, (items) => {
        const value = items?.[ACTIVE_TAB_STORAGE_KEY];
        resolve(typeof value === "string" ? value : null);
      });
    } catch {
      resolve(null);
    }
  });
}

function writeStoredTab(key: string): void {
  try {
    void chrome.storage.local.set({ [ACTIVE_TAB_STORAGE_KEY]: key });
  } catch {
    /* storage unavailable; ignore */
  }
}

function applyActiveTab(
  key: string,
  tabs: HTMLElement[],
  panels: HTMLElement[]
): void {
  for (const tab of tabs) {
    const isActive = tab.dataset.tab === key;
    tab.setAttribute("aria-selected", isActive ? "true" : "false");
    tab.tabIndex = isActive ? 0 : -1;
  }
  for (const panel of panels) {
    panel.hidden = panel.dataset.panel !== key;
  }
}

async function initTabs(): Promise<void> {
  const tablist = document.querySelector<HTMLElement>('[role="tablist"]');
  const tabs = Array.from(
    document.querySelectorAll<HTMLElement>('[role="tab"]')
  );
  const panels = Array.from(
    document.querySelectorAll<HTMLElement>('[role="tabpanel"]')
  );
  if (!tablist || tabs.length === 0 || panels.length === 0) {
    console.warn("[infocutter] options tabs missing; skipping tab init");
    return;
  }

  const validKeys = tabs
    .map((tab) => tab.dataset.tab ?? "")
    .filter((key) => key.length > 0);

  const stored = await readStoredTab();
  applyActiveTab(resolveActiveTab(stored, validKeys), tabs, panels);

  for (const tab of tabs) {
    tab.addEventListener("click", () => {
      const key = tab.dataset.tab;
      if (key) {
        applyActiveTab(key, tabs, panels);
        writeStoredTab(key);
      }
    });
  }

  tablist.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") {
      return;
    }
    const currentIndex = tabs.findIndex(
      (tab) => tab.getAttribute("aria-selected") === "true"
    );
    if (currentIndex === -1) {
      return;
    }
    const delta = event.key === "ArrowRight" ? 1 : -1;
    const nextTab = tabs[(currentIndex + delta + tabs.length) % tabs.length];
    const nextKey = nextTab.dataset.tab;
    if (nextKey) {
      applyActiveTab(nextKey, tabs, panels);
      writeStoredTab(nextKey);
      nextTab.focus();
    }
  });
}

if (typeof document !== "undefined") {
  void initTabs();
}

export { ACTIVE_TAB_STORAGE_KEY };
```

> 주의: `//` 라인 주석 금지(no-comments 게이트). 위 빈 `catch` 의 블록 주석은 `no-empty` 회피용으로 허용된다.

- [ ] **Step 2: 타입/빌드 + 기존 테스트 그린 확인**

Run: `npm run pipe:build && npm run pipe:test`
Expected: PASS — tsc 에러 없음, `resolveActiveTab` 테스트 여전히 통과(`typeof document` 가드로 node import 시 initTabs 미실행).

- [ ] **Step 3: 커밋**

```bash
git add vibecode-chrome-extension-infocutter/src/options/tabs.ts
git commit -m "feat(infocutter): implement options tab controller with persistence"
```

---

### Task 3: options.html 재구성 (헤더 + 탭바 + 5 패널)

**Files:**
- Modify: `public/options.html`

- [ ] **Step 1: `public/options.html` 을 아래 전체 내용으로 교체**

```html
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>인포커터 관리</title>
    <link rel="stylesheet" href="./options.css" />
  </head>
  <body>
    <main class="options">
      <header class="options__header">
        <div class="options__titlebar">
          <p class="options__eyebrow">인포커터 관리자</p>
          <h1 class="options__title">규칙 관리</h1>
        </div>
        <section class="options__toolbar">
          <input id="search-input" class="options__input" type="search" placeholder="사이트, 선택자, 텍스트 규칙 검색" />
          <select id="scope-filter" class="options__select">
            <option value="all">전체 규칙</option>
            <option value="main">메인 문서 규칙</option>
            <option value="iframe">iframe 규칙</option>
          </select>
          <button id="refresh-button" type="button">새로고침</button>
          <button id="toggle-global-button" type="button" class="options__secondary">전체 끄기</button>
        </section>
      </header>

      <nav class="options__tablist" role="tablist" aria-label="설정 메뉴">
        <button class="options__tab" type="button" role="tab" id="tab-selector" data-tab="selector" aria-controls="panel-selector" aria-selected="true">선택자 규칙</button>
        <button class="options__tab" type="button" role="tab" id="tab-text" data-tab="text" aria-controls="panel-text" aria-selected="false" tabindex="-1">텍스트 블록</button>
        <button class="options__tab" type="button" role="tab" id="tab-network" data-tab="network" aria-controls="panel-network" aria-selected="false" tabindex="-1">네트워크 필터</button>
        <button class="options__tab" type="button" role="tab" id="tab-template" data-tab="template" aria-controls="panel-template" aria-selected="false" tabindex="-1">템플릿</button>
        <button class="options__tab" type="button" role="tab" id="tab-settings" data-tab="settings" aria-controls="panel-settings" aria-selected="false" tabindex="-1">설정 / 상태</button>
      </nav>

      <div class="options__panel" role="tabpanel" id="panel-selector" data-panel="selector" aria-labelledby="tab-selector">
        <section class="options__create-card">
          <h2 class="options__section-title">프로필 추가</h2>
          <div class="options__create-grid">
            <input id="new-profile-name" class="options__input" type="text" placeholder="프로필 이름" />
            <input id="new-profile-matcher" class="options__input" type="text" placeholder="예: https://mail.naver.com/*" />
            <button id="create-profile-button" type="button">프로필 만들기</button>
          </div>
        </section>

        <section class="options__create-card">
          <h2 class="options__section-title">URL 매칭 테스트</h2>
          <div class="options__create-grid">
            <input id="url-test-input" class="options__input" type="text" placeholder="예: https://mail.naver.com/v3/" />
            <button id="url-test-button" type="button">매칭 확인</button>
          </div>
          <p id="url-test-result" class="options__meta">테스트할 URL을 입력하면 현재 우선순위 기준으로 어떤 프로필이 적용되는지 보여줍니다.</p>
        </section>

        <section class="options__list-wrap">
          <div id="site-list" class="options__site-list"></div>
          <p id="empty-state" class="options__empty">조건에 맞는 규칙이 없습니다.</p>
        </section>
      </div>

      <div class="options__panel" role="tabpanel" id="panel-text" data-panel="text" aria-labelledby="tab-text" hidden>
        <section class="options__create-card">
          <h2 class="options__section-title">텍스트 기반 블록 숨김</h2>
          <div class="options__text-block-grid">
            <input id="text-block-profile-name" class="options__input" type="text" placeholder="텍스트 프로필 이름" />
            <input id="text-block-matcher" class="options__input" type="text" placeholder="예: https://www.naver.com/*" />
            <input id="text-block-object-name" class="options__input" type="text" placeholder="오브젝트 이름" />
            <input id="text-block-object-tags" class="options__input" type="text" placeholder="태그 예: ad" />
            <input id="text-block-keyword" class="options__input" type="text" placeholder="숨길 키워드 또는 문구" />
            <input id="text-block-min-match-count" class="options__input" type="number" min="2" step="1" value="2" />
            <button id="text-block-create-button" type="button">텍스트 규칙 추가</button>
          </div>
          <div class="options__template-actions">
            <button id="text-block-toggle-global-button" type="button" class="options__secondary">텍스트 규칙 전체 켜기</button>
            <button id="text-block-toggle-ad-tag-button" type="button" class="options__secondary">ad 태그 숨김 끄기</button>
          </div>
          <div class="options__tag-toolbar">
            <input id="text-block-hidden-tag-input" class="options__input" type="text" placeholder="숨김 태그 추가 예: sponsored" />
            <button id="text-block-add-hidden-tag-button" type="button" class="options__secondary">숨김 태그 추가</button>
          </div>
          <div id="text-block-hidden-tag-list" class="options__tag-list"></div>
          <div class="options__preview-toolbar">
            <select id="text-block-preview-tab" class="options__select"></select>
            <button id="text-block-refresh-tabs-button" type="button" class="options__secondary">진단 탭 새로고침</button>
            <button id="text-block-open-tab-button" type="button" class="options__secondary">진단 탭으로 이동</button>
          </div>
          <p id="text-block-preview-status" class="options__meta">진단 대상 탭을 불러오는 중...</p>
          <p id="text-block-global-status" class="options__meta">텍스트 기반 블록 숨김 상태를 불러오는 중...</p>
          <p id="text-block-summary" class="options__meta">텍스트 규칙 통계를 불러오는 중...</p>
          <p class="options__meta">같은 구조의 블록이 최소 N개 이상 잡혔을 때만 숨깁니다. 기존 선택자 카드 기능과는 별도 저장소로 관리됩니다.</p>
        </section>

        <section class="options__list-wrap">
          <div id="text-block-list" class="options__site-list"></div>
          <p id="text-block-empty-state" class="options__empty">텍스트 기반 블록 규칙이 없습니다.</p>
        </section>
      </div>

      <div class="options__panel" role="tabpanel" id="panel-network" data-panel="network" aria-labelledby="tab-network" hidden>
        <section class="options__create-card">
          <h2 class="options__section-title">AdGuard/ABP 필터 가져오기</h2>
          <textarea id="filter-import-input" class="options__input options__rule-editor" placeholder="예:&#10;example.com##.ad-banner&#10;example.com#?#article:contains(&quot;광고&quot;)"></textarea>
          <div class="options__template-actions">
            <button id="filter-import-preview-button" type="button" class="options__secondary">가져오기 미리보기</button>
            <button id="filter-import-apply-button" type="button">지원 규칙 저장</button>
          </div>
          <p id="filter-import-status" class="options__meta">cosmetic selector와 text 조건 규칙은 인포커터 프로필/오브젝트로, 지원되는 네트워크 규칙은 Chrome DNR 동적 규칙으로 가져옵니다.</p>
        </section>

        <section class="options__list-wrap">
          <div id="network-rule-list" class="options__site-list"></div>
          <p id="network-rule-empty-state" class="options__empty">저장된 네트워크 차단 규칙이 없습니다.</p>
        </section>
      </div>

      <div class="options__panel" role="tabpanel" id="panel-template" data-panel="template" aria-labelledby="tab-template" hidden>
        <section class="options__create-card">
          <h2 class="options__section-title">템플릿 서버</h2>
          <div class="options__template-toolbar">
            <input id="template-server-url" class="options__input" type="text" placeholder="예: http://127.0.0.1:41800" />
            <input id="template-server-token" class="options__input" type="password" placeholder="선택 사항: 서버 토큰" />
            <button id="refresh-templates-button" type="button">템플릿 불러오기</button>
          </div>
          <p id="template-status" class="options__meta">로컬 또는 자체 호스팅 템플릿 서버를 연결해 네이버 같은 사이트용 템플릿을 불러와 적용할 수 있습니다.</p>
          <div id="template-list" class="options__template-list"></div>
        </section>
      </div>

      <div class="options__panel" role="tabpanel" id="panel-settings" data-panel="settings" aria-labelledby="tab-settings" hidden>
        <section class="options__status-card">
          <p id="global-status" class="options__meta">전역 상태를 불러오는 중...</p>
          <p id="summary" class="options__meta">규칙 통계를 불러오는 중...</p>
        </section>
      </div>

      <script type="module" src="src/options/index.js"></script>
      <script type="module" src="src/options/tabs.js"></script>
    </main>
  </body>
</html>
```

> 모든 `id` 가 원본과 동일한지 확인: `search-input, scope-filter, refresh-button, toggle-global-button, new-profile-name, new-profile-matcher, create-profile-button, url-test-input, url-test-button, url-test-result, site-list, empty-state, text-block-*(13개), text-block-list, text-block-empty-state, filter-import-*(4개), network-rule-list, network-rule-empty-state, template-server-url, template-server-token, refresh-templates-button, template-status, template-list, global-status, summary`.

- [ ] **Step 2: 빌드 + dist 반영 확인**

Run: `npm run pipe:build`
Expected: PASS, `dist/options.html` 갱신.

- [ ] **Step 3: 커밋**

```bash
git add vibecode-chrome-extension-infocutter/public/options.html
git commit -m "feat(infocutter): wrap options sections into 5 tab panels"
```

---

### Task 4: 탭바/패널 CSS

**Files:**
- Modify: `public/options.css`

- [ ] **Step 1: 헤더 레이아웃 보정** — `public/options.css` 의 `.options__header { margin-bottom: 24px; }` 블록 바로 아래에 추가:

```css
.options__titlebar {
  margin-bottom: 16px;
}
```

- [ ] **Step 2: 탭바/패널 스타일 추가** — `.options__toolbar { ... }` 블록 바로 아래에 추가:

```css
.options__tablist {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 20px;
  border-bottom: 1px solid var(--border);
}

.options__tab {
  appearance: none;
  margin-bottom: -1px;
  padding: 10px 16px;
  border: none;
  border-bottom: 2px solid transparent;
  border-radius: 0;
  background: transparent;
  color: var(--text-muted);
  font: inherit;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: color 0.12s ease, border-color 0.12s ease;
}

.options__tab:hover {
  background: transparent;
  color: var(--text);
  border-color: transparent;
}

.options__tab[aria-selected="true"] {
  color: var(--accent);
  border-bottom-color: var(--accent);
}

.options__tab:focus-visible {
  outline: none;
  border-radius: var(--radius-sm);
  box-shadow: 0 0 0 3px var(--accent-soft);
}

.options__panel[hidden] {
  display: none;
}
```

> `.options__tab` 은 `button` 전역 스타일(채운 accent)을 클래스 특이도로 덮어쓴다. `:hover` 도 명시적으로 재지정해 전역 `button:hover` 의 accent 배경을 막는다.

- [ ] **Step 2b: 첫 카드 상단 여백 정리** — 패널 안 첫 `.options__create-card` 가 `margin-top:16px` 라 탭바와 붙으면 어색하므로, 파일 내 `.options__create-card,` 로 시작하는 규칙은 그대로 두고 아래를 추가:

```css
.options__panel > .options__create-card:first-child,
.options__panel > .options__list-wrap:first-child,
.options__panel > .options__status-card:first-child {
  margin-top: 20px;
}
```

- [ ] **Step 3: 빌드**

Run: `npm run pipe:build`
Expected: PASS, `dist/options.css` 갱신.

- [ ] **Step 4: 커밋**

```bash
git add vibecode-chrome-extension-infocutter/public/options.css
git commit -m "style(infocutter): add tab bar and panel styles"
```

---

### Task 5: chrome-devtools MCP 실렌더링 검증

**Files:** 없음 (검증 전용). REQUIRED SKILL: `vibecode-chrome-devtools-mcp-testing`.

- [ ] **Step 1: dist 를 HTTP 로 서빙**

```bash
cd vibecode-chrome-extension-infocutter/dist && (python3 -m http.server 8765 > /tmp/infocutter-server.log 2>&1 &)
```
확인: `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8765/options.html` → `200`.

- [ ] **Step 2: 탭 5개 + 패널 전환 확인**

- `mcp__chrome-devtools__new_page` → `http://localhost:8765/options.html`
- `mcp__chrome-devtools__take_snapshot` 으로 탭 버튼 uid 획득
- 각 탭 클릭 후 `take_screenshot` (`.bs-debug/options-tab-<key>.png`) — 해당 패널만 보이는지 확인
- `mcp__chrome-devtools__list_console_messages` — `Missing required options element` (elements.ts throw) 없는지 확인. `Cannot read properties of undefined (reading 'query')` 류의 chrome.tabs 미정의 에러는 정적 서빙 한계로 무시(실확장에선 정상).

Expected: 비활성 패널은 렌더되지 않고, elements.ts throw 없음.

- [ ] **Step 3: 마지막 탭 기억 확인** — `chrome.storage` 는 정적 서빙에서 미동작하므로, `mcp__chrome-devtools__evaluate_script` 로 `applyActiveTab` 경로 대신 클릭→리로드 대신 다음으로 확인:

`evaluate_script`: `() => { const t = document.querySelector('[data-tab="network"]'); t.click(); return document.getElementById('panel-network').hidden; }`
Expected: `false` (네트워크 패널 노출). 클릭 시 다른 패널 `hidden===true` 도 확인.

> 영속(reload 후 복원)은 실확장에서만 검증 가능 — Task 6 의 실확장 로드 또는 수동 확인 항목으로 남긴다.

- [ ] **Step 4: 다크 모드 확인**

- `mcp__chrome-devtools__emulate` `colorScheme: dark` → reload → `take_screenshot` (`.bs-debug/options-tab-dark.png`)
Expected: 탭바/활성 탭 accent 가 다크 토큰으로 렌더.

- [ ] **Step 5: 서버 정리**

```bash
pkill -f "http.server 8765"
```

---

### Task 6: 게이트 + MR

**Files:** 없음 (검증/배포).

- [ ] **Step 1: 전체 게이트**

Run: `npm run pipe:check`
Expected: PASS — lint + typecheck + node:test 전부 통과.

- [ ] **Step 2: 미커밋 잔여 확인**

Run: `git status --short`
Expected: 내 변경(tabs.ts, selector.test.ts, options.html, options.css, 플랜/스펙 문서) 외 무관 파일은 스테이징하지 않음.

- [ ] **Step 3: 푸시 + MR 생성**

```bash
git push -u origin feat/infocutter-options-tabs-20260530 \
  -o merge_request.create \
  -o merge_request.target=feat/infocutter-modern-minimal-ui-20260530 \
  -o merge_request.title="feat(infocutter): options page tab navigation" \
  -o merge_request.remove_source_branch
```

> target 을 MR #45 브랜치로 둔다(이 작업이 그 위에 쌓였으므로). #45 가 main 에 머지된 뒤라면 target 을 `main` 으로 조정.

- [ ] **Step 4: 워크스페이스 복원** — 병렬 세션을 위해 시작 시점 브랜치로 되돌린다.

```bash
git checkout refactor/infocutter-split-bloated-files-20260530
```

---

## Self-Review

**Spec coverage:**
- 5탭 구성 → Task 3 (패널 5개) ✓
- index.ts 무접촉 → tabs.ts 독립 로드, 어떤 Task 도 index.ts 수정 안 함 ✓
- elements.ts 계약 유지 → 모든 id 보존(Task 3 주석), Task 5 console 확인 ✓
- 마지막 탭 기억 → Task 2 read/writeStoredTab + Task 5 Step 3 노트(영속은 실확장) ✓
- 접근성(role, ←/→) → Task 2 keydown, Task 3 role/aria 속성 ✓
- 모던 톤 계승 → Task 4 토큰 재사용, base = MR #45 ✓
- 전역 컨트롤 고정 헤더 → Task 3 header > toolbar ✓
- 테스트/검증 → Task 1 단위 테스트, Task 5 MCP, Task 6 pipe:check ✓
- 0충돌(options.html/tabs.ts/css 만) → File Structure 한정 ✓

**Placeholder scan:** 모든 코드 스텝에 완전한 코드 포함. "적절히 처리" 류 없음. ✓

**Type consistency:** `resolveActiveTab(stored, validKeys)` 시그니처가 Task1/Task2 동일. `applyActiveTab(key, tabs, panels)`, `data-tab`/`data-panel` 키(`selector|text|network|template|settings`)가 HTML(Task3)·JS(Task2) 일치. `ACTIVE_TAB_STORAGE_KEY` 동일. ✓
