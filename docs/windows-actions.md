# Windows Actions 실행 검증

워크플로는 `.github/workflows/windows-test.yml`이며 main push·pull request·수동 실행에 반응한다. GitHub 표준 Ubuntu 24.04와 Windows Server 2025 러너를 사용한다. 저장소 contents 읽기 권한만 요청하고 외부 API 키·사용자 파일·유료 OCR/CLEF 요청을 사용하지 않는다.

Linux 작업은 고정 Node 24.19.0으로 잠금 파일 설치, Chromium 설치, typecheck·lint·build·단위·통합·자체 점검, Windows 패키징과 정적 검사를 순서대로 수행한다. 공식 자산 HTTPS checksum·고지·파일 해시 검증을 유지하며 로컬의 임시 캐시 재사용 도구를 CI로 가져오지 않는다. 다운로드 실패는 실패로 기록한다.

Windows 작업은 생성 ZIP의 SHA256를 대조하고 압축을 푼 뒤 전체 패키지 파일을 검증한다. `scripts/windows-runner-check.mjs`가 bundled node.exe와 Chromium으로 자체 점검을 실행하고, 실제 Inspektor.exe의 --self-test를 실행한다. 각 보고서의 win32·desktop·합성 transport·DOM25·이미지20소유자/39발생·메뉴22음성 근거를 확인한다. 실제 EXE GUI를 열어 로컬 화면·키 미설정·OCR 기본 꺼짐·전송 동의·sandbox·context isolation·Node integration off·GPU 가속 off와 정상 종료를 확인하고 PNG를 저장한다.

각 작업에는 30분/15분 제한을 둔다. 테스트 결과·합성 근거와 스크린샷·Windows 패키지 artifact는 3일 보관한다. 실패해도 가능한 보고서를 업로드하며 빨간 작업을 성공으로 표시하지 않는다. 반복 실행의 서로 다른 보고서는 GitHub run ID로 구별한다.

Windows Server 러너의 실행 성공은 실제 Windows 11·GPU 없는 평가 PC·30분 사이트 점검·사용자 GUI의 실제 키 교체 성공이 아니다. 합성 transport를 생산 앱의 오프라인 분류기로 제공하지 않으며 실사이트 OCR/CLEF 정확도를 측정했다고 주장하지 않는다. 실제 실행 결과는 Actions run URL과 완료 commit·conclusion·artifact 보고서로 기록한다. 첫 CI 결과는 아직 확인 전이다.
