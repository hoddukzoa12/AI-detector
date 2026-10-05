# 공개 웹사이트 불법광고 점검

공개 URL을 입력하면 같은 hostname의 페이지와 포함된 iframe을 읽어 네 은닉 기법의 광고 후보를 수집합니다. 원문·요소 위치·근거를 보존하고 확정 결과와 검토 후보를 나눕니다. 광고 문맥은 OpenRouter CLEF만 판정하며 키와 전송 동의가 필수입니다. 일반·숨김 이미지 글자는 선택 Gemini OCR로 추출합니다. OCR은 기본 꺼짐이며 로컬 광고 판정은 제공하지 않습니다.

```bash
cd apps/inspector
npm ci
npx playwright install chromium
npm run dev
```

Node 24 LTS를 권장합니다. 콘솔의 루프백 URL을 브라우저로 여세요. Linux의 브라우저 시스템 라이브러리가 없으면 Playwright의 의존성 설치가 필요합니다. `npm run build` 후 `node dist/main.mjs`로도 실행할 수 있습니다.

기본 결과는 앱 작업 폴더의 `output/`입니다. `result.json`, `result_extra.json`, `scan-status.json`, `review.json`, `finding-details.json`, `ocr.json`과 `runs/<runId>/` 원문 근거를 생성합니다. `INSPECTOR_OUTPUT_DIR`로 바꿀 수 있고 화면에 실제 경로를 표시합니다. `.env`는 작업 폴더에 두며 OS 환경변수가 우선합니다. 키 변경 후 재시작하세요.

```bash
npm run typecheck
npm run lint
npm test
npm run build
npm run test:e2e
npm run self-test
docker build -t inspector:verify .
npm run test:docker
npm run package:win
npm run verify:win
```

`docker compose up --build`의 게시 주소는 `http://127.0.0.1:4173`입니다. Linux 출력 bind 폴더는 UID/GID 1001에 쓰기 권한이 있어야 합니다. Windows ZIP은 `release/Inspektor-win32-x64.zip`에 생성되며 사용자에게 Node·Docker·GPU를 요구하지 않습니다. 자체 점검은 기존 결과를 덮어쓰지 않는 `self-test/`에 저장합니다.

점검 전 `.env`의 `OPENROUTER_API_KEY`를 설정하고 화면에서 CLEF 전송에 동의합니다. OCR을 켜면 `google/gemini-3.8-flash`의 고정 `https://openrouter.ai/api/v1/chat/completions`에 포함 이미지의 PNG 한 프레임을 전송합니다. 이미지 결과는 `result_extra.json`의 `ETC/IMAGE_AD_OCR`로 네 DOM 유형과 분리합니다. 고정 endpoint는 `https://openrouter.ai/api/alpha/decisions`, 모델은 `cloudflare/clef`입니다. 후보의 원문·정규화 텍스트·링크만 보내며 쿠키와 전체 페이지는 보내지 않습니다. 불확실·오류·미완료 후보는 검토 목록에 남습니다.

단위 471개·통합 14개, 모의 OCR/CLEF의 DOM25건·빈 결과0건·이미지20양성 소유자·메뉴 22음성/5양성, 실제 화면·PNG·다운로드·중단·해시를 확인했습니다. 자체 점검은 명시적 모의 transport로 외부 요청 없이 수행합니다. 실제 소형 평가 OCR 8·CLEF 10회는 모두 HTTP200이었고 읽을 수 있는 6이미지 문자 차이 0·분류 선택9/10을 측정했습니다. 실제 사이트 대표 정확도·Windows11 GUI·실제 두 키 교체는 미검증입니다. 저장소 전체 라이선스도 확정되지 않았으므로 현재 상태를 제출 준비 완료로 판단하지 마세요.

실행·배포 세부 절차는 [PACKAGING.md](PACKAGING.md), 제출용 자료는 저장소의 `docs/submission/`에 있습니다. 기존 Flutter·확장 코드는 소비자 앱 자료이며 이 점검 앱을 실행하는 데 필요하지 않습니다.
