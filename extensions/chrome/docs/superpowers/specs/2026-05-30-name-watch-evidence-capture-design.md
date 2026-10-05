# 이름 감시 · 증거 수집 (Name Watch & Evidence Capture) — 설계

- 작성일: 2026-05-30
- 대상 확장: `vibecode-chrome-extension-infocutter`
- 상태: 설계 승인 대기

## 1. 목적

피해자가 특정 인물(이름 + 별칭)을 등록해 두면, **그 이름이 포함된 내용이 어떤 웹페이지에 나타날 때**:

1. 피해자 화면에서는 그 내용을 **안 보이게(숨김)** 하고,
2. 사용자가 동의(확인)하면 **그 시점의 페이지를 증거로 캡처해 PDF로 저장**한다.

쌓인 PDF/증거 묶음은 **명예훼손·모욕 등 형사 고소/민사 소송의 소명자료**로 활용한다. 즉 본질은 "숨김"이 아니라 **증거 보존(Evidence Preservation)** 이다.

기존 텍스트 블록 숨김(`text-block-runtime`)과는 목적이 다르다. text-block은 반복 콘텐츠(광고/댓글 목록)를 fingerprint + `minMatchCount`로 숨기는 기능이고, 본 기능은 단일 등장도 잡아 **증거화**한다.

## 2. 핵심 사용자 흐름

```
[content] 페이지 텍스트 스캔 → 감시 이름/별칭(부분일치) 발견
   └─ 발견 즉시 마스킹(블러) + 마커 칩  "🚩 감시 대상 발견  [증거 저장] [무시]"
       (피해자는 내용을 읽지 않아도 됨)
   └─ 사용자 [증거 저장] 클릭
        → 요소를 잠깐 보이게 + 스크롤로 노출 + 강조 테두리
        → background 로 captureEvidence 메시지 전송
[background] chrome.scripting 로 측정/스크롤 스크립트 주입
        → chrome.tabs.captureVisibleTab 으로 뷰포트 타일 반복 캡처(풀페이지)
          (MAX_CAPTURE_VISIBLE_TAB_CALLS_PER_SECOND quota 감지 + 딜레이 직렬 큐)
[offscreen] OffscreenCanvas 에 타일 스티칭 → 풀페이지 PNG
        → 헤더 밴드 스탬프(URL·제목·시각·이름·해시) 합성
        → SHA-256 해시 계산(PNG, HTML)
        → jsPDF 로 [스크린샷 페이지 + 메타데이터 페이지] PDF 조립
[background] chrome.downloads 로 저장: infocutter-evidence/<이름>/<ISO시각>.pdf
        + raw PNG / raw HTML / manifest.json(해시 포함) 동봉 저장
        + IndexedDB(append-only)에 증거 메타데이터 기록
        → content 에 완료 응답
[content] 해당 요소 완전 숨김(display:none) + "저장됨" 표시
```

캡처는 **OK 시점에(아직 보이는 상태에서) 먼저** 수행하고 **그 다음 숨기므로**, "숨기면 못 찍는다"는 충돌이 없다.

## 3. 확정된 요구사항 (브레인스토밍 Q&A 결과)

| 항목 | 결정 |
|---|---|
| 목적 | 단순 숨김이 아니라 **증거 수집/로깅(고소 자료용)** |
| 증거 1건 구성 | 스크린샷 + 요소 HTML 원본 + URL/시각/텍스트 |
| 트리거 | **확인(OK) → 캡처 → PDF 저장 → 숨김.** 자동 마스킹 후 사용자 동의 시 저장 |
| 적용 범위 | **모든 사이트(전역)** |
| 이름 매칭 | **부분일치(포함) + 별칭 여러 개** |
| 캡처 범위 | **풀페이지(스크롤-스티칭)** — 게시글 전체 포함이 증거력에 유리 |
| PDF 생성 | **jsPDF**(MIT) 번들, `addImage(PNG)` |
| 캡처 권한 | captureVisibleTab + `chrome.scripting`(background), `downloads`는 optional 권한 |
| 무결성 | **SHA-256 해시 + 원본 아티팩트 보존 + 메타 스탬프** 를 v1 필수로 격상 |

