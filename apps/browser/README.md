# Infocutter Browser

보고 싶은 것만 남기는 모바일 브라우저. 페이지에서 가릴 요소를 직접 골라 두면 같은 사이트에 다시 올 때 자동으로 가려집니다.

`chrome-extension-mono/vibecode-chrome-extension-infocutter` (Manifest V3 확장)의 모바일 버전이며 규칙 스키마를 공유합니다.

## 무엇을 하는가

- **요소 선택 차단** — 화면에서 가릴 부분을 골라 셀렉터 규칙으로 저장. 사이트별로 관리됩니다.
- **미리보기(peek)** — 가린 것을 잠깐 되돌려 봅니다.
- **텍스트 블록** — 특정 문구가 포함된 요소를 가립니다.
- **감시(watch)** — 지정한 이름·별칭이 페이지에 나타나면 알립니다.
- **AI 마스킹 제안** — 가릴 만한 요소를 추천합니다.
- **증거 저장** — URL·시각·해시가 담긴 캡처를 남깁니다.
- **네트워크 필터** — 필터 목록을 가져와 요청을 차단합니다.

## 알려진 제약

**Google 계정 로그인은 아직 보장하지 않습니다.** 다만 이전 문서가 단정하던 것보다
상황이 덜 분명합니다. 아래는 2026-08-04 실측 결과입니다.

측정 환경: iOS 시뮬레이터(iPhone 16e / iOS 26.3), Android 에뮬레이터(API 37 / WebView 149).
**실기기가 아니며, 자격증명을 제출한 이후 단계는 확인하지 못했습니다.**

| 항목 | 결과 |
|---|---|
| 로그인 페이지 렌더 | iOS·Android 모두 정상. `disallowed_useragent` 등 차단 문구 없음 |
| `X-Requested-With` | **나갑니다** — `com.dalsoop.infocutter` |
| `Sec-CH-UA` | **`"Android WebView";v="149"`** 로 우리를 웹뷰라고 광고합니다 |
| 헤더 opt-out API | `WebViewFeature.REQUESTED_WITH_HEADER_ALLOW_LIST` 가 **미지원**(`supported=false`) |

두 가지가 분명해졌습니다.

- 우리가 UA 문자열을 어떻게 쓰든 `Sec-CH-UA` 는 플랫폼이 만들어 붙이므로 **웹뷰라는
  사실 자체를 숨길 수 없습니다.** 이는 UA 를 위장하지 않는다는 이 앱의 방침과도 맞습니다.
- `X-Requested-With` 를 끄는 표준 경로(origin allow-list)는 현재 WebView 에서 **기능
  자체가 지원되지 않아** 레버가 되지 못합니다.

앱은 인증 도메인에서 JS 주입·요청 가로채기·콘텐츠 차단을 모두 끄고 안내를 표시합니다.
배제하는 인증 origin(서브도메인 포함, 점 경계 강제):

- 호스트 전체 — `accounts.google.com` · `login.microsoftonline.com` · `appleid.apple.com`
- 경로 한정 — `github.com/login` · `gitlab.com/users/sign_in`

판정은 `lib/infocutter/auth_origin_policy.dart` 의 `isAuthOrigin` 이 담당합니다.
남은 검증(실기기 로그인 제출 이후)과 대응 방향은 이슈 #12 · #21 을 보세요.

## 개발

```sh
cd apps/infocutter-app
fvm flutter pub get
fvm flutter run -d <device>      # ios / android / macos
```

### 디자인 토큰

색·간격·radius 의 정본은 **design-system-studio**(macOS 앱)이고, 앱은 그 export 스냅샷을
거쳐 Dart 를 굽는다.

```
design/design-tokens.json          ← 스냅샷 (정본의 사본, 커밋한다)
tool/generate_theme_tokens.dart    ← 생성기
lib/theme/infocutter_tokens.g.dart ← 생성물 (커밋한다)
lib/theme/infocutter_theme.dart    ← 토큰에 의미 이름을 붙이는 얇은 층
```

**테마 파일에서 색을 새로 만들지 않는다.** 토큰을 늘리고 다시 굽는다.

```sh
# 정본을 고쳤을 때 (design-system-studio 가 있는 기기에서만)
design-system-studio tokens export <set> --format json > design/design-tokens.json

# 어디서나
fvm dart run tool/generate_theme_tokens.dart          # 굽기
fvm dart run tool/generate_theme_tokens.dart --check   # 동기 검사 (CI 가 돌린다)
```

스냅샷을 커밋하는 이유는 `design-system-studio` 가 macOS 앱이라 CI·다른 기여자에게
없기 때문이다. 스냅샷만 있으면 도구 없이도 빌드와 검사가 돈다.

검증 (CI 와 같은 명령):

```sh
fvm flutter analyze
fvm flutter test
fvm dart run dart_code_linter:metrics analyze lib    # WARNING 0 이어야 한다
node tool/js_test.mjs                                # WebView 주입 JS 회귀 그물
fvm dart run tool/generate_theme_tokens.dart --check  # 토큰 생성물 동기
```

품질 점수:

```sh
../../tools/scripts/quality-score.sh apps/infocutter-app
```

### WebView 에 주입하는 JS

`assets/js/*.js` 가 정본입니다. Dart 상수(`lib/infocutter/generated/user_scripts.g.dart`)는
생성물이므로 직접 고치지 마세요.

```sh
fvm dart run tool/generate_user_scripts.dart           # .js → .g.dart
fvm dart run tool/generate_user_scripts.dart --check    # 동기 여부 검사
```

## 출처

[pichillilorenzo/flutter_browser_app](https://github.com/pichillilorenzo/flutter_browser_app)
(Apache-2.0)에서 fork 했습니다. 브라우저 셸(탭·주소창·설정·개발자 도구)이 그 계보이며,
인포커터 기능(`lib/infocutter/`)은 이 저장소에서 추가한 것입니다.
