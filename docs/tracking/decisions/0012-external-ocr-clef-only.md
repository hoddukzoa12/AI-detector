# 0012. 외부 Gemini OCR과 필수 CLEF로 광고 분류 통일

- 날짜: 2026-10-05
- 상태: 사용자 확인·구현·Linux 실행/정적 패키지·소형 실모델 평가 완료. 실제 사이트/Windows·전체 권리는 별도

## 배경

toonkor의 일반 이미지 배너 글자는 직접 DOM 원문에 없었다. 기존 로컬 판정은 부모 메뉴 광고 링크를 제목에 적용해22오탐을 냈다. 사용자는 이미지 광고도 구분해 점검하고 OpenRouter 최신 OCR을 사용하며 로컬 광고 규칙을 없애고 CLEF로 통일하자고 요청했다.

## 결정

OpenRouter google/gemini-3.8-flash가 등록 PNG 한 프레임의 글자·읽기 상태를 추출하고 cloudflare/clef Decisions가 읽힌 원문·정규화 글자·소유 링크를 분류한다. 키와 CLEF 전송 동의는 시작에 필수, OCR은 기본 꺼짐이다. 로컬 광고 판정·오프라인 제품 경로·실패 fallback은 제거한다. DOM의 네 은닉 관측·문자 복원·위치·실바이트 근거는 유지한다.

일반·숨김 이미지 탐지는 result_extra.json의 ETC·IMAGE_AD_OCR로 분리한다. 공식 result.json은 네 유형·직접 DOM 원문이다. OCR 부분/무문자/읽기 불가·CLEF 불확실·오류는 서로 구별해 검토/미완료로 남긴다. 같은 PNG 추출 캐시와 소유자별 분류를 분리하고 형제 링크·집계 부모 글자는 상속하지 않는다.

## 검토한 대안

- 로컬 한국어/영어 OCR: 전송·API 비용은 줄지만 가중치·런타임·Windows 자산 검증과 복잡한 배너 품질 관리가 추가된다. 사용자가 외부 모델로 변경했다.
- 로컬 규칙과 CLEF 병행: 키 없이 실행 가능하지만 서로 다른 판정과 fallback 오탐이 남는다. 사용자가 CLEF 단일 판정을 선택했다.
- OCR 모델로 광고까지 분류: 글자 추출 실패와 광고 판단을 구분하기 어려워 역할을 분리했다.

## 결과와 이전 결정

네트워크·OpenRouter 키/잔액이 제품 점검에 필수이며 요청 제한은 비용 보장이 아니다. 새 OCR 가중치·Python·GPU·추가 제공자 키는 배포하지 않는다. 합성 소형 평가의 OCR 8·CLEF 10 HTTP200·문자 차이 0·분류 선택9/10은 연결/표본 측정이며 대표 정확도·Windows 실행은 아니다. 모의 자체 점검은 외부 요청 없이 생산 경로를 검사한다.

[0007 외부 AI 선택](0007-optional-ai-transfer.md), [0008 선택 CLEF](0008-openrouter-clef.md), [0011 AI 사용 시 확정](0011-clef-confirmation-policy.md)의 선택 AI·로컬 판정 부분을 대체한다. [0005 공모전 전환](0005-contest-only-scope.md)의 플랫폼/소비자 분리 목적은 유지한다. 과거 결정과 실사이트 기록은 삭제하지 않는다.

공개 모델 메타데이터 조사에서 Gemini3.8 Flash는2026-09-02 등록·이미지/구조화 출력 지원으로 확인했다. 모델/문서 HTML은403이었고 이후 실제 소형 요청으로 연결을 측정했다. 최신이라는 표현은 조사 시점에 한정한다.

출처: https://openrouter.ai/api/v1/models · https://openrouter.ai/google/gemini-3.8-flash · https://openrouter.ai/cloudflare/clef