## 4. 아키텍처 (4-레이어 + offscreen)

기존 인포커터 규약(`vibecode-chrome-mv3-architecture`)을 따른다.

### 4.1 새 도메인 패키지 — `packages/infocutter-watch`

`infocutter-text-blocks`와 동일 패턴(순수 도메인 로직, normalize/migrate, `globalThis` IIFE 주입). content/background/options가 공유한다.

타입(예시):

```ts
export type WatchTarget = {
  id: string;
  name: string;
  aliases: string[];
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
};

export type WatchSettings = {
  globalEnabled: boolean;
  autoMask: boolean; // 발견 시 자동 블러 여부 (기본 true)
};

export type WatchStore = {
  version: 1;
  settings: WatchSettings;
  targets: WatchTarget[];
};

export type EvidenceRecord = {
  id: string;            // UUID
  sequence: number;      // 단조 증가 캡처 순번
  targetId: string;
  matchedTerm: string;   // 실제 적중한 이름/별칭
  url: string;
  pageTitle: string;
  matchedText: string;   // 매칭된 텍스트(정규화 전 원문 일부)
  htmlExcerpt: string;   // 요소 outerHTML
  capturedAt: string;    // ISO 8601 + 타임존
  pngSha256: string;
  htmlSha256: string;
  pdfFilename: string;
  downloadId: number | null;
};
```

헬퍼: `normalizeWatchStore`, `emptyWatchStore`, `createWatchTarget`, `watchTerms(store)`(이름+별칭을 소문자·공백정리한 텀 배열), `matchTerms(text, terms)`.

### 4.2 저장소

- **`infocutter.watchStore`** (chrome.storage.local, **v1**) — 감시 이름 + 설정. 용량 작음. `shared/constants.ts`에 `WATCH_STORAGE_KEY`, `WATCH_STORAGE_VERSION` 추가. 기존 normalize/migration 패턴(`vibecode-chrome-storage-schema`) 준수.
- **증거 메타데이터** — **IndexedDB** (`infocutter-evidence` DB, `records` object store). append-only(레코드 불변). 목록 UI 렌더용. (chrome.storage 쿼터 회피)
- **증거 파일(PDF/PNG/HTML/manifest)** — `chrome.downloads`로 디스크 저장. `unlimitedStorage` 권한 추가(원본 PNG를 IndexedDB에 백업 보관할 경우 대비).

### 4.3 content 런타임 — `src/content/watch-runtime.ts`

- `watchStore` 읽어 정규화된 텀 목록 구성.
- `TreeWalker`(SHOW_TEXT)로 텍스트 노드 스캔. text-block-runtime의 `preferredTextBlockContainer` / `isIgnoredTextHost` 로직을 **공용 헬퍼로 추출(`src/content/dom-block.ts` 등)** 해 재사용한다. (기존 코드 개선 — 두 런타임이 같은 컨테이너 추론을 공유)
- 매칭: `includes()` 부분일치, 이름+별칭 중 하나라도 적중. **텀 길이 ≥ 2** 가드(과도한 오탐 방지).
- **fingerprint / minMatchCount 없음** — 단일 등장도 매칭(텍스트 블록과의 핵심 차이).
- 발견 즉시 마스킹: 블러 오버레이 + 마커 칩(`[증거 저장]` / `[무시]`). `settings.autoMask`로 on/off.
- 페이지 내 `Set<contentHash>`로 같은 내용 칩 중복 표시 방지.
- 저장 시 `(정규화 URL + contentHash)`로 IndexedDB 중복 체크 → 재방문해도 중복 저장 안 함.
- `MutationObserver` 디바운스 재스캔(text-block-runtime와 동일 패턴).
- `settings.globalEnabled` 게이트.
- 마커 칩 / 마스킹 UI는 Shadow DOM 또는 전용 attribute + injected style로 페이지와 격리(picker-ui 패턴 참고).

