# 공개 웹사이트 점검 실행·배포 안내

Windows 기본 결과 저장 위치는 `Inspektor.exe`가 있는 폴더 자체입니다. `INSPECTOR_OUTPUT_DIR`를 설정하면 그 실제 절대 경로가 화면에 표시됩니다. 쓰기 가능한 폴더에 ZIP을 풀어 실행하세요. `Program Files` 같은 쓰기 제한 폴더에서는 먼저 저장 위치를 지정해야 합니다.

## Windows 11 사용자

`Inspektor-win32-x64.zip`을 완전히 압축 해제하고 `Inspektor.exe`를 실행합니다. 필요한 Electron DLL, Windows Node, Playwright와 Chromium, CLEF 토크나이저가 함께 들어 있습니다. 사용자는 Node/npm, Python, Docker, GPU, 로컬 AI 모델을 설치하지 않습니다. GPU 가속은 앱 시작 전에 끕니다. 앱은 127.0.0.1의 임의 포트만 사용합니다.

공개 진입 URL을 넣고 점검을 시작하세요. 같은 hostname 공개 페이지와 포함된 외부 iframe을 읽으며, 외부 사이트 링크·다른 서브도메인·로그인·폼 작성·사이트 변경을 수행하지 않습니다. 화면은 수집 HTML을 텍스트로만 표시합니다. 점검 중 창을 닫으면 취소와 결과 저장을 기다린 뒤 종료합니다. 부분 완료와 실패는 정상 완료와 구분합니다.

CLEF 키와 후보 전송 동의가 점검에 필수입니다. 광고 문맥은 OpenRouter의 `cloudflare/clef`, 고정 `POST https://openrouter.ai/api/alpha/decisions`를 사용합니다. 은닉이 관측된 직접 텍스트와 읽힌 이미지 원문·소유 링크를 전송하며 전체 페이지·쿠키·방문 기록은 보내지 않습니다. 확정 판정과 불확실한 검토 후보는 분리됩니다. OCR은 기본 꺼짐이며 선택 시 `google/gemini-3.8-flash`의 고정 Chat Completions endpoint에 등록 PNG 한 프레임을 전송합니다. 로컬 광고 판정·실패 fallback은 제공하지 않습니다.

점검 전에 `inspector.env.example`을 참고해 실제 `Inspektor.exe` 옆에 `.env`를 만들고 `OPENROUTER_API_KEY`를 설정하세요. 키를 바꾼 뒤 앱을 완전히 종료하고 다시 실행하면 됩니다. 재빌드는 필요 없습니다. OS 환경변수가 `.env`보다 우선합니다. Node만 키를 읽으며 화면·점검 사이트·결과·로그로 전달하지 않습니다. 키가 있는 `.env`는 제출 ZIP이나 소스에 넣지 마세요.

기본 파일은 `result.json`(네 유형 공식 확정), `result_extra.json`(이미지 확정), `ocr.json`(이미지 추출·근거), `scan-status.json`(완료 상태·오류·해시), `review.json`(검토 후보), `finding-details.json`(상세 판정)입니다. 실행별 파일과 원문 근거는 `runs/<runId>/`에 보존합니다. 화면의 JSON 다운로드는 이 저장본의 추가 복사입니다.

자체 점검은 앱을 모두 종료한 뒤 `Inspektor.exe --self-test`를 실행합니다. 실제 GUI exe를 기준으로 `.env`를 읽고, bundled Node/Chromium과 명시적 모의 OCR/CLEF로 합성 사이트를 검사합니다. 외부 API 요청·제품 오프라인 판정·실모델 정확도 검사는 아닙니다. 자체 점검은 지정 출력 위치의 `self-test/` 아래에 기록해 기존 결과를 덮어쓰지 않습니다. 기존 앱이 실행 중이면 자체 점검은 종료 코드 2이며, 실제 검사를 수행한 자식 프로세스만 성공 코드 0을 반환합니다.

## npm 실행 및 Windows 패키지 빌드

개발·패키지 생성에는 Node 24 LTS(검증 버전 24.19.0), npm, Linux의 `curl`, `unzip`, `zip`이 필요합니다. 고정 개발 버전은 Node 24.19.0/npm 11.9.0입니다. `apps/inspector`에서 `npm ci`, `npx playwright install chromium`, `npm run dev`를 실행하세요. npm 모드는 현재 앱 작업 폴더의 `.env`, 기본 `output/`을 사용합니다.

`npm run package:win`은 빌드 후 `release/Inspektor-win32-x64/`, 실행 ZIP·파일 SHA256 manifest, 앱 소스 allowlist ZIP, `SHA256SUMS.txt`를 만듭니다. `node scripts/verify-win.mjs`로 재검증합니다. 소스·의존성은 전용 staging에 복사하며 shared node_modules 폴더를 통째로 복사하지 않습니다. production 전용 `npm ci --omit=dev --ignore-scripts`로 설치하고 런타임에 개발 의존성은 넣지 않습니다. `.env`, output, 다른 프로젝트·Git 자료는 allowlist에 없습니다.

Electron 44.5.1, Node 24.19.0은 공식 HTTPS SHASUMS256로 다운로드를 확인합니다(서명 검증은 별도 미수행). Playwright 1.63.0과 일치하는 Windows Chromium 153.0.8010.12/revision 1243을 포함하고 다운로드 SHA256를 고정합니다. Chromium의 공개 upstream checksum 파일은 확인하지 못했으므로 이 해시는 공식 배포 파일에서 관측해 고정한 값입니다. 패키지의 모든 exe/DLL은 PE32+ x64 헤더를 검사하고 파일별 SHA256를 기록합니다. 캐시는 `release/cache/`에만 남습니다. 고정 버전·내용을 재현하며 ZIP의 바이트 단위 재현은 파일시각 때문에 보장하지 않습니다.

