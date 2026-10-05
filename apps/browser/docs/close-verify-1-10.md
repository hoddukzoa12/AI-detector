# Close-verify · GitLab #1–#10 (2026-08-08)

로드맵 #18 §1. 코드 존재 여부와 수용 기준을 대조한 판정.

| Issue | Verdict | Evidence | Residual |
|---|---|---|---|
| #1 Selector 규칙 관리 UI | **close candidate** | `lib/infocutter/ui/infocutter_rule_manager*.dart`, tests | 없음 |
| #2 Picker parity | **keep partial** | `selection_session*.dart`, depth targeting | multi-select polish may remain |
| #3 iframe scoped rules | **close candidate** | `frameScope` runtime + models | 실기기 iframe 스모크 권장 |
| #4 Text Block | **close candidate** | `text_block_*` + tests | 없음 |
| #5 Network filter import | **keep** | `network_filter_service.dart` import | 구독·갱신 → #16 (importFromUrl 1차 착수 2026-08-08) |
| #6 Template import | **close candidate** | `template_catalog.dart` | 없음 |
| #7 Watch | **close candidate** | `watch_service/runtime` + tests | 없음 |
| #8 Evidence | **close candidate** | `evidence_service/pdf` + tests | PNG fail soft 경로 유지 |
| #9 AI auto masking | **keep partial** | services + UI | auto background 의도적 미구현 |
| #10 Parity matrix | **keep** | `docs/infocutter-extension-parity.md` | 이 문서와 함께 갱신 |

**닫기 절차**: 사람이 glab 으로 close candidate 에 코멘트 후 close. 에이전트가 일괄 close 하지 않음(원장 정책).