### 4.4 background — `src/background/service-worker.ts`

- 새 메시지 핸들러 `captureEvidence`:
  1. 측정/스크롤 스크립트를 `chrome.scripting.executeScript`로 대상 탭에 주입 → `scrollHeight`/`innerHeight`/`devicePixelRatio`로 타일 분할 계산.
  2. 뷰포트를 스크롤하며 `chrome.tabs.captureVisibleTab` 반복. **`MAX_CAPTURE_VISIBLE_TAB_CALLS_PER_SECOND` quota 에러 감지** 후 딜레이/재시도. 모든 캡처는 **직렬 큐**(기존 `networkRuleApplyQueue` 패턴 재사용)로 처리.
  3. 타일 + 메타데이터를 **offscreen document**로 전달.
  4. offscreen 결과(PDF/PNG/HTML/manifest blob + 해시)를 받아 `chrome.downloads.download`로 저장, IndexedDB에 레코드 append.
- `downloads`는 optional 권한이므로 첫 저장 시 `chrome.permissions.request`로 요청.

### 4.5 offscreen document — `src/offscreen/index.ts` + `public/offscreen.html`

MV3 `offscreen` API 사용(이유: `DOM_PARSING`/`BLOBS` — canvas 스티칭과 jsPDF는 DOM/canvas가 필요, service worker엔 없음). GoFullPage의 `capture.html` 역할.

- `OffscreenCanvas`(또는 일반 canvas)에 타일 스티칭 → 풀페이지 PNG.
- 상단 **헤더 밴드 스탬프** 합성: 전체 URL · 페이지 제목 · 캡처 시각(타임존) · 감시 이름 · (가능 시) 작성자 추정 ID.
- `crypto.subtle.digest('SHA-256', ...)`로 PNG·HTML 해시 계산.
- **jsPDF**로 PDF 조립: 1p 스크린샷, 2p 메타데이터(해시 포함) + 푸터 면책 문구.
- `MAX_PIXELS` 캔버스 한계 캡(초대형 페이지 방어, GoFullPage 채택 기법).

## 5. 증거 무결성 사양 (법적 효력의 핵심)

조사 결론(§14): 스크린샷은 증거로 제출 가능하나 **단순 캡처는 증명력이 약함**. 강한 증거는 **동일성·무결성**과 **원본성·연속성(Chain of Custody)** 이 필요하며 기술적 수단은 **해시값**, 실무는 **게시글 전체 + URL + 작성일시 기록**을 요구.

v1에 반영:

1. **풀페이지 캡처** — 게시글/댓글 전체 포함.
2. **메타 스탬프** — captureVisibleTab은 브라우저 주소창을 못 담으므로, 결과물에 URL·제목·캡처시각(TZ)·이름을 직접 박아 넣음.
3. **SHA-256 해시** — 풀페이지 PNG와 요소 HTML 각각 해시. PDF 메타페이지 + `manifest.json` + IndexedDB 레코드에 동시 기록.
4. **원본 아티팩트 보존** — 가공 PDF뿐 아니라 **raw PNG + raw HTML + manifest.json(해시·시각·URL)** 도 함께 저장. PDF는 사람이 읽는 패키지, raw + 해시는 무결성 근거.
5. **append-only 로그** — IndexedDB 레코드는 수정/삭제 시 별도 처리(삭제는 사용자 명시 동작으로만, 캡처 순번 단조 증가).

### 면책 (과대광고 금지)

확장은 공증·디지털 포렌식·증거보전 신청을 대신하지 못한다. PDF 푸터 및 옵션 UI에 다음을 명시:

