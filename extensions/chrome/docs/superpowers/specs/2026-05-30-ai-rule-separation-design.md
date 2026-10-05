# AI Rule Separation Interface — Design Spec

Date: 2026-05-30
Status: Approved (brainstorming) — pending implementation plan

## Purpose

Give AI-generated hide rules a **completely separate, typed home** so they can
never mix with manual/user rules — at the type level, the storage-key level, and
the DOM level. This is the data-separation foundation for the upcoming AI
auto-masking feature (an internal LiteLLM detects "provocative" regions on first
visit); this spec covers only the separation interface + storage + render lane,
not the AI calls.

## Non-goals (separate, later work)

- The AI itself: calling `llm.ranode.net/v1`, first-visit detection, turning AI
  output into rules. That populates the store defined here, in a follow-up.
- Options-page UI for browsing/toggling AI rules (separate AI tab).
- No change to the manual `ruleStore` / `textBlockStore` / `networkRuleStore` /
  `watchStore` — those are untouched, so there is **no migration of existing
  data** (the AI store is brand-new at version 1).

## Separation guarantees (the "절대 안 섞임" contract)

1. **Type-level:** AI types (`AiRule`/`AiSiteRules`/`AiRuleStore`) share no fields
   or aliases with manual types (`StoredRule`/`RuleProfile`/`RuleStore`). You
   cannot pass one where the other is expected.
2. **Storage-key-level:** AI data lives under its own `chrome.storage.local` key
   (`infocutter.aiRuleStore`), parallel to the existing four stores. Different
   key → physically cannot share an array with manual rules.
3. **DOM-level:** AI hiding uses its own marker attribute + style element,
   distinct from the manual ones, so even on the page the two lanes are separable
   and independently clearable.
4. **Module-level:** `ai-rule-storage.ts` imports no manual-rule **data, types, or
   store accessors** (no `readStore`/`RuleStore`/`StoredRule`/profile logic), and
   the manual modules import nothing AI. The only thing reused across the boundary
   is the **generic, stateless URL-matcher helpers** (`matcherToRegExp`/`matchesUrl`
   in `storage-matchers.ts`) — pure functions over a URL string, carrying no rule
   data — so reuse is DRY without mixing anything. `ai-runtime.ts` is its own
   content module with its own DOM lane.

## Constants (no hardcoding — single source of truth)

All magic values are named constants, following the existing
`STORAGE_KEY`/`STYLE_ELEMENT_ID`/`SELECTOR_HIDDEN_ATTR` pattern. Enum-like lists
are a `const` array with the type derived from it.

`src/shared/constants.ts` (ES module, used by shared/background/options):
```ts
export const AI_RULE_STORAGE_KEY = "infocutter.aiRuleStore";
export const AI_RULE_STORAGE_VERSION = 1;
export const AI_RULE_CATEGORIES = ["violence", "sexual", "gore", "hate", "shock", "other"] as const;
```

`src/content/constants.ts` (content global-script copy, mirrors the above plus the
content-only DOM ids):
```ts
const AI_RULE_STORAGE_KEY = "infocutter.aiRuleStore";
const AI_RULE_STORAGE_VERSION = 1;
const AI_RULE_CATEGORIES = ["violence", "sexual", "gore", "hate", "shock", "other"] as const;
const AI_HIDDEN_ATTR = "data-infocutter-ai-hidden";
const AI_STYLE_ELEMENT_ID = "infocutter-ai-style-rules";
```

## Types

`src/shared/ai-types.ts` — derived from the constant, independent of manual types:
```ts
import { AI_RULE_CATEGORIES } from "./constants.js";

export type AiRuleCategory = (typeof AI_RULE_CATEGORIES)[number];

export interface AiRule {
  id: string;
  selector: string;
  enabled: boolean;
  category: AiRuleCategory;
  reason: string;
  confidence: number;
  model: string;
  createdAt: string;
}

export interface AiSiteRules {
  id: string;
  matchers: string[];
  enabled: boolean;
  generatedAt: string;
  rules: AiRule[];
}

export interface AiRuleStore {
  version: number;
  settings: { globalEnabled: boolean };
  sites: AiSiteRules[];
}
```
The content global-script side declares the equivalent ambient types in
`src/content/contracts.d.ts` (same field shape, no import), matching how the
content layer already mirrors shared types.