## Docker

앱 폴더가 build context입니다. Playwright 1.63.0 Noble 이미지를 digest로 고정하고 이미지의 matching Chromium을 사용합니다. `docker build -t inspector:local .` 다음 `docker compose up --no-build`를 실행하세요. 기본 게시 주소는 `http://127.0.0.1:4173`이며 컨테이너는 `0.0.0.0:4173`입니다. Host/Origin 검사는 이 실제 포트의 루프백 별칭만 허용하므로 게시 포트를 임의 변경하지 마세요. 호스트 network, privileged 모드, TLS 검증 해제를 사용하지 않습니다.

컨테이너의 기본 결과는 `/app/output`이고 호스트 `./output`으로 연결됩니다. `INSPECTOR_OUTPUT_DIR`를 바꾸면 컨테이너 내부 실제 저장 경로가 화면에 표시되며 그 경로의 volume과 쓰기 권한도 맞춰야 합니다. 고정 이미지의 pwuser UID/GID는 1001입니다. Linux에서는 출력 폴더를 사전 생성하고 해당 UID에 쓰기 권한을 부여하세요(예: `install -d -m 0770 output` 및 소유자를 1001:1001으로 설정). 다른 UID를 사용하는 경우 `docker compose run --service-ports --user UID:GID inspector`와 출력 소유권을 맞춰야 합니다. 런타임 코드·자산은 이 사용자도 읽을 수 있는 권한으로 패키징합니다. Windows Docker Desktop에서는 bind 폴더의 쓰기 허용을 확인하세요.

호스트 `.env`를 명시적으로 설정 파일로 사용합니다. Compose는 `.env`가 있으면 env_file로 전달합니다. 키가 없으면 화면은 열려도 실제 점검 시작을 거부합니다. `docker run`에서는 `--env-file .env`와 `--mount type=bind,src=<output절대경로>,dst=/app/output`을 직접 지정하세요. `.env`와 output은 이미지 build context에서 제외됩니다.

관리형 cloud proxy 환경의 빌드는 `docker build --secret id=proxy_ca,src="$CODEX_PROXY_CERT" -t inspector:local .`을 사용합니다. npm install 단계에서만 optional secret으로 CA를 읽고 이미지에 복사하지 않습니다. 관리형 프록시에서 실제 AI 호출을 실행할 때 Node 24의 `NODE_USE_ENV_PROXY=1`과 기존 HTTP(S)_PROXY를 함께 사용합니다. npm 앱은 `NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS="$CODEX_PROXY_CERT" npm run dev`로 시작하세요. 컨테이너는 CA를 read-only로 mount하고 `NODE_EXTRA_CA_CERTS`에 해당 컨테이너 경로를 지정합니다. 일반 환경에서는 CA secret 없이 빌드할 수 있습니다. TLS 검증은 유지합니다.

Docker 검증은 `docker build -t inspector:verify .` 후 `npm run test:docker`를 실행합니다. 자체 점검과 실제 production 서버·화면을 모두 실행하며 `release/verification/ocr-clef/docker-check-report.json`을 생성합니다. 이 검사 전용으로 비어 있는 합성 결과 폴더만 `/app/output`에 bind하세요. 실제 production `dist/main.mjs`, 정상 bootstrap token, Host/Origin 검사, 독립 합성 사이트와 matching Chromium을 통해 공식 JSON 25개 정답·원문·위치·유형·해시를 검증합니다. 합성 결과 출력과 보고서는 host에서도 읽을 수 있게 보존합니다.

## 라이선스 및 검증 한계

Electron LICENSE와 LICENSES.chromium.html, matching Chromium 공식 LICENSE와 ABOUT, Node LICENSE, npm production 의존성 LICENSE/NOTICE, Hugging Face tokenizer LICENSE와 provenance를 보존합니다. `resources/browser/LICENSES.chromium.html`은 고정 Windows ZIP의 `chrome-win64/resources.pak`에서 전체 generated credits HTML을 재현 추출한 파일이며 resource ID·원본 pak 해시·HTML 해시를 provenance에 기록합니다. Chrome의 matching 바이너리 자체에 chrome://credits/terms도 포함되어 있습니다. 루트 LICENSE 부재와 기존 Flutter Apache 라이선스의 저장소 전체 적용 여부는 미해결이며 이 패키지가 새 저작권이나 추가 허가를 부여하지 않습니다.

Linux 교차 패키징과 PE·해시 검사는 실제 Windows 실행 검증을 대신하지 않습니다. GPU 없는 Windows 11에서 exe 실행, 화면 조작, 키 교체, 정상 종료/취소, 규격 출력, --self-test는 별도로 수행해야 합니다. Linux에서 실제 소형 OCR 8·CLEF 10회가 HTTP200으로 끝났고 읽을 수 있는 6이미지 문자 차이 0·CLEF 수동 선택9/10을 측정했습니다. 나머지 MEMBER는 불확실 검토이며 확정 오탐이 아닙니다. 대표 실사이트 정확도·실제 두 키 교체·Windows 호출은 남아 있습니다. 최신 공식 metadata 재요청503 때문에 검증된 동일 버전 checksum·LICENSE 캐시를 해시 대조 후 재사용했으며 새 HTTP 성공/서명 검증을 주장하지 않습니다. 현재 패키지를 공모전 제출 준비 완료로 표시하지 마세요.