> 본 자료는 소명 참고자료입니다. 다툼이 있는 사건에서는 공증·증거보전 신청·디지털 포렌식 등 추가 절차가 필요할 수 있습니다.

## 6. UI

### 6.1 popup
- "이름 감시" 전역 토글
- 등록 이름 수 / 이 페이지에서 발견 N건 · 저장 M건
- "옵션에서 관리" 링크

### 6.2 options — 새 탭 "이름 감시"
- **이름 관리**: 이름 + 별칭(칩) 추가, on/off, 삭제
- **설정**: 전역 on/off, 자동 마스킹 on/off
- **증거 목록**: 이름·URL·시각·텍스트 일부 + [PDF 열기] / [삭제], 전체 내보내기(ZIP)

## 7. manifest / 메시지 / 빌드

- **manifest**:
  - `permissions`에 (필요 시) `offscreen` 추가, `unlimitedStorage` 추가.
  - `downloads`는 `optional_permissions`로 둠(첫 저장 시 요청).
  - `content_scripts.js` 순서에 `watch-package.js`(도메인 IIFE) + `watch-runtime.js` 추가.
  - `web_accessible_resources` / offscreen 문서 등록.
- **background `contentScriptFiles` 배열**도 동일 순서로 동기화(주입 무결성).
- **`shared/messages.ts` + `content/constants.ts`**에 메시지 타입 추가: `getWatchState`, `captureEvidence`, `toggleWatchGlobalEnabled`, `toggleWatchAutoMask`, `addWatchTarget`, `removeWatchTarget` 등.
- **빌드**: `tsconfig.packages.json`에 `infocutter-watch` 포함 → `sync-packages-dist.mjs`가 `packages-dist` 동기화. `build.mjs`가 offscreen 엔트리/`public` 합성 처리하도록 확인. jsPDF는 vendored 번들로 포함(번들 무결성은 `pipe:doctor`로 점검).

## 8. 에러 처리 / 한계

- 캡처 실패(quota/권한/비활성 탭) 시: 마스킹 유지 + 에러 칩 + 재시도 버튼. 부분 캡처는 폐기(증거 신뢰성).
- **iframe 내부 매칭**: captureVisibleTab은 top 뷰포트만 → v1은 top-frame 저장에 집중. iframe은 마스킹은 되나 캡처 정확도 제한 → 한계로 문서화.
- **부분일치 오탐**: 짧은 이름(예 3글자)이 동명이인/부분문자열에 적중 가능(사용자가 "포함" 선택). 별칭으로 보완 권장, v1은 부분일치 유지.
- **동적 콘텐츠**: 실무는 화면 녹화를 권하나 v1은 정지 풀페이지 캡처. 한계로 문서화.
- `downloads` optional 권한 거부 시: IndexedDB에 메타+raw는 보관하되 파일 저장은 불가 → 안내.

## 9. 테스트

- **단위(`node:test`)**: `infocutter-watch` normalize/migrate, `watchTerms`/`matchTerms` 매칭, 텀 길이 가드. (`pipe:test` 패턴)
- **수동(chrome-devtools MCP, `vibecode-chrome-devtools-mcp-testing`)**: 마스킹 칩 표시 → [증거 저장] → 풀페이지 캡처 → PDF 다운로드 + 해시 기록 검증.
- **게이트**: `pipe:check`(eslint/typecheck/test) + `pipe:doctor` 통과. no-comments-gate 준수.

## 10. 범위 (YAGNI)

- **v1 포함**: 부분일치+별칭, 전역, 자동 마스킹, 확인→풀페이지 캡처→jsPDF→다운로드, SHA-256 무결성, 원본 아티팩트 보존, 메타 스탬프, 증거 목록 옵션 탭.
- **후순위(제외)**: 자동 캡처(확인 없이), 사이트별 범위 한정, 화면 녹화(동영상), OCR, 클라우드 업로드, 외부 타임스탬프 서버(TSA)/공증 연동, 작성자 ID 자동 파싱(사이트별).

