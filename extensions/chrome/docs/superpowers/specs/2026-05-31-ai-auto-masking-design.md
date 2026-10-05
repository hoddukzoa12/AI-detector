# AI Auto-Masking (Population) — Design Spec

Date: 2026-05-31
Status: Approved (brainstorming) — pending implementation plan

## Purpose

Let infocutter, with the user's consent, send a page's structure to the internal
LiteLLM gateway, have it identify regions matching user-selected "provocative"
categories, and auto-hide them — by populating the **separate** `aiRuleStore`
that already exists (the data-separation interface from MR #83). The AI lane
renders these hidden, fully isolated from manual rules.

## Decisions (from brainstorming)

- **AI input:** the content layer serializes candidate **blocks** (a stable
  selector + truncated visible text + image `alt`/`src`), size-bounded. Not a
  screenshot. The model returns selectors to hide.
- **Trigger:** a master toggle defaulting **OFF**. When ON, analysis runs
  automatically on the **first visit** to a host (once per host; analyzed hosts
  are not re-requested). Manual re-analysis is available.
- **"Provocative" definition:** the user selects which of the fixed six
  categories (`AI_RULE_CATEGORIES` = violence/sexual/gore/hate/shock/other) to
  act on. The AI tags each region with a category; only rules in enabled
  categories are kept/applied.
- **Auth:** the user enters an API key + model in the options page (mirroring the
  existing template-server token field); endpoint defaults to
  `https://llm.ranode.net/v1`. Stored in `chrome.storage.local`; never hardcoded.

## Non-goals (YAGNI)

- No screenshot / multimodal vision (DOM-based only).
- No cross-device sync of keys (local storage only).
- No per-element manual editing of AI rules in this feature (the separate AI
  options management UI is Phase 3 polish).

## Architecture & module isolation

- `src/shared/ai-config.ts` (new) — credentials + endpoint + model, under its own
  key `infocutter.aiConfig` (secrets kept **out of** the rule store), plus the set
  of already-analyzed hosts: `readAiConfig`/`writeAiConfig`, `isHostAnalyzed`,
  `markHostAnalyzed`. No rule data here.
- `src/shared/ai-llm-client.ts` (new) — pure, testable: `buildAiDetectionPrompt(blocks, enabledCategories)`
  and `parseAiDetectionResponse(text)` → `{ selector, category, reason, confidence }[]`
  (tolerant JSON extraction); plus a thin `callLiteLLM(config, messages)` doing the
  `fetch` to `${endpoint}/chat/completions`.
- `src/shared/ai-detection.ts` (new) — orchestration glue: given serialized blocks
  + config + the store's `enabledCategories`, calls the client, filters by enabled
  category and a confidence threshold, and calls `replaceAiSiteRules(matchers,
  rules, model)` (from `ai-rule-storage.ts`).
- `src/content/ai-collector.ts` (new global script) — `collectAiBlocks()`:
  serializes visible candidate elements to `{ selector, text, imageAlt, imageSrc }`,
  skipping form inputs / password fields, capped in count and per-field length.
- `src/background/service-worker.ts` (modify) — a `webNavigation.onCompleted`
  handler that, when the master toggle is ON and the host is http(s) and not yet
  analyzed, asks the content layer for blocks, runs `ai-detection`, and marks the
  host analyzed; plus a message handler for the manual "analyze this page" action.
- `src/shared/ai-rule-storage.ts` (modify) — extend `settings` with
  `enabledCategories: AiRuleCategory[]` (+ `setAiEnabledCategories`); the store
  shape stays in the separated AI namespace.
- Options page (modify) — an AI section: master toggle, category checkboxes,
  endpoint/key/model inputs.

The manual `ruleStore`/manual render lane is never touched; AI rules flow only
into `aiRuleStore` and render via the AI lane (`renderAiRules`).

## Data flow (auto path)

```
webNavigation.onCompleted (top frame, http(s))
  → background: master toggle ON? host not analyzed?  (else stop)
  → message content: collectAiBlocks()
  → background: ai-detection(blocks, config, enabledCategories)
      → ai-llm-client.callLiteLLM(config, buildAiDetectionPrompt(...))
      → parseAiDetectionResponse → filter (enabled category + confidence ≥ threshold)
  → replaceAiSiteRules([host matcher], rules, model)   (writes aiRuleStore)
  → markHostAnalyzed(host)
  → chrome.storage.onChanged → content renderAiRules() hides via AI lane
```
The manual path is the same minus the trigger: a popup/menu "이 페이지 분석"
message runs the same `ai-detection` for the active tab on demand.

## Phasing (one feature, sequenced plans)

- **Phase 1 — manual end-to-end:** `ai-config`, `ai-llm-client` (+ unit tests for
  prompt build / response parse), `ai-detection`, `ai-collector`, a manual
  "analyze this page" trigger (popup button → background → detect → store), and a
  minimal options AI section (toggle, category checkboxes, key/model/endpoint).
  Verifiable end-to-end without auto-trigger.
- **Phase 2 — auto first-visit:** `webNavigation.onCompleted` trigger gated by the
  toggle + `isHostAnalyzed`/`markHostAnalyzed`.
- **Phase 3 — AI rule management UI:** browse/toggle AI rules by category in
  options.

Each phase is its own plan; each leaves a green, shippable build.

## Error handling & privacy

- Master toggle defaults OFF; nothing is sent to the AI until the user opts in.
- Only http(s) top-frame pages are analyzed; `ai-collector` skips `<input>`,
  `<textarea>`, password fields, and contenteditable, and truncates text +
  caps block count to bound tokens and avoid leaking form data.
- LLM call failure (network, non-2xx, unparseable body) → no rules written, the
  host is **not** marked analyzed (so a later retry can succeed), and the error is
  logged; the page is unaffected.
- Missing/blank API key → analysis is skipped with a status message; no call made.
- API key lives in `chrome.storage.local` (not synced).

## Testing

- `tests/ai-llm-client.test.ts` (node:test): `buildAiDetectionPrompt` includes the
  enabled categories + block selectors; `parseAiDetectionResponse` tolerantly
  extracts the JSON array, drops malformed entries, and coerces an unknown
  category. `tests/ai-detection.test.ts`: filtering by enabled category +
  confidence threshold (with the LLM client injected/stubbed).
- devtools harness: stub the LiteLLM `fetch` to return a canned detection, run the
  manual path, and confirm rules land in `aiRuleStore` and render via the AI lane
  (separate from the manual lane).

## Layering (AGENTS.md)

- `shared` — config, client, detection, AI store (its own files).
- `content` — `ai-collector` (page serialization) + the existing AI render lane.
- `background` — trigger + orchestration only.
- `options` — settings UI.
- No secrets in code; AI data only in the separated `aiRuleStore`.
