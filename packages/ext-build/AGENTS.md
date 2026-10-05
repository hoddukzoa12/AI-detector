# packages/ext-build: MV3 확장 빌드 파이프라인

## 공모전 전환에서의 위치

이 모듈에는 이전 Infocutter의 구현이 남아 있다. 공모전용 자동 점검 기능이 이 모듈에 이미 구현되었다고 간주하지 않는다. 재사용 범위는 필요한 기존 구현에 한정하며 소비자용 마스킹·모바일 배포는 새 제품의 개발 목표에 포함하지 않는다. 기존 코드 변경은 필요한 재사용 범위에 한정하고, 점검 원문을 읽기 전에 마스킹·네트워크 차단·페이지 변경을 적용하지 않는다.


## 범위

`@vibecode/ext-build` 패키지다. MV3 확장의 `build`, `doctor`, `dev`, `watch`, `package` 단계를 매개변수로 제공한다. 이 저장소의 소비자는 `extensions/chrome` 하나이고, `file:` 의존성으로 연결되어 확장의 `scripts/*.mjs`가 불러 쓴다.

이 디렉터리가 맡지 않는 것: 특정 확장의 content script 목록, 추가 자산 복사, manifest 개별 필드. 이런 확장별 동작은 소비자가 `contentScripts`, `afterCopy`, `transformManifest`, `extraChecks` 훅으로 넘긴다.

## 불변 조건

- 모든 경로는 `process.cwd()`를 확장 루트로 보고 계산한다(`lib.mjs`의 `projectRoot`). 소비자의 npm 스크립트 안에서 실행되어야 하며, 다른 디렉터리에서 직접 부르면 엉뚱한 `dist/`를 만든다.
- Node 표준 라이브러리만 쓴다. npm 의존성을 추가하지 않는다. 소비자는 `file:` 링크로 이 디렉터리를 그대로 쓰고 여기서 `npm install`을 하지 않는다.
- 외부 명령은 `run()`으로 `shell: false`에서 실행한다. 명령 문자열을 셸로 넘기지 않는다.
- 로그 머리말은 소비자 `package.json`의 `name`에서 만든다. 확장 이름을 코드에 적지 않는다.
- 기본값(service worker, popup, 아이콘 경로)을 바꾸면 모든 소비자의 빌드 결과가 바뀐다. 기본값 변경 대신 새 선택 인자를 추가한다.
- `package`는 `dist/`를 `dist-package/<name>-v<version>.zip`으로 묶는다. `zip` 명령이 있어야 한다.

## 테스트

- 자동 테스트는 없다. 이 패키지를 바꾸면 `extensions/chrome`에서 `npm install`(링크 갱신), `npm run pipe:rebuild`, `npm run pipe:check`, `npm run pipe:package`를 돌리고, `dist/manifest.json`의 `content_scripts[0].js`와 `options_page`가 바꾸기 전과 같은지 비교한다.
