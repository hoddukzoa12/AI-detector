# 공개 웹사이트 점검 앱

독립 npm 패키지에서 core 계약을 수집·탐지·AI·저장·HTTP·화면이 공유한다. 기존 Flutter·확장 소비자 데이터와 실행 경로는 이 앱의 소유 범위가 아니다. 공통 package/lock/build/최상위 엔트리를 바꿀 때 production 배포 allowlist와 고지를 함께 확인한다.

원문과 복원문, top-page URL과 실제 frameUrl, 확정·검토·미완료를 구별한다. 전체 element.location에 프레임 경로를 재부착하지 않는다. CLEF는 필수며 Node에서 동의한 후보 글자·소유 링크를 전송한다. 선택 OCR은 등록 PNG의 글자를 추출하며 로컬 광고 규칙으로 대신 판정하지 않는다. Node는 키를 반환/기록하지 않는다. HTML을 renderer에서 실행하지 않는다.

코드 변경은 typecheck·lint·test·build·test:e2e·self-test를 통과시킨다. 배포 변경은 test:docker·package:win·verify:win과 ZIP 검사를 추가한다. actual Windows GUI/실API 추론 없이 해당 성공을 주장하지 않는다. 자체 점검은 별도 self-test 경로에 보존하고 사용자의 .env·기존 결과는 덮어쓰지 않는다.
