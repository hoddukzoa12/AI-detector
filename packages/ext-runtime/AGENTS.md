# packages/ext-runtime: MV3 런타임 스캐폴드 원본

## 공모전 전환에서의 위치

이 모듈에는 이전 Infocutter의 구현이 남아 있다. 공모전용 자동 점검 기능이 이 모듈에 이미 구현되었다고 간주하지 않는다. 재사용 범위는 필요한 기존 구현에 한정하며 소비자용 마스킹·모바일 배포는 새 제품의 개발 목표에 포함하지 않는다. 기존 코드 변경은 필요한 재사용 범위에 한정하고, 점검 원문을 읽기 전에 마스킹·네트워크 차단·페이지 변경을 적용하지 않는다.


## 범위

`@vibecode/ext-runtime` 패키지다. MV3 확장용 i18n 함수 `t`, `chrome.storage` 설정 저장소 팩토리 `createSettingsStore`, 메시지 클라이언트 `sendRuntimeMessage`·`isExtensionContextValid`, 메시지 버스 `createMessageBus`의 원본 소스를 둔다.

이 저장소 안에는 이 패키지를 쓰는 코드가 없다. `extensions/chrome`도 import하지 않는다. `sync-consumers.mjs`가 복사하려는 소비자(`vibecode-chrome-extension-seo-check`, `vibecode-chrome-extension-youtube-evaluator`)는 이 저장소에 없다.

## 불변 조건

- 소비자는 번들러 없이 이 소스를 각자 `packages/ext-runtime/src`에 복사해 상대 경로로 import하는 방식을 전제로 한다. MV3 popup과 service worker가 bare specifier(`@vibecode/ext-runtime`)를 풀지 못하기 때문이다. 따라서 이 소스는 다른 패키지를 import하지 않는다.
- `sync-consumers.mjs`는 저장소 루트 바로 아래의 소비자 디렉터리를 가정한다. 이 저장소에서 실행하면 존재하지 않는 경로에 디렉터리를 만든다. 소비자가 생기기 전에는 실행하지 않는다.
- 메시지 응답 봉투는 `{ ok, data, error }` 모양이다. 이 모양을 바꾸면 복사본을 쓰는 모든 확장이 깨진다.

## 테스트

- 자동 테스트는 없다. 재사용 시 소비 경로와 검증 방법을 변경 범위에 포함하며, 소비자 없는 패키지를 고친 것을 제출 기능 구현으로 보고하지 않는다.
