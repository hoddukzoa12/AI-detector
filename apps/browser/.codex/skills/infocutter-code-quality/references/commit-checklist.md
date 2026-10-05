# Infocutter Commit Checklist

Use this before creating, reviewing, or landing a commit for
`main/apps/infocutter-app`.

## Commit Message Format

Preferred subject format:

```text
<type>(infocutter-app): <imperative summary>
```

Allowed types:

- `feat`: user-visible feature or capability
- `fix`: bug fix or behavioral correction
- `refactor`: structure change with no intended behavior change
- `test`: test-only change
- `docs`: documentation or local instruction change
- `chore`: maintenance, dependency, generated, or tooling change
- `ci`: CI or automation change
- `build`: build system or dependency wiring change
- `perf`: measurable performance improvement
- `revert`: revert commit

Allowed subject variants:

- `ci: <summary>` for repo-wide CI changes
- `chore: <summary>` for repo-wide maintenance
- `Merge branch '<branch>' into '<target>'` for merge commits

Subject rules:

- [ ] 72 characters or fewer.
- [ ] Starts with an allowed type or merge prefix.
- [ ] Uses `infocutter-app` scope for app-specific code changes.
- [ ] Summary is imperative and specific.
- [ ] No trailing period.
- [ ] No vague summaries such as `update`, `fix stuff`, `cleanup`, `wip`, or `changes`.

## Commit Body Rules

Add a body when any item is true:

- [ ] Runtime dependency changed.
- [ ] Persistence format, storage schema, or migration behavior changed.
- [ ] WebView JavaScript injection, ContentBlocker behavior, or selector logic changed.
- [ ] Platform behavior changed for Android, iOS, macOS, Windows, or Linux.
- [ ] The commit is a large refactor touching more than one boundary.

When a body is present, include:

- [ ] Why the change exists.
- [ ] User-visible behavior impact, or explicitly `Behavior unchanged`.
- [ ] Verification commands run.
- [ ] Residual risk or follow-up debt.

## Pre-Commit Code Checklist

- [ ] `git status --short` reviewed so unrelated user changes are not included accidentally.
- [ ] No secrets, local environment files, generated caches, or large binaries are staged.
- [ ] Diff contains only the requested scope.
- [ ] No new hard violation from the Infocutter audit script.
- [ ] No touched function newly exceeds configured DCL metrics without being
      reported as follow-up debt.
- [ ] Touched large files got smaller or gained a clear extraction boundary.
- [ ] New files live in the correct module per `module-boundaries.md`.
- [ ] User-visible strings follow l10n rules.
- [ ] No direct user input interpolation into injected JavaScript.
- [ ] No new direct plugin manager access from `lib/pages/` or `lib/app_bar/`.
- [ ] No model owns `Widget`, `BuildContext`, `GlobalKey`, routes, dialogs, or UI files.

## Required Verification

Run from `main/apps/infocutter-app`:

```bash
../../.fvm/flutter_sdk/bin/dart format --output=none --set-exit-if-changed lib test
python3 .codex/skills/infocutter-code-quality/scripts/audit_infocutter_quality.py .
bash .codex/skills/infocutter-code-quality/scripts/run_quality_metrics.sh .
../../.fvm/flutter_sdk/bin/flutter analyze
../../.fvm/flutter_sdk/bin/flutter test
git -C ../.. diff --check -- apps/infocutter-app
```

Run the commit subject lint before committing:

```bash
python3 .codex/skills/infocutter-code-quality/scripts/lint_commit_message.py --message "refactor(infocutter-app): split browser persistence"
```

For a prepared commit message file:

```bash
python3 .codex/skills/infocutter-code-quality/scripts/lint_commit_message.py --file .git/COMMIT_EDITMSG
```

## Commit Scope Guidance

- One commit should represent one coherent reason.
- Separate guardrail/skill updates from app code refactors when practical.
- Separate generated files from source changes only when the generator output is large enough to obscure review.
- Do not squash unrelated pre-existing dirty files into the commit.
