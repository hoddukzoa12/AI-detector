# 빌드·배포와 독립 검증

build·Windows 패키지·Docker smoke·자체 점검·기획서 PDF를 맡는다. 생산 탐지 알고리즘·업무 정책·외부 업로드를 구현하지 않는다. 패키지는 audited runtime allowlist와 production 전용 설치를 사용하며 개인 .env·출력·Git·공유 node_modules를 복사하지 않는다.

Playwright/Chromium·Electron·Node pin과 HTTPS checksum·전체 PE/파일해시·필수 자산·고지를 함께 확인한다. self-test와 map은 필수이며 누락을 optional 성공으로 바꾸지 않는다. matching Windows pak의 전체 credits를 추출하고 provenance를 보존한다. 정적 검사 성공은 Windows 실행 성공이 아니다.

verification helper에는 CLI 실행 부작용을 두지 않는다. 합성 정답과 공식 결과 validator는 생산 detector/validator를 복사하지 않는다. Docker 실제 서버/UI와 bind 파일 바이트·해시를 검사하고 합성 폴더 외의 권한은 완화하지 않는다. 자체 점검은 기존 결과·latest·runs를 보존하는 고유 self-test 경로를 사용한다.

배포 변경은 package:win·verify:win·ZIP 무결성·test:docker·실제 CLI를 확인한다. 기획서 PDF는 전체 저장소 원본과 한글 글꼴을 필요로 하며 인쇄 영역 overflow와 5~10쪽 조건을 확인한다. 실제 Windows·실CLEF 미수행은 보고서에 명시한다.
