# 입력과 결과 파일 규격

## 공모전용 인터페이스

apps/inspector가 생성하는 계약이며 기존 브라우저·확장의 규칙 파일과 별개다. 입력은 테스트 웹사이트의 진입 URL 하나다. 화면에서 결과를 확인할 수 있어야 하고, 화면과 별도로 필수 네 유형의 `result.json`을 생성해야 한다.

파일은 UTF-8(BOM 없음) JSON이다. Windows 기본 위치는 실제 exe 폴더, npm은 작업 폴더 output, Docker는 /app/output이다. INSPECTOR_OUTPUT_DIR override는 화면에 실제 경로로 표시한다. 최상위 키는 `meta`와 `findings`다. 결과가 없어도 `findings`를 빈 배열로 포함한다. 모든 페이지의 결과는 한 배열에 담고 페이지별 배열을 만들지 않는다.

| 실행 정보 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `meta.topic` | string | 예 | `TOPIC` |
| `meta.entry_url` | string | 예 | 입력한 진입 URL |
| `meta.started_at` | string | 예 | 입력·탐지 시작 시각, ISO 8601 |
| `meta.finished_at` | string | 예 | 완료 시각, ISO 8601 |
| `meta.elapsed_sec` | number | 예 | 시작부터 완료까지의 초 |
| `meta.tool_version` | string | 아니오 | 제출 버전 |
| `findings` | array | 예 | 검출 항목 목록 |

| 검출 항목 | 타입 | 필수 | 의미 |
|---|---|---|---|
| `id` | string | 예 | 파일 안에서 중복되지 않는 식별자 |
| `url` | string | 예 | 검출 항목이 존재하는 페이지의 전체 URL |
| `is_violation` | boolean | 예 | 위반 여부 |
| `location` | string | 예 | 검출 요소를 정확히 특정하는 CSS 선택자·프레임 경로 |
| `evidence_text` | string | 예 | 정규화 전 원문 근거 |
| `technique` | string | 예 | 아래 유형 코드 중 하나 |

meta 문자열은 비어 있지 않고 시각은 ISO 8601이며 elapsed_sec는 유한한 0 이상 숫자다. 확정 findings의 is_violation은 true만 출력한다.

유형 코드는 `HOMOGLYPH`, `JAMO`, `TRANSPARENT`, `OFFSCREEN`이다. `technique`에 배열이나 여러 코드를 넣지 않는다. 같은 요소에 두 기법이 있으면 별도 항목으로 출력한다. 중복 판정 단위는 URL + 위치 + 기법이다.

위치는 태그·클래스를 조합하고 필요할 때 nth-of-type 등으로 유일한 요소를 특정한다. 중첩 iframe은 `iframe[src="주소"] >>> 내부 선택자` 형식을 반복하며 구분 기호 앞뒤에 공백 한 칸을 둔다. 상대 iframe src는 절대 주소로 적는다. 최종 경로가 여러 요소를 가리키면 위치 정답으로 인정되지 않는다. 원문 근거는 정규화·자모 복원된 문자열로 바꾸지 않는다.

예시:

```json
{
  "meta": {
    "topic": "TOPIC",
    "entry_url": "https://www.example.go.kr/board/list",
    "started_at": "2026-10-20T10:00:00+09:00",
    "finished_at": "2026-10-20T10:01:00+09:00",
    "elapsed_sec": 60
  },
  "findings": [
    {
      "id": "f_001",
      "url": "https://www.example.go.kr/board/view?id=1",
      "is_violation": true,
      "location": "div.article-body > span.hidden-link",
      "evidence_text": "정규화 전 원문 근거",
      "technique": "OFFSCREEN"
    }
  ]
}
```

