# Infocutter Code Quality Checklist

Use this checklist for reviews and refactors. Report unchecked items explicitly.

## Before Editing

- [ ] Check git state and identify pre-existing dirty files.
- [ ] Read `AGENTS.md`.
- [ ] Read this skill's `module-boundaries.md` for affected modules.
- [ ] Read this skill's `commit-checklist.md` if the work may be committed.
- [ ] Read the target files and nearest tests.
- [ ] Classify the change as domain, model, service, UI, bootstrap, or test-only.

## Boundary Checklist

- [ ] No model imports `webview_tab.dart`, app bars, pages, `BuildContext`, or route/dialog APIs.
- [ ] No domain file under `lib/infocutter/` imports UI or app bootstrap code.
- [ ] No UI file directly performs raw SQL, direct repository implementation work, or hidden domain rule mutation.
- [ ] Runtime plugin state is separated from persisted JSON when touching tab/window state.
- [ ] New cross-module behavior has a narrow interface, not a generic manager.
- [ ] New classes have one reason to change.
- [ ] Touched functions do not newly exceed DCL metric thresholds for nesting,
      cyclomatic complexity, source lines of code, or maintainability index.
- [ ] DCL `ALARM` findings are treated as blockers; `WARN` findings are backlog
      unless they are introduced or worsened by the touched files.

## File-Specific Checks

### `lib/models/window_model.dart`

- [ ] Stores tab data as `WebViewModel` or `TabSession`, not `WebViewTab`.
- [ ] Serializes only JSON-safe fields.
- [ ] Does not create `GlobalKey`, `Widget`, route, dialog, or page objects.
- [ ] Disposes runtime WebView keep-alive handles only through an explicit runtime boundary or documented transitional code.

### `lib/models/browser_model.dart`

- [ ] Does not grow new platform/window-manager calls.
- [ ] Persistence uses `BrowserPersistence` / `WindowPersistence`.
- [ ] Settings defaults and URL decisions are represented as values, not duplicated branches in UI.

### `lib/webview_tab.dart`

- [ ] WebView callbacks stay thin.
- [ ] Selector generation stays in `lib/infocutter/selector_engine.dart`.
- [ ] Picker protocol handling stays in `lib/infocutter/webview_adapter.dart` or focused picker flow code.
- [ ] Error page HTML, download handling, and settings construction are extracted when touched.
- [ ] User-controlled values passed to JavaScript use `jsonEncode`, handlers, or structured messages.

### `lib/app_bar/webview_tab_app_bar.dart`

- [ ] Menu rendering is separate from command execution when touched.
- [ ] New menu actions use a command/descriptor object instead of extending large switch blocks.
- [ ] Archive save logic goes through `WebArchiveService` when touched.
- [ ] No new hardcoded user-visible strings.

### `lib/pages/developers/storage_manager.dart`

- [ ] Cookie, local storage, session storage, web storage, and auth credentials go through `BrowserStorageService` when touched.
- [ ] UI table/editing widgets are separated from plugin calls.
- [ ] Platform branches are isolated behind service capabilities where practical.

### `lib/pages/settings/**`

- [ ] Repeated `setSettings -> saveInfo -> setState` patterns are extracted when touched.
- [ ] Setting rows are composed from reusable row builders.
- [ ] Platform-only settings are guarded by capability methods or clear platform predicates.

### `lib/infocutter/**`

- [ ] Rule store schema changes include version/migration handling.
- [ ] Content blocker generation remains in `content_blocker_factory.dart`.
- [ ] URL matching remains in `url_matcher.dart`.
- [ ] Tests cover selector, matcher, codec, and content blocker behavior.

## Test Checklist

- [ ] Add or update behavior tests for changed model/service/domain behavior.
- [ ] Prefer service/model tests over widget tests for non-rendering logic.
- [ ] Keep placeholder smoke tests from being the only coverage for touched behavior.
- [ ] For generated l10n changes, verify generated files and ARB files move together.

## Verification Commands

Run from `main/apps/infocutter-app`:

```bash
../../.fvm/flutter_sdk/bin/dart format --output=none --set-exit-if-changed lib test
../../.fvm/flutter_sdk/bin/flutter analyze
../../.fvm/flutter_sdk/bin/flutter test
python3 .codex/skills/infocutter-code-quality/scripts/audit_infocutter_quality.py .
bash .codex/skills/infocutter-code-quality/scripts/run_quality_metrics.sh .
git -C ../.. diff --check -- apps/infocutter-app
```

For Infocutter domain-only changes, at minimum also run:

```bash
../../.fvm/flutter_sdk/bin/flutter test test/infocutter
```

## Commit Readiness Checklist

- [ ] Proposed subject passes `lint_commit_message.py`.
- [ ] Subject uses `type(infocutter-app): summary` unless the change is truly repo-wide.
- [ ] Subject is specific, lowercase, imperative, no trailing period, and 72 characters or fewer.
- [ ] Commit body exists when dependencies, persistence, WebView injection, ContentBlocker behavior, selector logic, platform behavior, or multiple boundaries changed.
- [ ] Commit body lists why, behavior impact, verification, and residual risk.
- [ ] Staged files were reviewed one by one.
- [ ] Pre-existing dirty files are not included unless intentionally part of the requested change.
- [ ] New `.codex` rules, scripts, and references are included together when changing the skill.
- [ ] New tests are included with their matching implementation changes.
- [ ] No generated/cache files such as `__pycache__` are staged.

Commit subject lint:

```bash
python3 .codex/skills/infocutter-code-quality/scripts/lint_commit_message.py --message "refactor(infocutter-app): split browser persistence"
```

## Definition of Done

- [ ] The changed behavior is covered by at least one focused test unless the change is documentation/config-only.
- [ ] Analyzer, formatter, tests, audit script, and diff check pass or skipped checks are justified.
- [ ] Quality metrics were checked when refactoring UI/control-flow-heavy code.
- [ ] No new boundary violation is introduced.
- [ ] Large touched files are smaller, more focused, or at least not more coupled.
- [ ] Final response names residual risks and the next highest-value refactor.
