# apps/browser/mcp: 인포커터 자동화 MCP 서버

## 공모전 전환에서의 위치

이 모듈에는 이전 Infocutter의 구현이 남아 있다. 공모전용 자동 점검 기능이 이 모듈에 이미 구현되었다고 간주하지 않는다. 재사용 범위는 필요한 기존 구현에 한정하며 소비자용 마스킹·모바일 배포는 새 제품의 개발 목표에 포함하지 않는다. 기존 코드 변경은 필요한 재사용 범위에 한정하고, 점검 원문을 읽기 전에 마스킹·네트워크 차단·페이지 변경을 적용하지 않는다.


## 범위

stdio JSON-RPC로 동작하는 MCP 서버 `infocutter-automation`이다. MCP 도구 호출을 Flutter 앱 디버그 빌드의 자동화 브리지 호출로 옮기고, 앱 상태 스냅샷을 리소스로 노출한다. 파일은 `index.mjs`(서버)와 `smoke.mjs`(끝에서 끝까지 확인) 둘이다.

이 디렉터리가 맡지 않는 것: 브리지 동작 자체(앱의 `lib/services/app_automation_*`), 접근 제어(앱이 한다), 앱 실행.

## 불변 조건

- 브리지 주소와 자격 증명은 환경 변수에서만 읽는다. 값을 코드나 README 예시에 적지 않는다.
- 이 서버는 권한 검사를 하지 않는다. 접근 제어는 앱 브리지가 한다. 서버 쪽에서 앱의 접근 제어를 우회하는 경로를 만들지 않는다. 현재 `page.getText`, `page.click`, `page.fill`은 민감 동작 목록에 없어 토큰 없이 현재 페이지를 읽거나 조작할 수 있는 코드 경로가 있다. 실제 기기 재현은 하지 않았다.
- 도구 이름(`snapshot`, `new_tab`, `navigate`, `wait_for_load`, `wait_for_selector`, `click`, `fill`, `get_text`, `eval_js`, `screenshot`, `infocutter_pick`, `infocutter_open_panel`, `infocutter_add_block_rule`, `infocutter_list_profiles`, `run`)은 사용자 MCP 설정과 프롬프트가 기대는 계약이다. 이름을 바꾸지 말고 새로 추가한다.
- 각 도구는 `toAction`에서 브리지 동작 이름(`page.load`, `infocutter.pick` 등)으로 바뀐다. 앱의 동작 이름이 바뀌면 이 표를 같은 변경에서 고친다.

## 구현 방식

- 의존성은 `@modelcontextprotocol/sdk` 하나이고 Node 18 이상의 전역 `fetch`를 쓴다.
- `package-lock.json`과 `node_modules/`는 gitignore 대상이라 설치마다 SDK 버전이 `^1.0.0` 범위에서 달라질 수 있다.

## 테스트

- 자동 테스트는 없다. 앱을 `flutter run -d <기기> --debug`로 띄운 뒤 이 디렉터리에서 `npm install`, `node smoke.mjs`를 돌려 `SMOKE PASS`가 나오는지 확인한다.
