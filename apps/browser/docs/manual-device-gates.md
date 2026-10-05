# 실기기 게이트 — #14 · #21/#12

AWO/CI 시뮬만으로는 닫을 수 없는 항목. 사람 또는 실기기 세션이 필요하다.

일일 스모크 표: [device-smoke-checklist.md](./device-smoke-checklist.md)

코드 쪽 준비: JS `alert`/`confirm`/`prompt` 다이얼로그, Android `onShowFileChooser`,
`GEOLOCATION` → OS 위치 권한 매핑, 메뉴 **읽기 모드**. 실기기 증거 없이 done 금지.

## #14 웹 호환성 매트릭스

| 기능 | 시뮬 추정 | 실기기 필수 | 확인 방법 |
|---|---|---|---|
| 파일 업로드 (`input type=file`) | 부분 | 예 | 테스트 HTML 페이지에서 사진 선택 |
| 전체화면 비디오 | 부분 | 예 | YouTube 전체화면 진입·종료 |
| Geolocation | 권한 다이얼로그만 | 예 | maps 사이트 위치 허용 |
| JS alert/confirm/prompt | 플러그인 기본 | 예 | 테스트 페이지 다이얼로그 |
| 카메라·마이크 getUserMedia | 시뮬 제한 | 예 | meet/webrtc 샘플 |

**닫는 조건**: 위 5행 모두 실기기 pass 또는 실패 시 재현 이슈로 쪼갬.

## #21 Google 로그인 실기기

| 단계 | 시뮬(2026-08-04) | 실기기 |
|---|---|---|
| 로그인 페이지 렌더 | OK (차단 문구 없음) | 미확인 |
| 자격 제출 이후 | 미확인 | **필수** |
| `X-Requested-With` | 나감 (`com.dalsoop.infocutter`) | 동일 예상 |
| `Sec-CH-UA` | Android WebView 광고 | 숨길 수 없음 |

**닫는 조건**: 실기기에서 1회 로그인 성공/실패를 증거(스크린샷·네트워크 헤더)로 남기고 #12 B/C/D 방향 결정.

## 에이전트 할 일 (코드)

- #14: 핸들러 미등록이면 등록(파일 선택·JS 다이얼로그 콜백). 동작 증명은 사람.
- #21: 인증 origin 배제·배너는 코드에 있음. 추가 우회 시도 금지(UA 위장 정책).

Backlog: `fec06672` (#14), `f2064095` (#21/#12) — 상태 planned 유지, 실기기 전 done 금지.
