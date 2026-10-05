# 설치·빌드 및 소스 재현

Node 24 LTS(검증: 24.19.0), npm 11.9.0을 권장합니다. 지원 Node 범위는 `^22.13.0 || ^24.0.0 || >=26.0.0`이며 다른 지원 버전의 실행은 별도 확인해야 합니다. Windows 교차 패키지 빌드는 `curl`, `unzip`, `zip`을 제공하는 Linux 환경에서 검증했습니다.

```bash
unzip infocutter-mono-source.zip
cd infocutter-mono/apps/inspector
npm ci
npx playwright install chromium
npm run dev
```

전달한 전체 소스 ZIP을 받은 폴더에서 시작하세요. 원격 원본 main에는 이번 구현이 아직 게시되지 않았으므로 원본 clone만으로 이 앱을 실행할 수 없습니다. Linux에 브라우저 시스템 라이브러리가 없으면 관리자 권한으로 `npx playwright install-deps chromium`이 필요합니다. Docker는 해당 라이브러리를 이미지에 포함합니다.

```bash
npm run typecheck
npm run lint
npm test
npm run build
npm run test:e2e
npm run self-test
```

빌드 결과는 `dist/`입니다. 자체 점검은 기본 출력 루트의 `self-test/` 아래에 별도 생성하며 모의 OCR/CLEF를 사용하며 외부 API 요청을 하지 않습니다. 제품의 오프라인 판정은 아닙니다. 반복 실행은 기존 실행을 보존합니다.

## Docker

Linux 호스트에서 먼저 출력 폴더를 생성하고 컨테이너 UID/GID 1001에 쓰기 권한을 줍니다.

```bash
install -d -m 0770 output
sudo chown 1001:1001 output
docker build -t inspector:local .
docker compose up --no-build
```

`http://127.0.0.1:4173`을 엽니다. Host/Origin 검사는 이 실제 포트를 사용하므로 게시 포트를 임의로 바꾸지 않습니다. Docker Compose의 optional env-file 기능이 필요한 최신 Compose v2를 사용하세요. 종료는 `docker compose down`입니다. 출력 bind 데이터는 유지됩니다.

```bash
docker build -t inspector:verify .
npm run test:docker
```

검증은 컨테이너의 자체 점검과 실제 서버·브라우저 화면, 호스트 볼륨의 결과 해시를 검사합니다. 테스트가 사용하는 4173 포트를 먼저 비우세요. 테스트용 합성 출력만 읽기 권한을 완화하며 일반 점검 근거는 비공개 파일 권한을 유지합니다.

관리형 프록시의 사용자 CA가 필요한 경우 다음처럼 빌드 단계에만 secret을 제공합니다. 일반 환경에서는 필요 없습니다.

```bash
docker build --secret id=proxy_ca,src="$CODEX_PROXY_CERT" -t inspector:local .
```

실제 점검은 .env의 OPENROUTER_API_KEY 설정과 화면의 CLEF 전송 동의가 필요합니다. OCR은 실행별 선택이며 기본 꺼짐입니다. 관리형 프록시에서 npm 앱의 실제 모델 호출은 Node 24 기준 `NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS="$CODEX_PROXY_CERT" npm run dev`로 시작하세요. 컨테이너에도 기존 HTTP(S)_PROXY와 `NODE_USE_ENV_PROXY=1`을 전달하고 CA를 read-only로 mount해 `NODE_EXTRA_CA_CERTS`를 실제 컨테이너 파일 경로로 지정합니다. 일반 인터넷 환경에서는 필요 없으며 TLS 검증을 끄지 않습니다.

## Windows 폴더와 ZIP

```bash
npm run package:win
npm run verify:win
```

`release/Inspektor-win32-x64/`, 실행 ZIP, 파일별 manifest, `SHA256SUMS.txt`, 앱 전용 `inspector-source.zip`을 생성합니다. Electron 44.5.1, 자체 점검용 Node 24.19.0, Playwright 1.63.0/Chromium 153.0.8010.12 revision 1243, production 의존성과 토크나이저를 포함합니다. GUI 서버는 Electron 내장 Node에서 실행합니다. 외부 bundled Node 버전을 GUI 내장 Node 버전으로 간주하지 않습니다.

공식 HTTPS SHASUMS로 Electron·Node 다운로드를 확인합니다. 이번 검증의 metadata 재요청은 HTTP503으로 실패해 이전에 검증·보존한 동일 버전 공식 checksum과 Chromium LICENSE를 해시 대조 후 재사용했습니다. 바이너리·전체 파일·ZIP 검사는 다시 통과했지만 새 metadata HTTP 다운로드 성공으로 기록하지 않습니다. 일반 빌드의 고정 HTTPS 경로와 TLS 검증은 유지합니다. 서명 검증은 미수행입니다. Chromium은 공식 ZIP에서 관측해 고정한 SHA256를 사용하며 upstream 공개 checksum 파일은 찾지 못했습니다. 정적 검사는 필수 자산·전체 파일 해시·PE x64 구조를 확인하며 실제 Windows 실행을 대신하지 않습니다.

앱 전용 소스 ZIP은 기존 Flutter·확장 소스와 저장소 문서를 포함하지 않습니다. 전체 전달 소스는 아래 명령으로 확정 커밋의 tracked 파일만 내보냅니다.

```bash
git archive --format=zip --prefix=infocutter-mono/ HEAD -o apps/inspector/release/infocutter-mono-source.zip
```

node_modules·실행 출력·개인 `.env`·Git 자료는 포함하지 않습니다. 출력 ZIP은 Git에 추가하지 않습니다. 저장소 전체 배포 권리가 확정되지 않았으므로 ZIP 생성이 재배포 허가를 뜻하지 않습니다.

기획서 PDF는 저장소 전체 소스와 한글 글꼴(Noto Sans CJK KR 등)을 설치한 환경에서 `npm run docs:proposal`로 생성합니다. 출력은 `release/docs/기획서.pdf`이며 실제 8쪽을 확인했습니다. 앱 전용 소스 ZIP에는 저장소의 기획서 원본이 없으므로 전체 소스를 사용하세요.
