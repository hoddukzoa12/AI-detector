# 실제 통합 검증

빌드된 npm 서버·Chromium 웹 화면·배포 CLI의 생산 실행 경로를 검사한다. 광고 판정 HTTP만 명시적 모의 OCR/CLEF로 주입하며 제품의 로컬 광고 판정이나 실제 모델 정확도로 간주하지 않는다. 수작업 DOM25건(유형17·쿼리2·iframe6)과 정상 반례, 이미지39발생·20양성 소유자, 메뉴22음성·주변5양성이 독립 정답이다.

```sh
npm run typecheck
npm run lint
npm test
npm run build
npm run test:e2e
npm run self-test
```

브라우저 단위·통합·Docker·Windows ZIP은 자원 경합과 vfs 공간 때문에 순차 실행한다. `deployment.test.ts`는 별도 production 서버에서 키·CLEF 동의·OCR 선택·세 목록·PNG·여섯 JSON·근거/다운로드 해시를 실제 UI로 검사한다. 생산 취소 검사는 페이지 생성 중 UI 중단·17확정 보존·최종 상태/근거·늦은 응답 불변·프로세스 그룹 정리를 확인한다. 모의 transport는 지정 endpoint/모델만 받아 다른 외부 요청을 실패시킨다.

`ai-integration.test.ts`는 실제 수집·관측·CLEF 어댑터·서버·UI에서0.8확정/0.79검토·uncertain·HTTP 오류·양성+미완료·취소·한도·요청 귀속을 확인한다. JSON 키 순서 대신 네 확률 값·원문 범위·조각 상태·대표값을 정확히 비교한다. 키/동의 없는 시작은 실행과 요청을 생성하지 않는다. OCR 미선택은 원본 확보·OCR 요청0이며 CLEF는 필수다.

`self-test.test.ts`는 bundled CLI의 인수 거부·desktop exe 인접 설정·bundled Chromium·반복 격리·실패 exit1을 검사한다. Linux의 exe 참조 파일은 설정 경계용이며 Windows GUI 증거가 아니다. 자체 점검은 `<outputRoot>/self-test/<고유ID>/`에 네 실행을 보존하고 이전 result/latest/runs 바이트를 바꾸지 않는다. 명시적 모의 OCR/CLEF로 검사해 실모델/실Windows는 NOT_RUN이다.

```sh
node dist/self-test.mjs --mode desktop --exe-path /actual/Inspektor.exe --chromium-path /bundled/chrome.exe --output-dir /configured/output
node dist/self-test.mjs --mode docker --output-dir /app/output
```

독립 검사기는 공식 meta/findings·단일 유형·중복ID/위치·UTF-8/BOM·정확한 원문·프레임 유일성과 V2 두 결과/이미지 근거를 대조한다. 생산 detector/validator를 정답으로 호출하지 않는다. quoted selector의 >>>는 경로 구분자로 오인하지 않고 상대 iframe src는 DOM 변경 없이 baseURI로 해석한다.

## Docker 재현

```sh
DOCKER_BUILDKIT=1 docker build --secret id=proxy_ca,src="$CODEX_PROXY_CERT" -t inspector:verify .
npm run test:docker
```

일반 환경은 CA secret을 생략한다. TLS·cap-drop ALL·no-new-privileges·init·UID1001·127.0.0.1:4173 게시를 유지한다. 자체 점검과 production UI·PNG·여섯 JSON·호스트 볼륨 bytes/hash 모두 종료0이어야 한다. 테스트 합성 출력만 host-readable로 만들며 다른 이미지·volume·사용자 결과를 삭제하지 않는다.

## 실제 유료 평가의 별도 경계

`actual-evaluation.ts`는 자동 테스트 파일이 아니며 별도 승인·실행 인수가 필요하다. 고정 OCR/CLEF endpoint, 실제 요청 전 지속되는 예산 기록, 단일 단계 재실행 거부, 누락키 NOT_RUN·비밀 제외는 `actual-evaluation-guard.test.ts`에서 모의 transport로 확인한다. 실제 작은 평가는 OCR8·CLEF10회로 종료했고 같은 단계의 추가 호출은 하지 않는다. 자동 테스트의 모의 카운트는 실제 카운트가 아니다.

2026-10-05 단위463·통합14와 Linux 실행/정적 Windows 검사가 통과했다. 소형 실제 이미지 글자 차이0·CLEF 선택9/10은 해당 표본 측정이며 실제 사이트·Windows GUI·두 실키 교체·주최 측 평가·30분 PC 성능은 별도다. 전체 재배포 권리도 미확정이다.
