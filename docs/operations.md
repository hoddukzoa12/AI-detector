# 실행과 제출 절차

## npm 준비와 검사

Node 24 LTS와 npm을 설치한다. 검증 버전은 Node 24.19.0/npm 11.9.0이다. manifest 지원 범위는 ^22.13.0 || ^24.0.0 || >=26.0.0이며 지원 표기와 실제 검증 버전을 구별한다. 저장소의 점검 앱 소스가 있는 checkout에서 실행한다.

```sh
cd apps/inspector
npm ci
npx playwright install chromium
npm run dev
```

Linux에서 시스템 라이브러리가 없으면 관리자 권한으로 npx playwright install-deps chromium을 실행한다. npm ci가 먼저이며 npm run dev는 빌드 후 서버를 시작한다. 콘솔의 실제 루프백 URL을 연다. 기본 출력은 작업 폴더 output이고 .env도 작업 폴더에서 읽는다. 관리형 프록시 환경의 Node 24 실행은 NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS="$CODEX_PROXY_CERT" npm run dev로 시작해 기존 HTTP(S)_PROXY와 추가 CA를 함께 사용한다. 일반 인터넷 환경에서는 이 설정이 필요 없다.

```sh
npm run typecheck
npm run lint
npm test
npm run build
npm run test:e2e
npm run self-test
```

자체 점검은 output/self-test의 새 디렉터리에 저장한다. 일반 실행과 이전 자체 점검 결과를 덮어쓰지 않는다. 보고서의 성공과 종료 코드 0을 함께 확인한다. 자체 점검은 모의 OCR/CLEF HTTP를 명시 주입하는 생산 경로 검사이며 실제 외부 요청을 하지 않는다. 제품의 오프라인 광고 판정이나 실모델 정확도 검사가 아니다.

## 실행 설정

OPENROUTER_API_KEY는 필수 CLEF와 선택 Gemini OCR이 공유하는 OpenRouter 키다. 실행에는 키와 CLEF 전송 동의가 필수며 OCR은 기본 꺼짐이다. npm .env·Docker env-file·Windows 실제 exe 옆 .env에서 읽으며 OS 환경변수가 우선한다. 키를 교체한 뒤 완전히 종료·재시작하며 재빌드하지 않는다. INSPECTOR_OUTPUT_DIR는 실제 출력 루트이고 화면에서 확인한다. Windows 기본값은 exe 폴더, Docker는 /app/output이다. INSPECTOR_RUNTIME은 npm/docker/desktop이며 desktop은 실제 exe 위치를 기준으로 설정한다. INSPECTOR_HOST·INSPECTOR_PORT는 bind 설정이고 Docker 밖에서는 루프백을 사용한다. INSPECTOR_CHROMIUM_PATH는 브라우저 실행 경로를 명시할 때 사용한다.

기본 한도는 OCR 100요청·CLEF 1,000요청(재시도 포함), 이미지 원본/PNG 각각 8MiB·16백만 픽셀이다. `INSPECTOR_MAX_OCR_REQUESTS`, `INSPECTOR_MAX_CLEF_REQUESTS`, `INSPECTOR_MAX_IMAGE_BYTES`, `INSPECTOR_MAX_IMAGE_PIXELS`는 1 이상의 안전한 정수로 재시작 시 반영한다. OCR을 끄려면 화면 선택을 해제하며 한도를 0으로 설정하지 않는다. 요청 상한은 달러 비용 보장이 아니다.

기본 500페이지·28분·1280×720, OCR/CLEF 각각 동시 2작업·대기 100개다. OCR 요청은 30초, 최대 32KiB JSON·4,096 출력 토큰이며 429/5xx만 같은 입력으로 최대 한 번 재시도한다. 이미지 GET은 20초·최대 5회 리다이렉트다. 개별 실패·전체 상한·중단을 상태와 검토에 구분해 보존한다.

## Docker와 Windows 배포

Docker와 최신 Compose v2를 설치한 뒤 앱 폴더에서 실행한다.

```sh
install -d -m 0770 output
sudo chown 1001:1001 output
docker build -t inspector:local .
docker compose up --no-build
```

게시 주소는 http://127.0.0.1:4173이다. 컨테이너 UID/GID 1001과 bind 출력 소유권을 맞춘다. 출력 override는 해당 컨테이너 경로의 volume·권한도 변경해야 한다. 다른 UID 실행 시 읽기 가능한 runtime 자산과 출력 소유권을 확인한다. 종료는 docker compose down이며 output은 보존된다.

검증은 docker build -t inspector:verify . 다음 npm run test:docker다. 4173 포트를 비우고 별도 합성 출력만 사용한다. 관리형 프록시 CA는 optional BuildKit secret proxy_ca로 빌드에만 제공하고 런타임 CA는 read-only mount와 NODE_EXTRA_CA_CERTS로 지정하고 Node 24의 NODE_USE_ENV_PROXY=1도 전달해 기존 프록시를 사용한다. TLS 검증·루프백 게시·비특권 실행을 유지한다.

