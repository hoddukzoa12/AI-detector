# Electron 로컬 실행

actual exe 기준 설정·루프백 서버·renderer 정책·창 닫기·자체 점검 child를 맡는다. 새 분류/저장 코어·IPC 파일/명령 API·기존 Flutter 브리지를 만들지 않는다.

nodeIntegration off/contextIsolation/sandbox를 유지하고 외부 navigation/popup/권한을 막는다. 안전한 blob JSON 다운로드만 허용한다. --self-test는 bundled Node·실제 GUI exe·bundled Chromium 경로를 전달하고 exit를 보존한다. close는 중단/저장을 기다린다.

정책 단위 검사·패키지 필수 자산/해시를 수행한다. 실제 Windows GUI·키 재시작·단일 instance/exit2·GPU없는 PC·자체 점검은 Windows에서 별도 확인한다.