## Components

- `src/shared/ai-types.ts` (new) — the interfaces above.
- `src/shared/ai-rule-storage.ts` (new, ES module) — `normalizeAiRuleStore`,
  `readAiRuleStore`, `writeAiRuleStore`, `findMatchingAiSite(store, url)`,
  `replaceAiSiteRules(matchers, rules, model)`, `setAiSiteEnabled`,
  `setAiRuleEnabled`, `setAiGlobalEnabled`, `clearAiRules`. Reuses
  `matcherToRegExp`/`matchesUrl` from `storage-matchers.ts` for URL matching
  (matching helpers are generic, not manual-rule-specific) but touches no manual
  store data.
- `src/content/ai-runtime.ts` (new global script) — reads the AI store from
  `chrome.storage.local` (own minimal normalize), and `renderAiRules()` clears
  prior AI markers, marks matching elements with `AI_HIDDEN_ATTR`, and sets the
  `AI_STYLE_ELEMENT_ID` style to `[${AI_HIDDEN_ATTR}] { display: none !important; }`
  when `globalEnabled` and the site/rule is enabled. Entirely parallel to
  selector-engine's manual lane; shares no attribute, style element, or state.
- `src/content/render-coordinator.ts` (modify) — `renderAllRules()` also calls
  `renderAiRules()` (orchestration only; the two render functions never touch each
  other's DOM lane).
- `src/content/index.ts` (modify) — the existing `chrome.storage.onChanged`
  listener also re-renders when `AI_RULE_STORAGE_KEY` changes.
- Content-script registration: `ai-runtime.js` added to the three lists
  (manifest, build.mjs, service-worker.ts), after `selector-engine.js` /
  `render-coordinator.js` group.

## Data flow

A future AI generator (out of scope) calls `replaceAiSiteRules(...)` →
`writeAiRuleStore` → `chrome.storage.local` under `AI_RULE_STORAGE_KEY`. The
content `storage.onChanged` fires → `renderAllRules()` → `renderAiRules()` marks
and hides via the AI lane. The manual `renderRules()` runs independently on the
manual store. Disabling AI globally (`setAiGlobalEnabled(false)`) empties the AI
style element without affecting manual hiding.

## Error handling & edge cases

- Unknown/empty/legacy AI store value → `normalizeAiRuleStore` returns an empty
  `version: 1` store (no crash). There is no prior AI data to migrate.
- Invalid AI selector → wrapped in try/catch during marking; skipped, others
  apply.
- AI and manual rules targeting the same element: both attributes may be set
  independently; either lane hiding it is fine and each is cleared by its own
  toggle. They never share state.

## Testing

- `tests/ai-rule-storage.test.ts` (node:test, importable shared module):
  `normalizeAiRuleStore` (empty/unknown → v1 empty; valid passthrough),
  `findMatchingAiSite` (URL matcher hit/miss), `setAiRuleEnabled` /
  `setAiSiteEnabled` / `clearAiRules` behavior, and that a category outside
  `AI_RULE_CATEGORIES` is rejected/normalized.
- devtools harness: write an AI store, confirm `renderAiRules()` marks elements
  with `data-infocutter-ai-hidden` and the separate `infocutter-ai-style-rules`
  style hides them, while the manual `data-infocutter-selector-hidden` lane is
  untouched.

## Layering (AGENTS.md)

- `shared` — AI types + AI storage module + constants (its own files).
- `content` — `ai-runtime.ts` render lane; render-coordinator wiring.
- No business logic in popup/background beyond eventual orchestration.
- Manual storage/render code is not modified except the one-line
  render-coordinator + storage.onChanged additions.