`result_extra.json`도 매 실행 생성한다. 같은 meta·항목 구조에 `technique: "ETC"`, `extra_finding: "IMAGE_AD_OCR"`로 이미지 광고를 기록한다. 두 파일의 ID는 전체 실행에서 중복되지 않으며 OCR 미선택·확정0건도 빈 findings를 쓴다. 이미지 원문은 같은 소유자의 readable OCR 글자를 img·CSS 배경·before·after/레이어 순으로 연결한다. DOM 원문과 합치지 않는다. 필수 네 유형을 추가 파일로만 출력하거나 추가 유형을 `result.json`에 섞지 않는다.

## 채점 시 해석

정답 검출은 `url`, `location`, `technique`가 모두 정답과 맞는 경우다. 위치 문자열 자체가 달라도 같은 요소를 정확히 가리키면 인정된다. 같은 조합은 중복을 합쳐 한 건으로 집계한다. 원문 근거는 정답 판정에 사용되지 않지만 본심사 참고자료이므로 반드시 넣는다.

URL 비교 시 끝 슬래시, http/https 차이, 해시 이하를 비교하지 않는다. 쿼리 값이 다르면 다른 페이지이고, 같은 쿼리 항목의 순서만 다르면 같은 페이지다. 이 규칙은 평가 비교 규칙이며 수집기에서 서로 다른 리소스를 무조건 합치라는 명령이 아니다.

필수 필드 누락·형식 불일치 항목은 채점에서 제외된다. 파일 전체가 파싱되지 않으면 해당 회차 성능은 0점이며, 결과 파일 미생성이나 규격 미준수는 평가 제외 사유가 될 수 있다. 접근 실패·선택 OCR 또는 필수 CLEF 분석 실패·중단 시에도 확인된 탐지는 규격대로 저장하고 화면 및 별도 실행 기록에 상태와 미완료 범위를 기록한다. 평가용 JSON의 `meta`·`findings` 구조에 임의의 성공 상태나 은닉 유형을 추가하지 않는다. scan-status.json·review.json·finding-details.json으로 상태·검토·상세를 별도 제공한다.

## 신규 상태·상세·근거 계약

신규 실행의 scan-status.json·review.json·finding-details.json·ocr.json은 schemaVersion 2다. 과거 version1은 읽기 호환성으로만 보존하며 local 출처·LOCAL_UNCERTAIN을 새 실행에 만들지 않는다. 기존 archive 바이트와 해시는 다시 직렬화하지 않는다.

RunSnapshot은 runId·entryUrl·startedAt·finishedAt·elapsedSec·activeUrls를 유지한다. state는 running/stopping/completed/partial/cancelled/failed, 종료 시 finishedAt은 ISO8601·elapsedSec는 유한한0이상 값이다. aiEnabled와 externalAnalysisConsent는 true, model은 cloudflare/clef다. ocrEnabled는 boolean이고 ocrModel은 선택 시 google/gemini-3.8-flash, 미선택 시 null이다.

| 집계 | 필드: 모두0이상 정수 |
|---|---|
| counts | discoveredPages, scannedPages, failedPages, skippedPages, pendingPages, confirmedFindings, reviewCandidates, extraConfirmedFindings |
| imageCounts | discovered, captured, ocrCompleted, failed, pending, skipped |
| requestCounts | ocr, clef: 실제 HTTP 시도·재시도 포함, 완료 캐시0 |

발견 페이지는 수락한 서로 다른 사이트 내부 URL이며 iframe 수와 구별한다. 알려지지 않은 미방문 URL을 추정 집계하지 않는다. errors는 `{scope,code,url,candidateId,message}`이며 해당 없는 URL/후보는 null이다. 기존 page/frame/ai/storage/runtime/limit scope에 image/ocr를 더한다. 기존 접근·AI·저장 오류 코드와 IMAGE_FETCH_ERROR·IMAGE_DECODE_ERROR·IMAGE_UNSUPPORTED·OCR_HTTP_ERROR·OCR_RESPONSE_INVALID·OCR_TIMEOUT·OCR_UNREADABLE을 사용한다. 키·헤더·응답 원문을 message에 넣지 않는다.

