# 0009. 웹 화면·Playwright 코어와 Electron Windows 배포

- 날짜: 2026-10-04
- 상태: 구현·Linux 검증, 실제 Windows·운영 API 평가 조건은 별도

## 배경

현재 개발 환경에서 npm·Docker로 점검 기능을 실행·확인하면서, 공모전의 Windows 실행 파일도 준비해야 한다. 기존 Flutter 전체 개조는 현재 Windows 빌드 검증 없이 진행할 수 없으며 TypeScript의 DOM 처리 코드를 활용할 별도 실행 기반이 필요하다.

## 결정

웹 화면과 Playwright 수집기를 분리한다. npm과 Docker에서는 웹 화면으로 점검 코어를 사용하고, Windows에서는 Electron으로 같은 기능을 패키징한다. 수집·탐지·파일 출력 코어를 Windows와 Docker용으로 각각 새로 작성하지 않는다. Windows 패키지는 Node 런타임과 Playwright 브라우저 등 실행에 필요한 의존 파일을 포함한다.

## 대안

- Electron과 내장 브라우저 중심의 단일 앱: 화면과 브라우저를 묶을 수 있지만 Docker의 웹 실행·헤드리스 점검과 실행 경로가 달라진다.
- 기존 Flutter 앱 개조: 기존 화면·저장 구현을 활용할 수 있지만 사용자는 npm 기반 개발로 전환했다.

## 결과

새 점검 화면과 로컬 세션 HTTP 인터페이스를 구현했다. npm·Docker 실행 성공은 Windows 실행 검증이 아니며, 현재 Windows 테스트 환경은 없다. 패키지 생성과 GPU 없는 Windows 11 실행 확인을 구분해서 기록해야 한다.
