---
name: infocutter-code-quality
description: Use when editing, reviewing, refactoring, or quality-checking the Infocutter Flutter app under main/apps/infocutter-app. Enforces object/interface boundaries, model-vs-widget separation, WebView safety, storage/repository rules, localization rules, and verification commands for code quality work.
---

# Infocutter Code Quality

## Overview

Apply this skill before changing, reviewing, or approving code in the Infocutter app. Keep changes behavior-preserving unless the user explicitly asks for behavior changes, and verify with the narrowest meaningful Flutter checks.

## Scope

- Work only inside `main/apps/infocutter-app` unless the user explicitly widens scope.
- Treat `AGENTS.md` in this directory as the project authority. This skill adds a repeatable workflow, not a replacement for those rules.
- Treat `.codex/AGENTS.md` as a compatibility pointer only. Do not duplicate source-of-truth rules there.
- Do not fix issues during a pure health check or review unless the user asks to implement fixes.

## Workflow

1. Check git state first:
   - `git -C <repo-main> status --short`
   - Never revert or overwrite existing user changes.
2. Read the concrete quality references:
   - `references/module-boundaries.md` before any refactor or architecture review.
   - `references/review-checklist.md` before reporting code quality status.
   - `references/commit-checklist.md` before preparing or reviewing a commit.
3. Run the audit script when doing a quality check or before finishing a refactor:
   - `python3 .codex/skills/infocutter-code-quality/scripts/audit_infocutter_quality.py .`
   - Treat `HARD` findings as blockers.
   - Report `WARN` findings as backlog unless they are in touched files.
   - For control-flow and maintainability hotspots, run:
     `bash .codex/skills/infocutter-code-quality/scripts/run_quality_metrics.sh .`
   - The metrics runner fails on DCL `ALARM` by default. Use
     `DCL_EXIT_LEVEL=warning` for stricter local or CI gates after existing WARN
     debt is reduced.
4. Read the files being changed and the nearest tests before editing.
5. Classify the work:
   - Domain logic: `lib/infocutter/`
   - General app models and settings: `lib/models/`
   - UI only: `lib/pages/`, `lib/app_bar/`, widgets
   - App bootstrap only: `lib/main.dart`
6. Make the smallest change that satisfies the request and improves the module boundary.
7. Run the verification commands below and report any skipped checks.

## Architecture Rules

- Keep business and Infocutter domain logic out of `lib/pages/`, `lib/app_bar/`, `lib/browser.dart`, `lib/webview_tab.dart`, and `lib/main.dart`.
- Put selector generation, selector parsing, URL matching, profile/rule handling, storage, picker integration, and ContentBlocker generation under `lib/infocutter/`.
- Keep `lib/models/` for app state and serializable models. Never store Flutter `Widget` payloads in models when a data object can represent the state.
- Avoid importing `main.dart` from model/domain code. Prefer injected services, repositories, or narrow adapters.
- Keep raw database access behind a repository/service boundary. Do not spread `rawQuery`, `rawInsert`, `rawUpdate`, or `rawDelete` into UI code.
- Do not add a new abstraction for one call site unless it removes meaningful duplication or enforces a real boundary.

## Object and Interface Rules

- Models may own state and serialization only. They must not own `Widget`, `BuildContext`, route/dialog code, or platform plugin calls unless no app boundary exists yet.
- UI widgets may render and dispatch user intent. They should not directly decide persistence, browser storage, WebView policy, selector generation, or domain mutation rules.
- Prefer `abstract interface class` for boundaries that cross modules:
  - persistence and repositories
  - platform/window launchers
  - WebView storage/cookie adapters
  - archive/download services
  - domain stores and rule engines
- Keep interfaces narrow. Add one method per actual cross-boundary capability, not a broad "manager" API.
- Use DTO/value objects for cross-boundary data. Do not use nullable values, magic strings, or UI labels to carry hidden domain meaning.
- A class over 500 lines or a widget with more than one workflow is a refactor candidate. Split by behavior, not by arbitrary file size.
- Functions over the configured DCL thresholds for cyclomatic complexity,
  maximum nesting, source lines of code, or maintainability index are refactor
  candidates. Treat existing violations as backlog unless touched; do not make
  touched files worse.
- When extracting from a UI file, prefer this order:
  1. pure value object or enum
  2. pure helper/factory with tests
  3. injected service/interface
  4. widget split for rendering only
- Use `references/module-boundaries.md` as the concrete path-level module map.

## WebView Safety

