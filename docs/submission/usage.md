# 사용설명서

## 첫 장: 실행과 저장 위치

| 실행 방식 | 기본 결과 저장 위치 | 설정 파일 |
|---|---|---|
| npm | 앱을 실행한 작업 폴더의 `output/` | 작업 폴더의 `.env` |
| Docker Compose | 컨테이너 `/app/output`, 호스트 `apps/inspector/output/` | 호스트 앱 폴더의 `.env` |
| Windows ZIP | 실제 `Inspektor.exe`가 있는 폴더 | 같은 폴더의 `.env` |

`INSPECTOR_OUTPUT_DIR`를 절대 경로로 지정하면 위치를 바꿉니다. 화면에서 실제 경로를 확인하세요. Docker에서는 volume·쓰기 권한도 함께 바꾸며 Windows ZIP은 쓰기 가능한 폴더에 완전히 풉니다.

여섯 JSON은 `result.json`(네 은닉 유형 확정), `result_extra.json`(이미지 광고 확정), `scan-status.json`(상태·미완료·해시), `review.json`(검토), `finding-details.json`(판정 상세), `ocr.json`(이미지·추출 기록)입니다. `runs/<runId>/`에는 이전 실행·DOM 근거·원본 이미지·분석 PNG가 보존됩니다. 화면 다운로드는 저장본의 추가 복사입니다. `latest.json`으로 최신 실행을 구별하세요.

## 점검 순서

1. 아래 방법으로 키를 설정하고 앱을 시작합니다. 공개 HTTP(S) URL 하나를 입력합니다. 계정·암호가 들어 있는 URL은 허용하지 않습니다.
2. 필수 CLEF의 후보 글자·관련 링크 전송 안내에 동의합니다. 동의·키가 없으면 시작할 수 없습니다.
3. 이미지 글자도 점검하려면 OCR을 켭니다. 기본 꺼짐이며 켜면 포함 이미지의 정적 PNG가 Gemini로 전송됩니다.
4. 상태·페이지·실제 요청 수·공식/이미지/검토 건수·미점검 범위를 확인합니다. 행을 열어 원문·유형·전체 iframe 위치·근거·CLEF 확률을 확인합니다.
5. 이미지 행에서는 PNG·추출 글자·읽기 상태·관련 링크·원본/PNG 해시를 확인합니다. 두 결과와 상태·검토·OCR 기록을 함께 보관합니다.

같은 hostname 공개 페이지와 포함된 외부 iframe을 읽습니다. 외부 사이트 링크·다른 서브도메인 이동, 로그인·폼 제출·게시글 작성·삭제는 수행하지 않습니다. 포함 이미지의 외부 자산은 OCR 선택 시 읽을 수 있으나 광고 목적지를 방문하지 않습니다.

완료는 선택 범위의 처리가 끝났다는 뜻입니다. 확정 0건은 사이트 전체 광고 없음이 아닙니다. 부분 완료·실패·중단에도 확인된 결과와 남은 범위를 보존합니다. 저장 오류는 따로 표시하며 중단 후 확정 결과는 늘어나지 않습니다.

## 모델과 키 교체

`inspector.env.example`을 복사해 `.env`를 만들고 본인의 키를 입력합니다. 기존 `.env`가 있으면 복사로 덮어쓰지 마세요.

```dotenv
OPENROUTER_API_KEY=발급받은_키
```

완전히 종료·재시작하면 적용되며 재빌드는 필요 없습니다. OS 환경변수가 `.env`보다 우선합니다. 키는 Node만 사용하고 화면·결과·로그·제출 ZIP에 넣지 않습니다.

OCR은 OpenRouter `google/gemini-3.8-flash`의 고정 Chat Completions endpoint에서 글자만 추출합니다. 분류는 `cloudflare/clef`의 고정 Decisions endpoint에서 원문·정규화 글자·가장 가까운 소유 링크로 수행합니다. HTML·쿠키·전체 방문 기록을 보내지 않습니다. 다른 모델·로컬 OCR·로컬 광고 판정으로 자동 대체하지 않습니다.

CLEF의 최고 확률 선택이 illegal_ad이고 확률 0.8 이상이면 확정합니다. 일반 광고·비광고를 충분히 확신하면 제외하고 불확실·오류·미완료는 검토에 남깁니다. 일부 양성 뒤 다른 조각이 미완료면 확정과 검토가 함께 있을 수 있습니다.

## 이미지 범위와 한도

img·CSS 배경·before/after URL 이미지의 일반·숨김 배너를 지원합니다. 움직이는 이미지는 첫 프레임만 읽습니다. 캔버스·영상·CSS 도형·나머지 프레임·아직 선택되지 않은 lazy 이미지는 검사하지 않았습니다. 글자 없는 그림 광고와 복잡한 배너는 놓칠 수 있습니다.

OCR 미선택·글자 없음·부분 읽기·읽기 불가·API 오류·미처리는 별개입니다. 글자 없음도 비광고 확정이 아니며 검토로 남습니다. 부분 읽기·읽기 불가는 미완료로 표시합니다. 숫자 OCR 신뢰도는 제공하지 않습니다.

기본 500페이지·28분, OCR 100요청·CLEF 1,000요청(재시도 포함), 원본/PNG 각각 8MiB·16백만 픽셀입니다. `.env`의 `INSPECTOR_MAX_OCR_REQUESTS`, `INSPECTOR_MAX_CLEF_REQUESTS`, `INSPECTOR_MAX_IMAGE_BYTES`, `INSPECTOR_MAX_IMAGE_PIXELS`를 1 이상의 안전한 정수로 설정하고 재시작하면 한도를 바꿀 수 있습니다. 한도 초과는 확인 결과와 남은 작업을 보존합니다. 요청 한도는 달러 비용 보장이 아니며 사용량을 받지 못하면 비용 미확정입니다.

## Windows 실행 및 자체 점검

ZIP을 풀고 `Inspektor.exe`를 실행합니다. 별도 Node·Docker·Python·GPU·모델 설치가 필요 없는 구성입니다. 창을 닫으면 중단·저장을 기다립니다. 실제 Windows 실행은 아직 미검증입니다.

```powershell
$inspection = Start-Process -FilePath '.\Inspektor.exe' -ArgumentList '--self-test' -Wait -PassThru
$inspection.ExitCode
```

앱이 이미 실행 중이면 종료 코드 2, 실제 검사가 성공하면 0, 오류면 1입니다. `self-test/<고유ID>/self-test-report.json`을 확인하세요. 모의 OCR/CLEF로 생산 경로·합성 정답을 검사하고 외부 요청이나 기존 결과 덮어쓰기를 하지 않습니다. 실제 모델 정확도와 Windows GUI 동작은 별도입니다.

근거에는 공개 개인정보가 남을 수 있습니다. 보관 기간·접근 권한은 운영자가 정하며 자동 삭제·외부 신고는 제공하지 않습니다. 판정과 해시는 관리자 검토·파일 무결성을 돕는 값이며 법적 위반 확정이나 인증이 아닙니다.
