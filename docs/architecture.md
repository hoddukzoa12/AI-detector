# 시스템 구성

공개 웹사이트 관리자가 URL 하나로 은닉 텍스트와 일반·숨김 이미지 광고를 점검하는 로컬 도구다. 독립 npm 앱 `apps/inspector`에서 같은 코어를 웹·Docker·Electron 화면에 제공한다. 기존 Flutter·Chrome 소비자 앱은 실행 의존성이 아니다.

## 구성과 연결

| 구성 | 역할과 의존 방향 |
|---|---|
| core | 공식 결과·별도 상태·실행 ID 계약. 다른 구현을 참조하지 않음 |
| dom | 페이지 안에서 원문 소유 요소·스타일·유일 선택자 관측. core 자료 반환 |
| crawler | Playwright로 공개 페이지·프레임을 읽고 dom 관측을 core 자료로 반환 |
| detection | 수집 자료에서 네 은닉 기법을 관측하고 읽힌 이미지 글자를 소유 요소별 후보로 연결. 브라우저·저장·외부 HTTP 없음 |
| ocr | 등록 PNG에서 Gemini로 글자·읽기 상태 추출. 광고 여부를 판정하지 않음 |
| classification | 원문 범위와 토큰을 계산하고 OpenRouter Decisions HTTP 응답을 판정 자료로 반환 |
| output | 공식/추가 JSON·검토·상세·상태·DOM/이미지 근거를 실행별 로컬 파일로 보존 |
| application | 수집→은닉 관측/선택 OCR→필수 CLEF 분류→저장을 연결하며 실행과 중단 제어 |
| server | application의 로컬 HTTP 인터페이스와 웹 정적 자산 제공 |
| web | HTTP 실행 상태·확정·검토·근거를 표시하고 저장 JSON 다운로드 |
| desktop | Electron 화면으로 같은 서버를 열고 패키지 경로·종료 제어 |
| scripts | 빌드·패키지·자체 점검과 독립 결과 검증 |

대표 흐름은 웹의 URL 시작 요청→서버 입력 확인→실행 ID 생성→새 Chromium 컨텍스트의 같은 hostname 방문→전체 프레임 관측→직접 원문 은닉 후보와 이미지 후보→CLEF 판정→공식/추가 확정·검토 보존→화면 상태와 다운로드다. 수집 HTML을 웹 화면이나 Electron renderer에서 실행하지 않는다.

Node가 필수 CLEF의 고정 Decisions endpoint에 후보 원문·별도 정규화 텍스트·소유 링크를 전송한다. 이미지 OCR을 선택하면 별도의 고정 Chat Completions endpoint에 Gemini 분석 PNG를 전송한다. OCR 응답의 글자·읽기 상태와 CLEF 응답의 광고 확률은 별개다. HTML·쿠키·전체 방문 기록은 전송하지 않고 위치·은닉 기법은 로컬 관측 자료를 유지한다. 모델 실패를 로컬 광고 판정이나 다른 모델로 대체하지 않는다. CLEF 토크나이저만 포함하고 모델 가중치·Cloudflare 직접 계정 ID를 요구하지 않는다.

## 실행과 파일 경계

npm 서버와 Docker 웹 화면은 HTTP를 사용한다. Electron main은 같은 서버를 임의 루프백 포트에 시작하고 renderer는 HTTP만 사용한다. 자체 점검 CLI는 bundled Node로 별도 실행하며 기존 결과를 덮어쓰지 않는 출력 하위 경로를 사용한다.

네 유형의 result.json과 IMAGE_AD_OCR의 result_extra.json은 같은 실행 정보지만 별도 탐지 목록이다. 이미지 발생별 원본/PNG·OCR·소유자·프레임·해시를 연결하고 같은 PNG의 추출 캐시와 서로 다른 소유자의 분류를 구별한다. 확정 결과·검토·상세·상태·근거는 하나의 실행 ID로 연결한다. 실행별 archive를 먼저 보존한 뒤 최신 파일을 교체하고 최신 표시를 마지막에 쓴다. 서버는 해당 실행에 등록된 파일·근거만 제공한다. 별도 중앙 서버·계정·모바일 배포는 현재 목표 범위에 없다.

## 현재 코드의 재사용 경계

| 구성 요소 | 현재 역할 | 전환 시 활용과 제한 |
|---|---|---|
| `apps/browser` | Flutter 브라우저, WebView, Dart 서비스, 로컬 증거 저장 | 근거 확인·파일 저장의 구현 참고. 제출 실행 기반은 npm 쪽이며 기존 차단 기능을 점검 페이지에 적용하지 않는다 |
| `apps/browser/assets/js` | 피커, 마스킹 런타임, 키워드 선택, 지연 이미지 변경 | 선택자 생성과 DOM 접근 참고. 현재 스크립트 전체를 점검 페이지에 주입하는 방식은 부적합하다 |
| `extensions/chrome` | Chrome MV3 확장과 TypeScript DOM 처리 | 선택자 생성, 프레임 문맥, 텍스트 순회, PDF 근거 저장 참고. 확장 설치만으로 Windows 제출 앱을 대체하지 않는다 |
| `extensions/chrome/packages`의 네 패키지 | 선택자 규칙, 텍스트 블록, 감시, 필터 해석 | 브라우저 API와 저장소를 분리한 함수의 재사용 후보. 차단 규칙은 불법광고 탐지 결과가 아니다 |
| `packages/ext-build` | 확장 빌드·진단·패키징 | 기존 확장 검증에 사용. 제출 앱의 패키징 도구로 확정하지 않았다 |
| `packages/ext-runtime` | MV3 공통 코드 | 현재 이 저장소에 소비자가 없다. 제출 도구의 의존성으로 간주하지 않는다 |
| `apps/browser/mcp` | 디버그 앱의 로컬 자동화 브리지 호출 | 개발 확인용 통로. 제출 앱이 실행되기 위한 필수 서비스가 아니다 |
| `extensions/chrome/introduce` | 기존 소비자 제품 소개·블로그 | 기존 정적 콘텐츠이며 공모전 결과 화면이나 제출물에 포함되는 구현이 아니다 |

Chrome과 Flutter는 규칙 JSON 일부를 공유하지만 실행 코드는 별개다. TypeScript를 바꿔 Flutter 동작이 바뀐다고 가정하거나, 반대 방향의 동기화를 가정하지 않는다. 기존 프레임 식별은 주로 origin+pathname이며, 공모전의 중첩 iframe 위치 표기를 그대로 충족하지 않는다.

## 기존 외부 의존

Flutter WebView의 고정 git 의존성과 Chrome의 jsPDF·브라우저 캡처 API는 기존 앱에 남아 있다. 새 점검 앱은 이 서비스·브리지를 연결하지 않으며, 기존 Chrome·Flutter 규칙 JSON의 일부 공유를 실행 코드 동기화로 간주하지 않는다. 선택자 구현은 확인했지만 새 앱으로 복사·import하지 않았다.
