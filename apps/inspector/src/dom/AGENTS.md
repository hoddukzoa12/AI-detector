# DOM 원문과 위치 관측

브라우저 문서의 직접 텍스트 소유 요소·img/CSS/pseudo 발생·계산 스타일·프레임 위치를 읽는다. 광고 판정·큐·AI·저장은 소유하지 않는다.

HTML·rawText를 분석 전에 바꾸지 않는다. 수집한 요소 location과 조상 style 위치는 top-page부터의 전체 프레임 경로다. 저장용 EvidenceSnapshot의 style 위치는 application이 해당 프레임 기준으로 변환한다. 상대 src를 baseURI로 비교하되 실제 속성을 바꾸지 않는다.

rawText는 소유 요소의 직접 TEXT_NODE 값을 DOM 순서로 합친다. 자손 textContent를 부모 원문에 섞지 않고 직접 글자가 없는 집계 부모는 별도 원문 요소로 만들지 않는다. 부모·자식의 같은 문구가 각각 직접 글자이면 둘 다 보존한다.

실제 Chromium에서 같은 src/중첩/srcdoc/외부 프레임의 유일성과 원문·조상 스타일, 수집 전후 DOM 일치를 검사한다.

이미지 숨김 관측은 실제 owner/조상 스타일과 문서·viewport 좌표를 구별한다. fixed 기준을 만드는 CSS·완전 clip·정상 스크롤·부분 clip·이미지의 작은 font-size를 실제 Chromium 반례로 검사한다. pseudo의 margin/padding/border나 transform이 있는 경우 offset만으로 숨김을 확정하지 않는다. 브라우저로 직렬화하는 캡처 함수는 외부 closure/import에 의존하지 않으며 수집 전후 DOM·owner bounds를 보존한다.