Windows 패키지 빌드는 Linux의 curl/unzip/zip과 앱 npm 의존성이 필요하다. npm run package:win 후 npm run verify:win으로 release의 폴더·ZIP·manifest·고지를 검사한다. 사용자는 ZIP을 쓰기 가능한 폴더에 완전히 풀어 Inspektor.exe를 연다. 별도 Node·Docker·Python·GPU 설치를 요구하지 않는 구성이며 실제 Windows 검증은 별도다. 앱을 종료한 뒤 Inspektor.exe --self-test를 실행하고 self-test 보고서와 종료 코드 0을 확인한다. 이미 실행 중이면 자체 점검은 2다. 창을 닫으면 중단과 저장을 기다린다.

전체 소스는 확정 커밋의 git archive로 만들고 개인 .env·node_modules·output·Git 자료를 넣지 않는다. 앱 전용 소스 ZIP은 기존 저장소 전체를 포함하지 않는다. npm run docs:proposal은 저장소 전체의 기획서 원본과 한글 글꼴을 사용해 8쪽 PDF를 만든다.

## 기존 기반 확인

아래는 기존 소비자 앱의 절차다. 새 점검 앱 실행에 필요하지 않으며 이번 작업에서 기존 Flutter 플랫폼 빌드를 검증하지 않았다. 기존 기록의 Flutter 3.44.0과 manifest 최소 Flutter 3.24.0/Dart ^3.5.0을 구별한다.

## 기존 Chrome 기반 확인

저장소 루트에서 실행한다.

```sh
cd extensions/chrome
npm install
npm run pipe:check
npm run pipe:doctor
```

`npm install`이 먼저다. 공용 빌드 패키지는 `file:../../packages/ext-build`로 연결되며 기존 lock 파일과 경로 차이가 있어 `npm ci`를 정상 설치 절차로 안내하지 않는다. lock 파일이 갱신될 수 있으므로 변경을 확인한다.

실제 DOM 확인은 빌드된 `dist`를 Chrome의 `chrome://extensions`에서 개발자 모드로 로드해 수행한다. content script 변경 후에는 확장을 새로 읽고, 설치 전에 열린 탭과 새 탭을 모두 확인한다.

## 기존 Flutter 기반 확인

Flutter SDK를 설치하고 선택한 SDK의 `flutter`·`dart`가 PATH에서 같은 SDK를 가리키게 한다. Windows 빌드는 Windows 머신의 Visual Studio C++ 데스크톱 도구와 WebView 실행 환경도 필요하다. 이 저장소에는 SDK를 고정한 `.fvmrc`가 없다.

저장소 루트에서 실행한다.

```sh
cd apps/browser
flutter doctor -v
flutter pub get
flutter analyze
flutter test
node tool/js_test.mjs
dart run tool/generate_user_scripts.dart --check
dart run tool/generate_theme_tokens.dart --check
```

Windows 머신에서 기반 빌드 확인:

```sh
cd apps/browser
flutter build windows --release
```

이 명령은 아직 이번 작업에서 실행하지 않았다. 빌드된 exe만 떼어 제출하지 않고 필요한 DLL·데이터·WebView 의존성을 포함한 실행 폴더를 실제 GPU 없는 Windows 11 PC에서 확인해야 한다. 구체적인 배포 방식은 빌드 검증 후 확정한다.

JS 또는 테마 원본을 수정한 뒤 재생성하는 명령:

```sh
cd apps/browser
dart run tool/generate_user_scripts.dart
dart run tool/generate_theme_tokens.dart
flutter gen-l10n
```

## 제출 준비

마감은 2026-10-23 18:00이며 접수 주소는 `gongmo@aipubcon.kr`이다. 이메일 제목은 `공모_작품명_팀명 또는 성명` 형식이다. 이메일 발송은 별도 사용자 지시로 수행한다.

제출 묶음은 참가신청서, 서약서, 개인정보 동의서(팀 전원), 5~10쪽 기획서, Windows 11 실행 파일 및 의존 파일, 전체 소스코드, 실행·빌드 매뉴얼, 사용설명서다. API 사용 시 서비스·모델·환경변수를 사용설명서에 적는다. 라이선스 고지와 코드 출처를 확인하고 실키를 제거한다.

진입 URL 입력부터 완료까지 결과 화면과 `result.json` 생성, UTF-8 인코딩, 필수 필드, 원문 근거, 정확한 위치를 확인한다. 검출 0건·오탐·중첩 iframe·동일 요소 복수 기법·실패 사례를 포함한다. 결과 생성 기본 위치는 실행 파일 폴더다. 다른 위치를 쓰면 사용설명서 첫 장에 경로를 명시한다.

적격평가는 주최 측의 비공개 사이트를 사용하며 URL·위치·유형 추출과 30분 시간 상한을 평가한다. 공개 사이트의 임의 스캔 결과를 해당 평가를 통과했다는 증거로 쓰지 않는다. 현재 라이선스 불일치와 Windows 실행 검증은 제출 전 해결할 사항이다.
