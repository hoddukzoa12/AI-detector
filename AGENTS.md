# 공공 웹사이트 불법광고 탐지 도구

이 저장소는 공공 웹사이트 관리자가 공개 페이지의 은닉 텍스트와 일반·숨김 이미지 광고를 점검하는 로컬 도구다. apps/inspector의 TypeScript·Playwright 코어를 npm/Docker 웹 화면과 Electron Windows 패키지에서 공유한다. 실제 Windows 11 실행·대표 OCR/CLEF 정확도·전체 배포 권리는 별도 확인이 필요하다.

## 프로젝트 구조

```text
AI-detector/
├── AGENTS.md                         ← 프로젝트 목적과 작업 지침
├── CLAUDE.md                         ← 동일한 프로젝트 지침
├── docs/
│   ├── architecture.md               ← 점검 코어와 실행 경로의 연결
│   ├── business-rules.md             ← 공개 페이지 점검·광고 판정·원문 보존 규칙
│   ├── security.md                   ← 읽기 범위·필수 CLEF/선택 OCR 전송·키 처리 정책
│   ├── standards.md                  ← 변경 경계와 산출물 검증 규칙
│   ├── engineering-notes.md          ← 원문·프레임·취소·배포의 실제 함정
│   ├── operations.md                 ← npm·Docker·Windows 실행 절차
│   ├── contracts.md                  ← 진입 URL·result.json·추가 결과 규격
│   ├── submission/
│   │   ├── usage.md                  ← 사용자 실행·출력·키 교체
│   │   ├── build.md                  ← 설치·빌드·소스 재현
│   │   ├── verification.md           ← 실제 검사와 남은 조건
│   │   ├── proposal.md               ← 8쪽 기획서 원본
│   │   └── licenses.md               ← 출처·고지·미확정 권리
│   └── tracking/
│       ├── status.md                 ← 구현·실제 검사와 남은 조건
│       ├── findings.md               ← 현재 해결하지 않은 문제
│       └── decisions/
│           ├── index.md              ← 기존 이력과 확인된 새 결정 목록
│           └── NNNN-*.md             ← 대안과 결과를 기록한 결정
├── apps/
│   ├── inspector/
│   │   ├── AGENTS.md                 ← 독립 점검 앱의 변경 경계
│   │   ├── scripts/AGENTS.md         ← 배포·자체 점검·독립 검증
│   │   └── src/
│   │       ├── core/AGENTS.md                    ← 계약과 실행 상태
│   │       ├── dom/AGENTS.md                     ← DOM 원문과 위치 관측
│   │       ├── crawler/AGENTS.md                 ← 공개 페이지 수집
│   │       ├── detection/AGENTS.md               ← 은닉 관측과 소유 후보 연결
│   │       ├── ocr/AGENTS.md                     ← Gemini 이미지 글자 추출
│   │       ├── classification/AGENTS.md          ← CLEF 분류
│   │       ├── output/AGENTS.md                  ← 실행별 파일 보존
│   │       ├── application/AGENTS.md             ← 점검 실행 제어
│   │       ├── server/AGENTS.md                  ← 로컬 HTTP 경계
│   │       ├── web/AGENTS.md                     ← 점검 화면
│   │       └── desktop/AGENTS.md                 ← Electron 로컬 실행
│   └── browser/
│       ├── AGENTS.md                 ← 기존 Flutter 기반의 재사용 경계
│       └── mcp/AGENTS.md             ← 디버그 앱 자동화 통로
├── extensions/
│   └── chrome/
│       ├── AGENTS.md                 ← 기존 MV3·DOM 코드의 경계
│       ├── introduce/AGENTS.md       ← 기존 소비자 제품의 정적 콘텐츠
│       └── packages/
│           ├── AGENTS.md             ← 순수 도메인 패키지의 공통 빌드 조건
│           ├── infocutter-selector-rules/AGENTS.md ← 선택자·규칙 모델
│           ├── infocutter-text-blocks/AGENTS.md    ← 기존 텍스트 차단 모델
│           ├── infocutter-watch/AGENTS.md          ← 기존 이름 감시 모델
│           └── infocutter-filter-importer/AGENTS.md ← 기존 필터 해석
└── packages/
    ├── ext-build/AGENTS.md            ← 확장 빌드 도구
    └── ext-runtime/AGENTS.md          ← 현재 소비자가 없는 공통 런타임
```

## 반드시 지킬 것

1. 입력 사이트의 공개 페이지와 포함 iframe을 읽는다. 외부 광고 링크 추적, 로그인, 사이트의 작성·수정·삭제는 하지 않는다.
2. 후보를 수집하기 전에 기존 마스킹·차단·페이지 변경을 적용하지 않는다. 분석용 정규화 값과 원문 근거를 구분한다.
3. 결과는 요소 위치와 은닉 유형까지 검증한다. 검출 0건, 실패, 부분 완료를 구분하고 오류를 정상 완료로 표시하지 않는다.
4. 광고 문맥은 CLEF만 판정하며 키와 텍스트·소유 링크 전송 동의가 필수다. 선택 OCR은 PNG를 전송하고 기본 꺼짐이다. HTML·쿠키는 모델에 보내지 않는다. 실행 키는 소스·제출 파일·로그에 넣지 않는다.
5. 실제 GPU 없는 Windows 11 실행과 규격 파일 생성을 확인하지 않고 제출 준비가 완료되었다고 주장하지 않는다.

## 작업 전 확인

기본으로 `docs/standards.md`, `docs/engineering-notes.md`와 변경할 모듈의 AGENTS.md를 읽는다. 수집·유형 판정은 `docs/business-rules.md`, 파일 작성은 `docs/contracts.md`, 외부 전송·키·Electron 실행·세션 토큰은 `docs/security.md`를 먼저 확인한다. 기존 저장소를 바꿀 때 이전 입력의 데이터 보존을 확인한다. Windows 재사용·배포를 결정할 때 `docs/tracking/status.md`의 미검증 사항을 확인한다.

## 문제 처리

점검 범위 밖의 로그인·사이트 변경, 원문 보존 전 마스킹, API 키·쿠키의 결과 포함, 실패를 검출 0건으로 처리, 유일하지 않은 위치를 정답으로 출력, 릴리스의 디버그 통로 노출은 즉시 사용자에게 알린다. 나머지 해결되지 않은 문제는 `docs/tracking/findings.md`에 조건·영향·이번 작업에서 해결하지 않은 이유를 기록한다.