scan-status.json은 `{schemaVersion:2,run,scope,files,resultSaved,extraResultSaved,imageScope}`다. scope는 `{hostname,framePolicy:"embedded",skipped:[{url,reasonCode}],unvisitedUrls}`다. files는 resultPath·reviewPath·findingDetailsPath·evidenceDir·resultSha256·extraResultPath·extraResultSha256·ocrPath이며 저장 전/실패는 null, 경로는 출력 루트 상대 경로다. 두 saved flag는 실제 등록·검증된 각 결과의 저장 여부다. imageScope는 `{enabled,framePolicy:"first",unsupportedKinds:["canvas","video","animation_remaining_frames"],pendingImageIds}`로 이미지 미완료를 페이지 미방문과 구별한다.

## 후보·CLEF 조각·상세

review.json은 `{schemaVersion:2,runId,candidates}`다. 후보는 `{candidateId,url,location,evidenceText,techniques,reason,ai,evidence,sourceType,sourceIds,sourceTextRanges}`다. DOM 후보의 sourceType은 dom_text이고 sourceIds/sourceTextRanges는 빈 배열이다. 이미지 후보는 image_ocr, sourceIds는 같은 소유자의 모든 발생ID, sourceTextRanges는 readable 글자만 연결한 `{imageId,rawStart,rawEnd}` 배열이다. 기법 배열은 DOM의 중복 없는 네 코드, 이미지에서는 빈 배열이다. url·location은 top-page 전체 소유자 경로다.

대표 검토 이유 우선순위는 AI_ERROR > OCR_ERROR > NOT_ANALYZED > OCR_UNREADABLE > UNCERTAIN > OCR_NO_TEXT다. 모든 읽기 전/미선택/읽힌 글자 없음이면 ai는 null이다. no_text는 completed 추출·검토, partial/unreadable은 읽기 미완료로도 표시한다. 실패·미처리를 비광고로 바꾸지 않는다.

ai는 `{model,summaryChunkId,choice,probabilities,confidence,chunks}` 또는 null이다. probabilities는 illegal_ad/general_ad/non_ad/uncertain의 네0~1유한 값이고 합의1차이는0.001이하다. confidence는 별도0~1값이며 확률과 대체하지 않는다. 대표값은 양성 중 illegal_ad 확률이 가장 높은 완료 조각, 없으면 첫 불확실 완료, 없으면 첫 완료 응답을 복사한다. 동률은 rawStart·chunkId 순이며 집계/평균 확률을 만들지 않는다.

각 조각은 `{chunkId,rawStart,rawEnd,status,choice,probabilities,confidence,reasonCode}`다. 범위는 원문 UTF-16 반열린 `[rawStart,rawEnd)`이며 문자 경계를 보존하고 문맥 겹침을 허용한다. 실제 직렬화 state를 고정 토크나이저로 측정해1500토큰 이하로 나눈다. 복원문 인덱스를 원문 범위로 쓰지 않는다. status는 pending/running/completed/error/not_started/cancelled이며 종료 시 pending/running은 남지 않는다. 미요청은 not_started, 실제 진행 중 취소만 cancelled다. 완료 외 choice/확률/confidence는 null이다. AI_HTTP_ERROR·AI_RESPONSE_INVALID·AI_TIMEOUT·USER_CANCELLED·TIME_LIMIT·RESOURCE_LIMIT으로 이유를 기록한다. 먼저 확인한 양성과 뒤 미완료는 확정/검토에 함께 남을 수 있다.

finding-details.json은 `{schemaVersion:2,runId,details}`다. 상세는 `{findingId,candidateId,decisionSource:"clef",ruleIds:[],ai,evidence,resultFile,sourceType,sourceIds,sourceTextRanges,observationIds}`다. resultFile은 result.json 또는 result_extra.json이며 두 파일의 모든 finding ID에 상세가 정확히 한 건 대응한다. observationIds는 로컬 은닉 관측 진단으로 광고 규칙ID가 아니다. 확률·이미지 참조·상태를 공식 finding 필드에 덧붙이지 않는다.

