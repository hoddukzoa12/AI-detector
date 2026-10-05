# apps/browser: 인포커터 Flutter 브라우저 앱

## 공모전 전환에서의 위치

이 모듈에는 이전 Infocutter의 구현이 남아 있다. 공모전용 자동 점검 기능이 이 모듈에 이미 구현되었다고 간주하지 않는다. 재사용 범위는 필요한 기존 구현에 한정하며 소비자용 마스킹·모바일 배포는 새 제품의 개발 목표에 포함하지 않는다. 기존 코드 변경은 필요한 재사용 범위에 한정하고, 점검 원문을 읽기 전에 마스킹·네트워크 차단·페이지 변경을 적용하지 않는다.


## 범위

`flutter_inappwebview` 기반 브라우저([pichillilorenzo/flutter_browser_app](https://github.com/pichillilorenzo/flutter_browser_app) fork, Apache-2.0)에 인포커터 기능을 얹은 Android·iOS·macOS·Windows 앱이다. 패키지 이름은 `infocutter_app`, 앱 id는 `com.dalsoop.infocutter`다.

이 디렉터리가 맡는 것: 브라우저 셸(탭, 주소창, 설정, 개발자 도구), 인포커터 기능(`lib/infocutter/`), WebView 주입 JS(`assets/js/`), 디버그 자동화 브리지(`lib/services/app_automation_*`), 생성 도구(`tool/`), 디자인 토큰 스냅샷(`design/`).

이 디렉터리가 맡지 않는 것:

- Chrome 확장 코드. 규칙 모델은 Dart로 따로 구현되어 있고 TypeScript를 불러 쓰지 않는다. 확장 쪽 파일을 고쳐 이 앱의 동작을 바꾸려 하지 않는다.
- MCP 서버(`mcp/`)의 도구 정의. 브리지 동작을 추가하면 MCP 쪽은 따로 맞춘다.

## 레이어

| 경로 | 맡는 것 | 하지 않는 것 |
|---|---|---|
| `lib/main.dart` | 부트스트랩, 플랫폼 초기화, Provider 연결 | 도메인 판정, WebView 이벤트 처리 |
| `lib/util.dart` | 여러 레이어가 함께 쓰는 범용 유틸 | 인포커터 도메인 로직(선택자, 규칙, 필터 판정 등) |
| `lib/browser.dart`, `lib/webview_tab*.dart` | 탭 렌더링과 WebView 생명주기, 요청 콜백 | 선택자 생성, 저장소 정책 |
| `lib/app_bar/`, `lib/pages/` | 화면과 메뉴 | 저장소 구현, 도메인 코덱 |
| `lib/models/` | 직렬화되는 브라우저·창·탭 상태 | `webview_tab.dart`, `lib/pages/`, `lib/app_bar/` import |
| `lib/services/` | 영속화, 플랫폼 연동, WebView 설정 팩토리, 자동화 브리지 | 인포커터 규칙 판정 |
| `lib/infocutter/` | 선택자·규칙 저장소·ContentBlocker·텍스트 블록·감시·증거·네트워크 필터·AI·인증 origin 판정 | 브라우저 셸 화면 |
| `lib/infocutter/ui/` | 인포커터 사이드바와 패널 위젯 | 저장소 직접 쓰기 |
| `lib/infocutter/application/` | 선택 결과 저장, 런타임 적용 유스케이스와 저장소 포트 | 위젯 |
| `lib/l10n/` | ARB 문자열과 생성된 `AppLocalizations` | 비즈니스 규칙 |

현재 `lib/models/browser_model.dart`와 `lib/infocutter/` 일부 파일(`auth_unsupported_banner.dart`, `infocutter_runtime_applier.dart` 등)은 Flutter 위젯 라이브러리를 import한다. 새 파일에서 이 범위를 넓히지 않는다.

## 불변 조건

- 기존 인증 주소 판정은 `lib/infocutter/auth_origin_policy.dart`의 `isAuthOrigin`이다. 설정·요청 콜백·후속 런타임에 예외가 있지만 초기 `initialUserScripts`는 주소 조건 없이 등록된다. 모든 스크립트 주입이 차단된다고 보장하지 않는다. 점검용 경로는 로그인 진입 금지와 초기 주입을 별도로 검증한다. `SiteProtectionBypass` 호스트도 같은 지점에서 같은 방식으로 건너뛴다.
- User-Agent를 위장하지 않는다.
- 규칙 JSON 인코딩·디코딩은 `lib/infocutter/rule_store_codec.dart`의 `RuleStoreCodec`만 한다. 출력은 Chrome `infocutter.ruleStore`와 같은 모양(version 4)이어야 하고, 디코딩은 어떤 입력에도 throw하지 않는다.
- 선택자 ContentBlocker는 `lib/infocutter/content_blocker_factory.dart`만 만든다. 액션은 `CSS_DISPLAY_NONE`만 쓰고, 네트워크 필터는 `network_filter_service.dart`에서 `BLOCK`만 쓴다.
- 선택자 생성·검증은 `lib/infocutter/selector_engine.dart`, 저장소 키는 `lib/infocutter/storage.dart`에 있다. 같은 일을 다른 파일에서 새로 구현하지 않는다.
- AI API 키는 `flutter_secure_storage`(`infocutter.aiConfig.apiKey`)에만 둔다. SharedPreferences의 설정 JSON에 키를 쓰지 않는다.
- WebView JS에 사용자 값(선택자, 키워드 등)을 넣을 때는 `jsonEncode`로 리터럴을 만들거나 JavaScriptHandler 인자로 넘긴다. 따옴표로 감싼 문자열 보간을 쓰지 않는다.
- `assets/js/*.js`가 원본이고 `lib/infocutter/generated/user_scripts.g.dart`는 생성물이다. JS 안에 `'''`를 쓰지 않는다. Dart raw 문자열이 끊긴다.
- 색·간격·radius는 `design/design-tokens.json`에서 생성한 `lib/theme/infocutter_tokens.g.dart`를 거친다. 테마 파일에서 `Color(0x...)`를 새로 만들지 않는다.
- 자동화 브리지는 `kDebugMode`에서만 시작하고 루프백 주소에만 bind한다. 임의 JS 실행, 인증된 페이지 내용 읽기·변경, 비밀 덮어쓰기에 해당하는 새 동작은 토큰이 필요한 민감 동작 목록(`AppAutomationBridge`)에 넣는다. 현재 `page.getText`, `page.click`, `page.fill`은 민감 동작 목록에 없어 토큰 없이 현재 페이지를 읽거나 조작할 수 있는 코드 경로가 있다. 실제 기기 재현은 하지 않았다.
- `dart:io` `Process`로 외부 명령을 실행하지 않는다.
- 사용자에게 보이는 문자열은 `lib/l10n/app_en.arb`와 `app_ko.arb`에 같은 키로 넣는다. 템플릿 ARB는 `app_en.arb`다.
- 새 runtime 의존성은 `pubspec.yaml`과 `pubspec.lock`을 같은 커밋에 넣고 커밋 본문에 이유를 적는다. `flutter_inappwebview`는 git 커밋으로 고정되어 있으므로 올릴 때 그 커밋 해시를 바꾼다.

## 구현 방식

- 서비스(`InfocutterService`, `TextBlockService`, `WatchService`, `NetworkFilterService`, `EvidenceService`, AI 서비스들)는 `ChangeNotifier`이고 `lib/infocutter/infocutter_providers.dart`에서 Provider로 연결된다. 변경은 스냅샷을 새로 만들어 저장소 포트에 JSON으로 쓰고 `notifyListeners()`를 부른다.
- 저장소는 인터페이스(`InfocutterStore` 등)와 SharedPreferences 구현으로 나뉜다. 테스트는 `test/infocutter/fakes/`의 가짜 구현을 쓴다.
- 페이지 적용은 두 경로다. ContentBlocker(URL에 맞는 모든 활성 프로필의 최상위 문서 `hide` 규칙)와 runtime contributor(첫 매칭 프로필의 규칙 상태를 JS로 주입)다. 숨김 버그를 볼 때는 어느 경로 문제인지부터 가른다.
- 사이트 전용 처리는 이름 붙은 어댑터로 분리한다. 공용 경로에 호스트 이름 분기를 넣지 않는다.

## 테스트

- 게이트: `flutter pub get`, `flutter analyze`(문제 0건), `flutter test`, `dart run dart_code_linter:metrics analyze lib`(문제 0건), `node tool/js_test.mjs`, `dart run tool/generate_user_scripts.dart --check`, `dart run tool/generate_theme_tokens.dart --check`. 이 앱에는 `.fvmrc`가 없으므로 fvm 전역 버전이 없는 기기에서는 fvm 캐시의 SDK를 직접 쓴다.
- `dart format --set-exit-if-changed lib test`는 Dart 3.12.0 기준 기존 6개 파일 때문에 실패한다. 새로 만들거나 고친 파일은 포맷을 맞춰 커밋한다.
- 반드시 테스트할 것: `isAuthOrigin`의 경계(서브도메인, 유사 도메인, 끝 점, 경로 세그먼트, 비 http 스킴), `RuleStoreCodec`의 Chrome JSON 왕복과 잘못된 입력, ContentBlocker의 카드 꺼짐·전역 꺼짐·`unhide` 처리, 네트워크 필터의 허용 규칙 우선, 증거 중복 판정(URL과 HTML 해시), AI 키가 설정 JSON에 남지 않는지, 자동화 브리지의 접근 제어.
- `integration_test/infocutter_app_smoke_test.dart`는 기기나 시뮬레이터가 있어야 돈다. WebView 주입 JS를 바꿨으면 디버그 빌드를 실제로 띄워 해당 기능을 한 번 실행한다.
