# extensions/chrome/packages: 확장 도메인 패키지

## 공모전 전환에서의 위치

이 모듈에는 이전 Infocutter의 구현이 남아 있다. 공모전용 자동 점검 기능이 이 모듈에 이미 구현되었다고 간주하지 않는다. 재사용 범위는 필요한 기존 구현에 한정하며 소비자용 마스킹·모바일 배포는 새 제품의 개발 목표에 포함하지 않는다. 기존 코드 변경은 필요한 재사용 범위에 한정하고, 점검 원문을 읽기 전에 마스킹·네트워크 차단·페이지 변경을 적용하지 않는다.


## 범위

네 패키지가 있다.

| 패키지 | 맡는 것 | content script 전역 이름 |
|---|---|---|
| `infocutter-selector-rules` | 선택자 규칙 저장소 모델·정규화(version 1~4), URL matcher, 프로필 선택, 카드 묶기, 선택자 후보 생성 보조, 메시지 타입 이름 | `InfocutterSelectorRules` |
| `infocutter-text-blocks` | 텍스트 블록 저장소 모델·정규화, 오브젝트 태그, 활성 상태 계산 | `InfocutterTextBlocks` |
| `infocutter-watch` | 감시 대상 저장소 모델, 검색어 목록, 부분 문자열 매칭 | `InfocutterWatch` |
| `infocutter-filter-importer` | AdBlock·uBlock 필터 줄 해석, declarativeNetRequest 규칙 변환 | 없음(options와 service worker만 import) |

이 디렉터리가 맡지 않는 것: `chrome.storage` 읽기·쓰기, 메시지 송수신, 화면. 그것은 확장의 `src/`에 있다. Flutter 앱의 Dart 모델도 여기서 만들지 않는다.

## 불변 조건

- 각 패키지는 `src/index.ts` 한 파일이고, 다른 모듈을 import하지 않는다. 빌드(`scripts/build.mjs`의 `buildContentGlobalPackage`)가 컴파일된 `dist/index.js`에서 줄 머리의 `export `를 지우고 IIFE로 감싸 전역에 붙이므로, import 문이 있으면 content script에서 문법 오류가 난다.
- `chrome.*` API를 부르지 않는다. DOM이 필요한 함수(`isUniqueSelector`, `buildForcedUniqueSelector` 등)는 `document`를 기본값으로 받는 인자를 두어 테스트에서 바꿔 넣을 수 있게 한다.
- 새 export를 content script에서 쓰려면 `scripts/build.mjs`의 해당 export 목록에 이름을 추가한다. 목록에 없는 이름은 IIFE가 돌려주지 않는다.
- 정규화 함수는 어떤 입력에도 throw하지 않고 기본값이 채워진 객체를 돌려준다. 잘못된 항목은 버린다.
- `normalizeRuleStore`는 version 4와 3의 `profiles`, version 1과 2의 `sites`를 읽는다. 그 밖의 버전은 빈 저장소를 돌려준다. `normalizeWatchStore`는 version이 있고 1이 아니면 빈 저장소를 돌려준다. 버전을 올릴 때는 이전 버전 분기를 지우지 않는다.
- `infocutterMessageTypes`의 문자열 값(`infocutter/...`)은 바꾸지 않는다. content script, service worker, popup이 이 값으로 통신한다.
- 네트워크 규칙 변환은 지원하지 않는 수정자를 만나면 규칙을 만들지 않고 `reason`을 돌려준다. 추측으로 비슷한 규칙을 만들지 않는다.

## 구현 방식

- 빌드 순서: `tsc -p tsconfig.packages.json`이 `packages-dist/<패키지>/src`로 컴파일하고, `scripts/sync-packages-dist.mjs`가 그것을 `packages/<패키지>/dist`로 복사한다. `packages/*/dist`는 생성물이며 gitignore 대상이다.
- 확장의 `src/`는 이 패키지를 `../../packages/<패키지>/src/index.js` 상대 경로로 import한다. 패키지 이름(`@infocutter/selector-rules` 등)으로 import하지 않는다.

## 테스트

- 테스트는 확장의 `tests/*.test.ts`에 있고 `npm run pipe:test`로 돈다.
- 반드시 테스트할 것: 버전별 저장소 입력(1, 2, 3, 4, 알 수 없는 값, 객체 아님), 문자열 규칙과 카드 없는 규칙의 보정, `matchesUrl`의 scheme `*`·port 생략·서브도메인 불일치·`*://*/*`, 감시 검색어의 두 글자 미만 제외와 대소문자 무시와 연속 공백 정규화(`홍 길동`과 `홍길동`은 일치하지 않음), 필터 줄 종류별 해석(`##`, `#@#`, `:has-text`, `#%#`, `@@`, 지원 안 하는 수정자).