## 11. 구현 순서(요약, 상세 plan은 별도)

1. `packages/infocutter-watch` 도메인 + 단위테스트
2. `shared/constants.ts` 키/버전 + storage normalize/migrate
3. content `watch-runtime.ts` + 공용 `dom-block` 헬퍼 추출 + 마스킹/칩 UI
4. offscreen(스티칭 + 스탬프 + 해시 + jsPDF)
5. background `captureEvidence` 큐 + downloads + IndexedDB
6. popup / options UI
7. manifest/메시지/빌드 배선 + doctor
8. MCP 수동 검증 + 게이트

## 12. 미해결/추후 확인

- jsPDF 번들 방식(vendored vs npm dep) — 빌드 파이프라인과 맞춰 결정.
- offscreen vs service-worker `OffscreenCanvas` 직접 처리 — jsPDF 호환성 검증 후 확정(현재 offscreen 권장).
- 증거 목록 "전체 내보내기" 포맷(ZIP) — SEO-check ZIP export 재사용 가능성 확인.

## 13. 참고 구현 — GoFullPage 분석 요약

설치본(`fdpohaocaechififmbbbbbknoalclacl` v8.6) 분석:
- 풀페이지 = `chrome.scripting`로 측정/스크롤 주입 + `captureVisibleTab` 타일 반복 + canvas 스티칭.
- `MAX_CAPTURE_VISIBLE_TAB_CALLS_PER_SECOND` quota 에러를 명시적으로 감지/재시도(`isCaptureVisibleTabQuotaError`).
- PDF는 **jsPDF** `addImage(PNG)`.
- 캡처/스티칭은 확장 페이지(`capture.html`)에서 수행(→ 우리는 offscreen).
- 권한: `activeTab`/`scripting`/`storage`/`unlimitedStorage` 필수, `downloads`/`webNavigation` optional.
- 코드는 베끼지 않음. 스크롤-스티칭은 공지 기법, jsPDF는 MIT → 직접 구현/번들.

## 14. 법적 효력 조사 요약 (한국, 명예훼손·모욕)

- 스크린샷은 형사·민사에서 **증거로 제출·인정 가능**. 단 **단순 캡처는 조작 가능성 때문에 증명력이 약함**.
- 디지털 증거의 증거능력 요건: **동일성·무결성**(대법원 2018.2.8. 2017도13263), 기술적 수단은 **해시값**, **원본성+연속성(Chain of Custody)**.
- 실무 권고: **게시글 전체+댓글, 작성 시각이 보이게** 캡처 + **URL·작성일시·작성자 ID 기록**. 동적 요소는 화면 녹화. 강한 효력엔 **공증·내용증명·증거보전 신청·디지털 포렌식**.
- → 본 설계는 풀페이지 + 해시 + 원본 보존 + 메타 스탬프로 증명력을 보강하되, 공증/포렌식은 외부 절차임을 면책 고지.

### 출처
- 문자 캡처 증거 제출: https://www.hellawlog.kr/entry/문자-캡처-법원에-증거로-제출해도-될까요
- 휴대폰 메시지 촬영물 증거능력: https://www.a-ha.io/questions/452741d29f1df2c89548eb876e180351
- 디지털 증거 무결성·동일성(2017도13263 평석, KCI): https://www.kci.go.kr/kciportal/landing/article.kci?arti_id=ART002343517
- 대법원 2017도13263 판결: https://casenote.kr/대법원/2017도13263
- SNS 명예훼손 형사고소 절차·증거수집: https://gounlaw.com/legal-information/legal-information/56
- 사이버명예훼손 증거 수집 방법: https://www.daeryunlaw-detective.com/lawInfo_new/8779
- 디지털 증거 증거능력 연구(사법정책연구원): https://jpri.scourt.go.kr/fileDownLoad.do?seq=1858
