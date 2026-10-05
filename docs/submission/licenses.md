# 출처와 배포 권리 조사

기반은 `dalsoop/infocutter-mono`의 커밋 `8a67fc6`입니다. 기존 Chrome 선택자 구현 `extensions/chrome/src/shared/selector.ts`를 확인했지만 새 앱의 수집·선택자 구현으로 복사·변형·import하지 않았습니다. 그룹 피커·origin+pathname frameScope·차단/마스킹도 가져오지 않았습니다. 새 앱은 읽기 전용 Playwright 관측과 프레임 소유자 전체 경로를 별도로 구현했습니다. 이 독립 구현이 기존 저장소 전체 재배포 권리를 해결해 주지는 않습니다.

원본 README는 루트 MIT LICENSE를 가리켰으나 해당 파일이 없었습니다. `apps/browser/LICENSE`에는 Apache 라이선스가 있습니다. 근거 없는 루트 MIT 표기는 제거했습니다. 전체 소스를 배포하기 전 원저작권자가 허용한 적용 범위와 권리를 확인해야 하며, 이번 작업에서 새 루트 라이선스나 허가를 작성하지 않았습니다.

| 포함 자료 | 버전·출처 | 보존 자료 |
|---|---|---|
| Electron | 44.5.1 공식 GitHub ZIP | LICENSE, 전체 LICENSES.chromium.html |
| Node | 24.19.0 공식 Windows ZIP | runtime/LICENSE |
| Chromium | 153.0.8010.12 공식 Playwright CDN ZIP, revision 1243 | LICENSE, ABOUT, matching Windows pak의 전체 credits HTML |
| Playwright·playwright-core | 1.63.0 npm | production LICENSE/NOTICE |
| dotenv | 18.0.5 npm | production LICENSE |
| Hugging Face tokenizers | 0.2.0 npm | production 고지 |
| CLEF 토크나이저 | Cloudflare/clef 고정 revision | 원본 Apache-2.0 LICENSE, 출처·크기·해시 |

토크나이저 revision은 `2f3de3dd85f379784083b0814d997ab627200f0c`입니다. 모델 가중치는 포함하지 않습니다. Gemini OCR도 외부 API로만 사용하며 별도 OCR 가중치·Python·글꼴 런타임을 배포하지 않습니다. `tokenizer.json`은 19,989,325바이트, SHA256 `06b9509352d2af50381ab2247e083b80d32d5c0aba91c272ca9ff729b6a0e523`이며 원본 LICENSE·config의 해시도 provenance에 보존합니다.

Windows Chromium ZIP의 고정 SHA256는 `415968b02065d4a9e2c10b85f0ae9f489b8fba500e94d9d0a7b7c4852a7234c1`입니다. 공개 upstream checksum을 찾지 못했으므로 관측 고정 해시로 명시합니다. `resources.pak`의 resource 38941에서 전체 credits를 추출하며 결과 8,792,402바이트, SHA256 `d24cf2ff8d3cfc8efc50e28bdd80bce32dd5a1fd64c5b0e78cb5f0eff7c8b82b`입니다. 템플릿의 링크만 넣거나 관련 없는 Linux Chrome 고지로 대신하지 않습니다.

Electron·Node는 HTTPS 공식 SHASUMS와 비교했으며 서명 검증은 별도 미수행입니다. 최신 패키징에서 metadata HTTP503 때문에 기존 검증된 동일 버전 공식 checksum·Chromium LICENSE 캐시를 해시 대조 후 사용했습니다. 이를 새 다운로드·서명·재배포 허가 검증으로 해석하지 않습니다. 패키지의 THIRD-PARTY-NOTICES.json·browser/provenance.json·전체 파일 manifest로 고지와 출처를 확인할 수 있습니다. 의존성 고지는 보존해야 하며 사용자의 `.env`, 출력 근거, 쿠키나 API 키를 배포물에 넣지 않습니다.