- Do not interpolate user input directly into injected JavaScript.
- Use `JavaScriptHandler`, `WebMessageListener`, or structured arguments for user-controlled data.
- Keep picker user script source in `lib/infocutter/selector_engine.dart` and WebView glue in `lib/infocutter/webview_adapter.dart` or `webview_integration.dart`.
- Keep ContentBlocker rule generation in `lib/infocutter/content_blocker_factory.dart`.
- Do not add network-blocking ContentBlocker actions without explicit user-visible justification. Default action remains CSS display hiding.

## Refactor Priorities

Prefer these refactors in order when the user asks for code quality work:

1. Separate global app state from `main.dart`:
   - Move `db`, window identity, WebView environment, and archive path access behind injectable services or repositories.
2. Split persisted tab data from runtime WebView controllers:
   - Persisted state should be serializable.
   - Runtime state may hold `InAppWebViewController`, pull-to-refresh, find controller, screenshot buffers, and focus/controller handles.
   - `WindowModel` should expose `WebViewModel`/tab data, not `WebViewTab` widgets.
3. Introduce service boundaries where UI directly touches plugins:
   - Cookie/local/session storage -> browser storage service interface.
   - Web archive save path and save action -> archive service.
   - Native window creation -> window launcher interface.
4. Reduce `webview_tab.dart` by extracting focused helpers:
   - Initial settings builder
   - Load start/stop handlers
   - Error page HTML builder
   - Download handling
   - Infocutter picker result handling
5. Reduce `webview_tab_app_bar.dart` by extracting commands:
   - Tab commands
   - Menu item descriptors
   - Favorite/history/archive actions
   - Screenshot/share actions
6. Reduce settings-page repetition:
   - Reuse helper widgets/functions for "mutate setting -> setSettings -> read back settings -> saveInfo -> refresh UI".
7. Convert placeholder tests into behavior tests when touching the related UI or model.

## Localization Rules

- New user-visible strings belong in `lib/l10n/app_<locale>.arb`.
- Regenerate generated localization files after ARB changes.
- Do not add new hardcoded Korean/English UI text unless it is marked as follow-up debt or is test-only text.

## Verification

Run from `main/apps/infocutter-app` when possible:

```bash
python3 .codex/skills/infocutter-code-quality/scripts/audit_infocutter_quality.py .
bash .codex/skills/infocutter-code-quality/scripts/run_quality_metrics.sh .
../../.fvm/flutter_sdk/bin/flutter analyze
../../.fvm/flutter_sdk/bin/flutter test
../../.fvm/flutter_sdk/bin/dart format --output=none --set-exit-if-changed lib test
```

If `flutter` is available on PATH, `flutter analyze`, `flutter test`, and `dart format --output=none --set-exit-if-changed lib test` are also acceptable. If full tests are too slow for the request, run the narrow test path first and state that the full suite was skipped.

For Infocutter domain changes, run at minimum:

```bash
../../.fvm/flutter_sdk/bin/flutter test test/infocutter
```

For changed diffs, also run:

```bash
git diff --check -- apps/infocutter-app
```

## Commit Lint

Before creating a commit, read `references/commit-checklist.md` and lint the
proposed subject:

```bash
python3 .codex/skills/infocutter-code-quality/scripts/lint_commit_message.py --message "refactor(infocutter-app): split browser persistence"
```

Commit subjects should normally use:

```text
<type>(infocutter-app): <imperative summary>
```

Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`,
`build`, `perf`, `revert`.

Add a commit body when changing runtime dependencies, persistence format,
WebView JavaScript injection, ContentBlocker behavior, selector logic, platform
behavior, or more than one architectural boundary. The body must say why,
whether behavior changed, what verification ran, and any residual risk.

## Review Checklist

- Read and apply `references/review-checklist.md`.
- Read and apply `references/commit-checklist.md` before commit work.
- Analyzer and formatter pass.
- Tests cover the changed behavior, not only placeholder smoke cases.
- Domain logic stays out of UI/app bootstrap files.
- Models do not import UI widgets or own `Widget` lists.
- UI files do not directly own persistence, database, cookie/storage, or native-window side effects when a boundary exists or is being touched.
- Interfaces are narrow and named after capabilities, not generic managers.
- WebView JavaScript calls do not contain user-input string interpolation.
- Storage writes go through the intended store/repository boundary.
- New runtime dependencies have a clear reason.
- Generated localization files match ARB changes.
- Large files touched by the change have not grown more coupled.
