# Infocutter Chrome Extension Parity

This document tracks the Flutter app against the Chrome extension feature set.

## Status Legend

- Done: implemented in the app and covered by tests or direct UI wiring.
- Partial: app has a usable baseline but not Chrome parity.
- Missing: no app implementation yet.
- Blocked: requires a platform decision or WebView capability decision.

## Matrix

| Area | Chrome extension source | App status | Tracking |
|---|---|---:|---|
| Selector rule store | `packages/infocutter-selector-rules`, `src/shared/storage.ts` | Partial | #1 |
| Picker and selector refinement | `src/content/picker-*`, `src/content/selector-engine.ts` | Partial | #2 |
| iframe scoped rules | `all_frames`, `frame-context.ts`, `picker-iframe.ts` | Partial | #3 |
| Text block rules | `packages/infocutter-text-blocks`, `text-block-runtime.ts` | Partial | #4 |
| Network filters | `packages/infocutter-filter-importer`, `network-rules.ts` | Partial | #5 |
| Rule templates | `templates/*.json`, `template-ui.ts` | Partial | #6 |
| Watch targets | `packages/infocutter-watch`, `watch-runtime.ts` | Partial | #7 |
| Evidence records | `evidence-db.ts`, offscreen PDF builder, downloads | Partial | #8 |
| AI auto masking | `ai-*`, `ai-orchestrator.ts`, `ai-runtime.ts` | Partial | #9 |
| Parity docs/tests | N/A | Partial | #10 |

## Current App Baseline

- Selector templates are bundled in Dart and can be imported from the Infocutter settings tab.
- Text block rules have Chrome-compatible models/codecs, app storage, current-site management UI, and a WebView UserScript runtime for repeated keyword block hiding.
- Network filters have ABP/uBlock network-rule parsing, app storage, settings UI, allow-rule precedence, WebView navigation cancellation, and WebView `shouldInterceptRequest` subresource blocking for matched HTTP(S) URLs. This is still a WebView-level implementation rather than Chrome `declarativeNetRequest`, but the app now has an actual subresource interception path.
- Watch targets can be stored and managed from the Watch tab. A WebView UserScript now scans page text, reports recent detections, and can auto-mask matched blocks.
- Evidence records can be captured from the current WebView with HTML hash records, `page.html`, `manifest.json`, `page.png` when screenshot capture succeeds, and `summary.pdf`. Watch detections can be attached as evidence metadata.
- AI auto masking has config storage/UI, secure API key storage, legacy API-key migration, a manual current-page analysis action, structural page candidate collection without raw text content, an OpenAI-compatible client, suggestion parsing, persistent generated-rule suggestions, and user-approved suggestion application into selector hide rules. Automatic background analysis is still intentionally absent.

## Next Verification Targets

- Add fixture tests that compare Chrome template JSON with `bundledInfocutterTemplates`.
- Add a WebView integration test page for watch term detection after runtime wiring lands.
- Decide whether network filters need native subresource interception beyond `shouldOverrideUrlLoading`.
