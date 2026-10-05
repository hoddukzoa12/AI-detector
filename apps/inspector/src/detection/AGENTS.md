# 은닉 관측과 CLEF 후보

core 수집 자료에서 네 은닉 기법을 순수하게 관측하고 readable OCR을 소유 요소 단위로 묶는다. 광고 문맥은 CLEF만 판정하며 localDecision과 광고 ruleIds를 만들지 않는다. 브라우저·API·저장·UI·실행 상태는 소유하지 않는다.

원문을 정규화 값으로 덮어쓰지 않는다. element.location에 framePath를 다시 붙이지 않는다. 같은 요소·기법은 한 건이며 복수 기법은 별도 결과다. 기법이 관측된 모든 직접 텍스트 후보를 CLEF에 넘긴다. 관측 진단은 observationIds에 보존한다.

rawText는 직접 TEXT_NODE 원문이다. 조상 관계와 같은 문구만으로 부모 원문을 자식 집계라고 추측해 삭제하지 않는다. 숨긴 부모·보이는 자식의 같은 문구와 독립 형제, 직접 원문 없는 집계 부모, 같은 위치 반복 수집을 실제 DOM 자료로 대조한다.

기사·교육 자모·숫자·접근성·일반 스크롤 아래 반례와 조상 효과·복수 기법, actual crawler→detector의 전체 iframe 정답을 검사한다.
