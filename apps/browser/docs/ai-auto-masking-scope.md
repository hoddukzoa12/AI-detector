# AI Auto Masking Scope

GitLab issue: #9

## Decision Needed

The Chrome extension has AI block collection, LLM orchestration, AI rule storage,
and generated selector management. The Flutter app should not silently inherit
that feature until these decisions are explicit:

- Whether the mobile/desktop app should send page structure to an external model.
- Where API keys live and how they are protected.
- Whether analysis is manual only or can run automatically per host.
- Which block categories are allowed to auto-apply versus requiring approval.
- How generated rules are explained, disabled, and deleted.

## Recommended First App Slice

1. Add local AI config storage with endpoint, model, and analyzed hosts.
2. Add AI rule store compatibility models.
3. Add a manual "Analyze current page" action gated behind explicit settings.
4. Collect candidate blocks in WebView without text content unless the user opts in.
5. Show generated selectors as pending suggestions, not active rules.

## Non-goals For The First Slice

- No automatic background analysis.
- No hidden network calls.
- No direct auto-apply without preview.
- No reuse of Chrome `chrome.runtime` message flow.

## Current App State

The app now has AI config storage and Settings tab UI for endpoint, model, API
key, and analyzed-host reset. API keys are stored in secure storage, with legacy
SharedPreferences key migration on load. It also has a manual "Analyze current
page" action that collects structural candidate metadata from the WebView
without raw text content, sends it to an OpenAI-compatible endpoint, parses JSON
suggestions, stores generated suggestions per host, and lets the user apply a
suggestion into the existing selector hide-rule store.

Still intentionally absent:

- No automatic background analysis.
- No direct auto-apply without user approval.
- No Chrome background orchestration parity yet.
