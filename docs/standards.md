# 개발 규칙

## 원문과 산출물의 일치

점검 원문을 확보하기 전에 기존 마스킹, ContentBlocker, 네트워크 차단, 지연 이미지 변경을 적용하지 않는다. 탐지 위치는 결과가 가리키는 요소로 다시 조회해 유일하게 식별되는지 검증한다. 여러 요소를 가리키는 선택자를 임의로 정답 위치로 제출하지 않는다. 원문과 분석용 문자열을 같은 값으로 덮어쓰지 않는다.

결과 파일 작성은 한 경로에서 수행하고 화면과 파일은 같은 판정 결과를 소비한다. 필수 네 유형과 추가 유형은 출력 파일을 분리한다. JSON 파일은 UTF-8 BOM 없이 생성하며, 검출 0건에서도 `findings: []`를 쓴다.

Windows 11에서 실행하지 않은 산출물을 Windows 실행 검증 완료로 표시하지 않는다. GPU가 없는 Windows 11 PC에서 도구가 실행되어야 한다. 현재 OCR과 광고 분류는 외부 API이며 모델 가중치·Python·GPU 설치를 요구하지 않는다. 파일 생성, 전체 스키마, 중첩 iframe 위치, 중복 제거, 두 기법이 겹친 요소, 오탐 사례와 접근 실패를 검증 대상으로 포함한다.

## 현재 코드의 경계

- Chrome의 background·popup·options·content 레이어는 서로 import하지 않는다. 공유 기능은 shared 또는 도메인 패키지에 둔다.
- Chrome content script는 일반 스크립트로 함께 로드된다. `import`·`export`를 넣거나 실제 manifest 주입 목록과 재주입 목록을 서로 다르게 만들지 않는다.
- 도메인 패키지에 `chrome.*` 접근을 넣지 않는다. DOM 헬퍼는 문서·요소를 인자로 받도록 유지한다.
- Flutter 도메인 판정은 `lib/infocutter`에 두고, 화면·앱 시작 코드에 새 판정 로직을 넣지 않는다. 새 점검 모듈은 독립 npm 패키지 apps/inspector에서 관리한다.
- 기존 데이터 형식을 바꿀 때 이전 입력을 읽는 경로와 데이터 보존 검증을 함께 둔다. 불법광고 결과를 기존 숨김 규칙 저장소에 억지로 맞춰 저장하지 않는다.
- 사용자 값을 WebView JS에 넣을 때 `jsonEncode` 또는 핸들러 인자를 사용한다. 문자열 따옴표 보간, `eval`, 원격 코드 로딩은 사용하지 않는다.

## 생성물과 의존성

`apps/browser/assets/js`가 원본이고 `lib/infocutter/generated/user_scripts.g.dart`는 생성물이다. JS 수정과 재생성을 같은 변경에 넣는다. 디자인 값도 커밋된 JSON에서 생성한다. 생성물만 직접 고치지 않는다.

의존성을 변경하면 해당 manifest와 lock 파일을 같은 변경에 포함한다. 새 런타임 의존성은 도입 이유를 남긴다. 기존 `flutter_inappwebview`는 고정 git 커밋을 사용하므로 변경 시 버전을 식별할 수 있어야 한다. 코드 출처·라이선스 고지를 보존하며, 루트 라이선스가 확정되기 전 저장소 전체를 MIT로 간주하지 않는다.

## 변경 확인

기존 Chrome 코드를 바꾸면 `extensions/chrome`에서 `npm run pipe:check`, `npm run pipe:doctor`를 수행한다. DOM 동작은 단위 테스트만으로 검증되지 않으므로 변경된 경로를 실제 브라우저에서도 확인한다.

기존 Flutter 코드를 바꾸면 `apps/browser`에서 `flutter analyze`, `flutter test`, `dart run dart_code_linter:metrics analyze lib`, `node tool/js_test.mjs`, `dart run tool/generate_user_scripts.dart --check`, `dart run tool/generate_theme_tokens.dart --check`를 수행한다. 새로 만들거나 고친 Dart 파일은 포맷한다. 플랫폼 실행 검증은 정적 분석·단위 테스트와 별도로 기록한다.

문서만 바꾼 경우에는 링크·경로·기존 코드에 대한 주장·구현과 계획 구분을 확인한다. 과거 테스트 기록을 새로 실행한 테스트로 바꾸지 않는다. 실행하지 못한 검사는 이유와 함께 미검증으로 남긴다.

## Git과 비밀

기능 변경은 브랜치에서 검토하고 커밋 제목은 `<type>(<scope>): <요약>`으로 쓴다. 스테이징 경로를 지정하고 다른 사람의 변경을 한꺼번에 넣지 않는다.

API 키·서명 키·서비스 토큰을 소스, 테스트 입력, 문서, 제출 파일에 넣지 않는다. `.env` 샘플에는 빈 값과 설정 이름만 둔다. 기존 소비자 기능의 문자열을 고칠 경우 Flutter의 한국어·영어 ARB 키를 함께 유지한다.

## 점검 앱의 변경 기준

core는 wire 계약과 실행 상태 검증만 맡고 브라우저·HTTP·파일을 import하지 않는다. detection은 네 은닉 관측과 소유자별 readable OCR 연결만 맡으며 광고 문맥 판정·브라우저·저장·AI 호출을 넣지 않는다. crawler/dom·ocr·classification·output은 core 계약으로 연결하고 application이 실제 흐름을 제어한다. 로컬 광고 키워드 판정·실패 fallback이 생기면 위반이다. web은 API 자료만 소비하며 Node 자격 증명을 import하지 않는다. desktop과 npm/Docker는 같은 서버·코어를 사용한다.

의존 버전·lock·Playwright browser revision·Docker digest·Windows asset 해시를 일치시킨다. 새 production 의존성을 추가하면 패키지 allowlist·필수 자산 검증·고지 목록을 같이 갱신한다. 선택자 검증은 실제 프레임 DOM으로 수행하고 공식 JSON 검증은 생산 탐지 알고리즘과 독립된 정답을 사용한다.

점검 앱 코드 변경은 typecheck·lint·단위·build·통합·자체 점검을 모두 통과해야 한다. 배포 코드 변경은 Docker 실제 서버/화면/출력 볼륨과 Windows 패키지 정적 검증도 수행한다. 모의 AI 응답·Linux desktop-mode CLI·Windows PE 검사에 실제 서비스/Windows 실행 성공 표기를 붙이지 않는다. 키 비노출·중단 후 결과 불변·저장 실패 시 이전 archive 보존을 검사한다. V2의 두 결과 파일·상세 일대일·이미지 발생/소유 관계·원문 범위·원본/PNG 실제 해시를 독립 정답과 비교한다. V1 자료는 읽기 호환성만 유지하고 새 실행에 local 출처·LOCAL_UNCERTAIN을 생성하지 않는다. 실제 모델 평가는 수작업 정답·요청 상한·재시도 수·지연·사용량을 별도 기록한다. 모의 성공을 실제 인식/분류 정확도로 발표하면 위반이다.