evidence는 `{snapshotId,path,sha256}`이며 미저장 path/hash는 null이다. DOM 근거는 `{snapshotId,topPageUrl,frameUrl,framePath,capturedAt,html,elements}`다. elements의 location은 전체 경로, styles의 elementLocation은 해당 프레임 기준이며 rawText는 직접 TEXT_NODE 원문이다. styles는 계산 CSS와 유한한 bounds를 담는다. SHA256는 실제 저장 바이트의 값이며 법적 인증이 아니다.

## 이미지 발생·OCR 기록

ocr.json은 `{schemaVersion:2,runId,enabled,model,images}`이며 model은 선택 시 Gemini, 미선택 null이다. 각 발생은 다음을 보존한다.

| 필드 | 계약 |
|---|---|
| imageId,url,frameUrl,framePath,location,snapshotId | 발생ID·top-page 실제URL·실제 프레임URL·경로·유일 소유 위치·DOM 근거ID |
| sourceKind,sourceIndex | img/css_background/css_before/css_after, 같은 kind URL 레이어0이상 인덱스(img는0) |
| imageUrl,capturedAt | 실제 HTTP(S) 자산URL 또는 null, 원본 확보 ISO시각 또는 null; data/blob payload 제외 |
| original,input | `{assetId,path,sha256,mime,byteLength}` 또는 null; input은 width/height/frameIndex:0 추가, PNG만 허용 |
| styles,concealment | 프레임 내부 스타일·TRANSPARENT/OFFSCREEN 중복 없는 배열, 이미지 글꼴 크기로 은닉 판단하지 않음 |
| status | discovered/captured/running/completed/error/not_started/cancelled/not_selected/unsupported |
| extractionStatus,text,confidence | readable/partial/no_text/unreadable 또는 null, 추출 원문 또는 null, confidence는 항상 null |
| model,promptVersion,cacheOf | 선택 모델 또는 null, 추출 규격 버전, 같은 실행 완료 캐시 원본 발생ID 또는 null |
| attemptCount,usage | 실제 시도 수(캐시0), promptTokens/completionTokens/totalTokens/costUsd의 제공된0이상유한 값 또는 각 null |
| reasonCode | 이미지/OCR 오류·USER_CANCELLED·TIME_LIMIT·RESOURCE_LIMIT·OCR_NOT_SELECTED 또는 null |

자산 길이/크기는 양의 정수, SHA256는 실제 파일 바이트다. 저장 전 path/hash는 null이고 파일 없는 해시를 만들지 않는다. 발생 정체성은 URL·프레임·소유 위치·sourceKind·sourceIndex이며 같은 PNG의 여러 소유자를 합치지 않는다. readable은 비어 있지 않은 글자, partial은 부분 글자, no_text/unreadable은 빈 문자열이다. 읽기 상태는 광고 확률이 아니다.

종료에는 discovered/captured/running이 남지 않는다. 미선택은 not_selected·OCR_NOT_SELECTED로 원본 확보/요청0, 미요청은 not_started, 실제 요청 중 취소는 cancelled다. 지원 형식 디코딩 실패를 unsupported로 숨기지 않는다. 원본·분석 PNG는 별도 역할/파일이고 각각 길이·해시·mime을 검증하며 원본 SVG/HTML은 화면에 제공하지 않는다.

## 로컬 API와 요청 형식

검증된 루프백 Host의 GET / bootstrap에서 현재 세션 토큰을 받고 모든 API·파일·근거에 Authorization Bearer를 보낸다. Origin이 있으면 실제 listener 포트의 같은 http origin이어야 하고 cross-site는 거부한다. 재시작 시 토큰은 바뀐다. JSON body는16,384바이트 이하, 임의 query·파일 경로·페이지 JS 실행 입력은 금지다.

