# 공개 페이지 수집

공개 방문 큐·읽기 요청 정책·Playwright 생명주기를 맡고 dom 관측과 선택 이미지 원본/정적 PNG를 반환한다. 같은 소유자의 가장 가까운 anchor만 관련 링크이며 형제 링크·집계 문맥을 상속하지 않는다. 이미지 발생 메타데이터를 확보 전에 보존하고 개별 실패와 실제 치명 종료를 구별한다. 광고 판정·외부 AI·파일/UI는 소유하지 않는다.

방문은 같은 hostname과 실제 쿼리를 보존하며 외부 iframe을 읽어도 그 링크로 큐를 확장하지 않는다. 새 컨텍스트에서 비읽기 요청·로그인·popup을 제외한다. stop은 Browser.close의 한 promise를 공유하고 launch 전 완료값을 캐시하지 않는다.

실제 fixture의 외부 redirect/쓰기/로그인·자원/시간 상한·대기 callback·page 생성 중 취소·SIGTERM·잔류 Chromium을 검사한다.
