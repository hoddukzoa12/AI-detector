# Windows Actions 실행 검증

워크플로는 `.github/workflows/windows-test.yml`이며 main push·pull request·수동 실행에 반응한다. GitHub 표준 Ubuntu 24.04와 Windows Server 2025 러너를 사용한다. 저장소 contents 읽기 권한만 요청하고 외부 API 키·사용자 파일·유료 OCR/CLEF 요청을 사용하지 않는다.

Linux 작업은 고정 Node 24.19.0으로 잠금 파일 설치, Chromium 설치, typecheck·lint·build·단위·통합·자체 점검, Windows 패키징과 정적 검사를 순서대로 수행한다. 공식 자산 HTTPS checksum·고지·파일 해시 검증을 유지하며 로컬의 임시 캐시 재사용 도구를 CI로 가져오지 않는다. 다운로드 실패는 실패로 기록한다.

Windows 작업은 생성 ZIP의 SHA256를 대조하고 압축을 푼 뒤 전체 패키지 파일을 검증한다. `scripts/windows-runner-check.mjs`가 bundled node.exe와 Chromium으로 자체 점검을 실행하고, 실제 Inspektor.exe의 --self-test를 실행한다. 각 보고서의 win32·desktop·합성 transport·DOM25·이미지20소유자/39발생·메뉴22음성 근거를 확인한다. 실제 EXE GUI를 열어 로컬 화면·키 미설정·OCR 기본 꺼짐·전송 동의·sandbox·context isolation·Node integration off·GPU 가속 off와 정상 종료를 확인하고 PNG를 저장한다.

각 작업에는 30분/15분 제한을 둔다. 테스트 결과·합성 근거와 스크린샷·Windows 패키지 artifact는 3일 보관한다. 실패해도 가능한 보고서를 업로드하며 빨간 작업을 성공으로 표시하지 않는다. 반복 실행의 서로 다른 보고서는 GitHub run ID로 구별한다.

Windows Server 러너의 실행 성공은 실제 Windows 11·GPU 없는 평가 PC·30분 사이트 점검·사용자 GUI의 실제 키 교체 성공이 아니다. 합성 transport를 생산 앱의 오프라인 분류기로 제공하지 않으며 실사이트 OCR/CLEF 정확도를 측정했다고 주장하지 않는다.

## 2026-10-05 실제 실행 결과

[실행 37298661138](https://github.com/hoddukzoa12/AI-detector/actions/runs/37298661138)은 코드 커밋 `407896d7f4632bbc3a9f4ad7c29b80bbeb1bd039`에서 Linux·Windows 작업 모두 success로 완료됐다. Linux의 40파일·473단위, 4파일·14통합, 자체 점검·공식 자산 다운로드·689파일 패키징과 정적 검사가 통과했다.

실제 Windows Server 2025 러너(`win25-vs2026`, OS `10.0.26100`)에서 bundled Node `v24.19.0`·Chromium `153.0.8010.12`, Node 자체 점검, `Inspektor.exe --self-test`가 종료 0으로 통과했다. 두 자체 점검에서 DOM25건·빈 결과0건·이미지20소유자/39발생·메뉴22음성/주변5양성의 근거를 확인했다. 실제 EXE 창에서 화면·키 미설정 시 시작 거부·OCR/동의 기본 꺼짐·sandbox/context isolation·Node integration off·GPU 가속 off를 검사했고 창 닫기가 종료 0으로 완료됐다. 이번 실행의 실제 OCR/CLEF 요청은 0회다.

첫 [실행 37296189058](https://github.com/hoddukzoa12/AI-detector/actions/runs/37296189058)은 Node 자체 점검 후 EXE 자체 점검에서 180초 시간 초과로 실패했다. Electron ESM 진입 파일의 최상위 `await app.whenReady()`가 모듈 평가와 준비 이벤트를 서로 기다리게 했다. 준비 이벤트 이후 콜백으로 시작하도록 수정했고 두 회귀 검사의 수정 전 실패·수정 후 통과와 위 Windows 재실행 성공을 확인했다. 최초 실패 기록은 보존한다.

완료 코드 커밋과 이후 문서 갱신 커밋은 구별한다. [영구 검증 요약](verification/windows-actions-2026-10-05.json)에 run·job·코드 SHA·artifact 해시·미검증 범위를 기록했고 [실제 GUI 캡처](verification/windows-gui-2026-10-05.png)를 보존했다. 전체 ZIP과 합성 실행 근거는 위 Actions의 artifacts에서 3일간 내려받을 수 있다.
