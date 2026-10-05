# extensions/chrome: 인포커터 Chrome 확장 (Manifest V3)

## 공모전 전환에서의 위치

이 모듈에는 이전 Infocutter의 구현이 남아 있다. 공모전용 자동 점검 기능이 이 모듈에 이미 구현되었다고 간주하지 않는다. 재사용 범위는 필요한 기존 구현에 한정하며 소비자용 마스킹·모바일 배포는 새 제품의 개발 목표에 포함하지 않는다. 기존 코드 변경은 필요한 재사용 범위에 한정하고, 점검 원문을 읽기 전에 마스킹·네트워크 차단·페이지 변경을 적용하지 않는다.


## 범위

이 디렉터리가 맡는 것: Chrome(및 iOS Safari 변환본)에서 선택자 숨김, 선택 모드, 텍스트 블록, 감시와 증거 캡처, 필터 목록 가져오기와 declarativeNetRequest 적용, AI 마스킹, 템플릿 화면, 그리고 이 확장의 빌드 스크립트(`scripts/`), 템플릿 서버, 소개 페이지(`introduce/`).

이 디렉터리가 맡지 않는 것:

- 빌드 파이프라인 본체: 저장소 루트 `packages/ext-build`에 있다. `scripts/*.mjs`는 그것을 부르는 얇은 래퍼다. 공용 동작을 바꾸려면 그쪽을 고친다.
- 모바일 앱: `apps/browser`의 Dart 코드는 이 확장의 코드를 쓰지 않는다. 규칙 JSON 모양을 바꾸면 그쪽 `RuleStoreCodec`도 따로 고쳐야 한다.
- `introduce/`의 글과 페이지는 확장 빌드에 들어가지 않는다. 이 디렉터리의 skill 파일(`.claude/skills/`, `introduce/SKILL.md`)이 작성 규칙을 갖고 있다.

## 레이어

| 경로 | 맡는 것 | 하지 않는 것 |
|---|---|---|
| `src/background/service-worker.ts` | 탭 준비, 배지, 컨텍스트 메뉴, 단축키, 네트워크 규칙 적용, 증거 캡처 조율, AI 분석 호출 | DOM 조작, 선택자 생성 |
| `src/content/*.ts` | 규칙 렌더링, 선택 모드, 텍스트 블록·감시·AI 런타임, 프레임 문맥 | `import`·`export` 사용, 원격 요청 |
| `src/popup`, `src/options` | 사용자 조작 화면 | 도메인 판정 로직 새로 만들기 |
| `src/shared` | 저장소 읽기·쓰기, 타입, 상수, AI 클라이언트, IndexedDB 증거 기록 | 화면 코드 |
| `src/offscreen`, `src/evidence` | 증거 PNG·PDF 합성 | 파일 저장(다운로드는 service worker가 한다) |
| `packages/infocutter-*` | 선택자 규칙·텍스트 블록·감시 모델, 필터 목록 해석 | `chrome.*` 호출 |

`src/background`, `src/popup`, `src/options`, `src/content`는 서로 import하지 않는다. ESLint가 `../background/*`, `../popup/*`, `../content/*` import를 오류로 만든다.

## 불변 조건