| 경로 | 입력과 응답 |
|---|---|
| GET /api/config | `{aiConfigured,aiRequired:true,model:"cloudflare/clef",ocrModel:"google/gemini-3.8-flash",outputRoot,limits}`; limits는 maxOcrRequests/maxClefRequests/maxImageBytes/maxImagePixels, 키 값 없음 |
| POST /api/runs | 정확히 `{entryUrl:string,ocrEnabled:boolean,externalAnalysisConsent:true}` →202 RunSnapshot |
| GET /api/runs/:runId | 200 RunSnapshot |
| POST /api/runs/:runId/cancel | 빈 객체 → 진행중202/종료후200 RunSnapshot |
| GET /api/runs/:runId/findings | `{runId,findings}` 공식 항목 |
| GET /api/runs/:runId/extra-findings | `{runId,findings}` 추가 이미지 항목 |
| GET /api/runs/:runId/finding-details | V2 상세 파일 |
| GET /api/runs/:runId/review | V2 검토 파일 |
| GET /api/runs/:runId/ocr | V2 OCR 파일 |
| GET /api/runs/:runId/related-links | `{runId,candidates:[{candidateId,links}]}`; 실제 소유 링크만 |
| GET /api/runs/:runId/files/:name | 여섯 등록 JSON 바이트: result/result_extra/scan-status/review/finding-details/ocr |
| GET /api/runs/:runId/evidence/:snapshotId | 등록 DOM 근거 바이트 |
| GET /api/runs/:runId/images/:assetId | 등록 input PNG만 인증·ID·경로·symlink·해시 검증 후 image/png·nosniff |

오류는 `{error:{code,message}}`다. 잘못된 URL400 INVALID_URL, 이전 aiEnabled 입력/동의 누락/알 수 없는 필드400 INVALID_REQUEST, 누락키400 INVALID_CONFIG이며 실행과 호출을 만들지 않는다. 세션401 UNAUTHORIZED·출처403 FORBIDDEN·알 수 없는 실행/파일404 NOT_FOUND·활성 실행409 ACTIVE_RUN이다. 임의 URL/원본 SVG/HTML/미등록 자산을 제공하지 않는다.

## 자체 점검 CLI

npm run self-test는 명시적 모의 OCR/CLEF transport로 생산 경로·독립 합성 정답을 검사한다. 실제 외부 요청·제품의 로컬 광고 판정·실모델 정확도 검사는 아니다. output/self-test/<고유ID>/에 DOM/빈 결과/이미지/메뉴 네 실행을 보존한다.

dist/self-test.mjs는 --mode npm|docker|desktop, --output-dir, --chromium-path를 받는다. desktop은 실제 GUI --exe-path와 bundled Chromium이 필요하다. 중복·알 수 없는 플래그는 오류다. Inspektor.exe --self-test는 bundled Node 종료 코드를 전달한다. 성공0·오류1·이미 앱 실행중2이며 기존 결과는 덮어쓰지 않는다.

## 기존 개발용 인터페이스

기존 Flutter 디버그 브리지는 루프백 HTTP의 `GET /health`, `GET /state`, `POST /run`을 제공한다. 실행 입력은 `{ "action": "동작", "args": {} }`이며 결과는 성공 여부와 동작별 값, 실패 시 오류다. 토큰을 설정한 경우 Bearer 또는 `x-infocutter-automation-token` 헤더를 받는다. 토큰 없이는 코드에서 지정한 민감 동작이 403이고, 설정된 토큰이 틀리면 401이다. 미등록 경로는 404, 잘못된 JSON은 400이다.

MCP 서버는 환경변수 `INFOCUTTER_BRIDGE_URL`과 `INFOCUTTER_AUTOMATION_TOKEN`을 읽고 이 브리지에 요청을 전달한다. 연결 실패는 `ok: false`와 오류로 반환한다. 이 통로와 기존 규칙 JSON·증거 manifest는 개발 기반의 인터페이스이며, 공모전 결과 계약을 대체하지 않는다.

규격의 출처는 행정안전부 2026-09-14 공고의 모집요강 붙임 3·4다. 공식 공고: https://mois.go.kr/frt/bbs/type013/commonSelectBoardArticle.do?bbsId=BBSMSTR_000000000006&nttId=129458
