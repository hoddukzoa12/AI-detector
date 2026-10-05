# 0008. OpenRouter의 CLEF로 선택적 광고 문맥 분류

- 날짜: 2026-10-04
- 상태: 연동 구현·모의 계약·실CLEF 합성 4건 검증, 정확도·실키 교체는 별도; 선택 AI·로컬 판정은 [0012](0012-external-ocr-clef-only.md)로 대체

## 배경

네 은닉 기법과 정확한 요소 위치는 DOM 분석으로 계산해야 한다. 숨겨진 문구가 실제 불법광고인지 일반 광고·기사·공공 안내인지 구분하는 보조 분류기가 필요하다. CLEF는 선택지별 확률을 반환하지만 공개 27B 가중치 약 55GB를 GPU 없는 제출 PC에 넣는 방식의 성능은 검증되지 않았다.

## 결정

사용자가 지정한 OpenRouter의 `cloudflare/clef`를 선택적 외부 분류 서비스로 사용한다. `POST https://openrouter.ai/api/alpha/decisions`에 `model`, `state`, `questions`를 보내고 `answers`의 타입·선택지·확률을 검증한다. 일반 채팅 API의 자유 형식 응답 파서를 그대로 사용하지 않는다. 실행 시 외부 설정의 `OPENROUTER_API_KEY`를 읽고 재빌드 없이 키를 교체한다.

사용자가 설정하고 전송을 선택한 후보 텍스트·링크만 보낸다. 이미지 지원을 이유로 스크린샷·전체 HTML·쿠키 전송을 추가하지 않는다. 원문·위치·기법은 로컬 수집 자료를 유지하며 모델이 이를 새로 만들어 제출하지 않는다. AI를 사용하지 않아도 로컬 점검 경로를 제공한다.

## 대안

- Cloudflare Workers AI 직접 호출: 서비스 자체는 제공되지만 사용자 지정은 OpenRouter다. 제출 설정에 Cloudflare 계정 ID를 추가하지 않는다.
- 공개 가중치 자체 운영: 자체 추론 환경의 실행 가능성·가용성·비용 검증이 필요하고 현재 채택하지 않았다.
- CLEF-Flash: 별도 9B 모델이며 명시적으로 지정된 CLEF를 임의로 대체하지 않는다.

## 결과

OpenRouter 모델 페이지는 긴 state를 현재 약 첫 2,000토큰으로 잘라 처리한다고 안내한다. 표시된 65,536토큰 컨텍스트만 믿고 페이지 전체를 보내지 않고 후보를 나누어 처리한다. 한국어 합성 4건의 실제 모델 호출은 모두 HTTP200·응답 검증을 통과했고 총 지연 228~826ms를 기록했다. 대표성 있는 광고·기사·안내 라벨 사례의 정확도·임계값, 운영망 오류와 실제 두 키 교체는 추가 검증이 필요하다. 모의 계약 검사와 작은 실제 연결 표본을 전체 정확도로 표현하지 않는다.

출처: https://openrouter.ai/cloudflare/clef
API 규격: https://openrouter.ai/docs/api/api-reference/alphadecisions/submit-a-decisions-request

가중치 규모 출처: https://huggingface.co/api/models/Cloudflare/clef (`usedStorage` 약 55GB, BF16 약 273.6억 파라미터).