- content script는 전역 스코프를 공유하는 일반 스크립트다. `src/content/*.ts`에 `import`·`export`가 생기면 컴파일 결과가 모듈이 되어 로드에 실패한다. 다른 content 파일의 함수는 `src/content/contracts.d.ts`에 선언하고 전역으로 부른다.
- content script 로드 순서는 IIFE 패키지 3개 → `constants.js` → 나머지 → `index.js`다. 목록은 `scripts/build.mjs`의 `contentScriptFiles`(실제 manifest)와 `src/background/service-worker.ts`의 `contentScriptFiles`(재주입) 두 곳에 있고, 둘은 같은 순서·같은 파일이어야 한다. `public/manifest.json`의 목록은 빌드가 덮어쓴다.
- 도메인 패키지의 새 export를 content script에서 쓰려면 `scripts/build.mjs`의 `selectorRulesPackageExports`·`textBlocksPackageExports`·`watchPackageExports` 가운데 맞는 목록에 이름을 넣는다. 빠지면 타입 검사는 통과하고 페이지에서만 `undefined`가 된다.
- 선택자 생성은 `src/shared/selector.ts`와 content 쪽 사본 `src/content/selector-engine.ts` 두 곳에만 있다. 선택 모드가 실제로 쓰는 것은 content 쪽이다. 한쪽을 고치면 다른 쪽도 같은 변경에서 맞춘다.
- `src/content/constants.ts`와 `src/shared/constants.ts`의 저장소 키·버전·속성 이름은 같은 값이어야 한다.
- 저장소 키(`infocutter.ruleStore`, `infocutter.textBlockStore`, `infocutter.networkRuleStore`, `infocutter.watchStore`, `infocutter.aiRuleStore`, `infocutter.aiConfig`)는 이름을 바꾸지 않는다. 모양을 바꾸면 `version`을 올리고 이전 버전을 읽는 분기와 테스트를 먼저 넣는다. 알 수 없는 버전은 빈 저장소로 읽힌다.
- 렌더링은 멱등이다. `renderRules` 등은 이전에 붙인 `data-infocutter-*-hidden` 속성을 먼저 지우고 다시 붙인다. 두 번 실행해도 결과가 같아야 한다.
- URL마다 선택자 규칙은 matcher가 맞는 첫 프로필 하나만 적용한다. 프로필 배열 순서가 우선순위다.
- declarativeNetRequest 동적 규칙은 id 1,000,000~1,199,999만 쓰고, 이 범위 밖의 동적 규칙은 지우지 않는다.
- `innerHTML`, `eval`, `new Function`, 원격 스크립트를 쓰지 않는다. jsPDF는 `vendor/jspdf.js`만 쓴다.
- `src/evidence/page-evidence-builder.ts`의 `buildEvidenceInPage`는 함수 밖의 어떤 심볼도 참조하지 않는다. Safari 경로에서 `executeScript`로 직렬화되기 때문이다.
- TypeScript·JavaScript 소스에 `//` 줄 주석을 쓰지 않는다.
- manifest 권한을 늘릴 때는 그 권한을 쓰는 코드와 같은 커밋에 넣고 커밋 본문에 이유를 적는다. `storage`, `tabs`, `contextMenus`, `scripting`, `declarativeNetRequest`는 `pipe:doctor`가 필수로 검사한다.

## 구현 방식

- 저장소 접근은 `src/shared/*-storage.ts`, `storage-*.ts`, `ai-config.ts`, `network-rules.ts`의 함수로 한다. content 쪽은 `src/content/site-storage.ts`가 같은 일을 전역 패키지 함수로 한다.
- 메시지 이름은 `infocutterMessageTypes`(선택자 규칙 패키지)에만 추가한다. 응답은 `{ ok, data?, error? }` 모양이다.
- 저장소가 바뀌면 각 탭의 content script가 `chrome.storage.onChanged`로 다시 그린다. 화면에서 저장한 뒤 따로 메시지를 보낼 필요가 없다.
- 네트워크 규칙은 저장소 변경 때마다 인포커터 범위의 동적 규칙을 모두 지우고 다시 넣는다. 적용은 큐로 직렬화되어 있다.
- 증거 캡처도 큐로 직렬화된다. 같은 URL과 같은 HTML 해시가 이미 있으면 파일을 만들지 않는다.

## 테스트

- 명령: `npm install` 뒤 `npm run pipe:check`(lint → typecheck → 빌드 → `node --test 'dist/tests/*.js'`)와 `npm run pipe:doctor`. `npm ci`는 lock 파일 경로 문제로 실패한다.
- 테스트는 `tests/*.test.ts`에 두고 `.js` 확장자로 import한다. 대상은 `src/shared`, `packages/*`, `src/evidence`, options 보조 함수다.
- 반드시 테스트할 것: 저장소 정규화(버전별 입력, 문자열 규칙, 카드 없는 규칙), matcher 비교(scheme `*`, port 생략, 서브도메인 불일치), 필터 줄 해석(지원 안 함 이유 포함), 네트워크 규칙 id 범위 초과, AI 응답 파싱(배열 밖 텍스트, 알 수 없는 카테고리, 신뢰도 범위 밖), PDF 빌더의 크기 초과 처리.
- `src/content/*`에는 자동 테스트가 없다. content script를 바꿨으면 `./infocutter build` 뒤 `chrome://extensions`에서 `dist`를 다시 읽고, 일반 페이지와 iframe이 있는 페이지, 확장 갱신 전에 열린 탭에서 선택 모드·숨김·peek을 직접 확인한다.
