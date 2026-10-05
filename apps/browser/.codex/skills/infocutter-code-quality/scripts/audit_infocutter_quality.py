#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


HARD = "HARD"
WARN = "WARN"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def rel(path: Path, root: Path) -> str:
    return str(path.relative_to(root))


def add(results: list[tuple[str, str, str]], severity: str, path: str, message: str) -> None:
    results.append((severity, path, message))


def iter_dart(root: Path) -> list[Path]:
    return sorted((root / "lib").rglob("*.dart"))


def check_required_files(root: Path, results: list[tuple[str, str, str]]) -> None:
    required = [
        "AGENTS.md",
        ".codex/AGENTS.md",
        ".codex/skills/infocutter-code-quality/SKILL.md",
        ".codex/skills/infocutter-code-quality/references/commit-checklist.md",
        ".codex/skills/infocutter-code-quality/references/module-boundaries.md",
        ".codex/skills/infocutter-code-quality/references/review-checklist.md",
        ".codex/skills/infocutter-code-quality/scripts/lint_commit_message.py",
    ]
    for item in required:
        if not (root / item).exists():
            add(results, HARD, item, "required code-quality guidance file is missing")


def check_forbidden_imports(root: Path, results: list[tuple[str, str, str]]) -> None:
    for path in iter_dart(root):
        text = read(path)
        name = rel(path, root)

        if "import 'package:infocutter_app/main.dart'" in text or "import 'main.dart'" in text:
            add(results, HARD, name, "must not import main.dart outside bootstrap")

        if name.startswith("lib/models/"):
            forbidden = [
                "package:flutter/material.dart",
                "package:flutter/widgets.dart",
                "webview_tab.dart",
                "/app_bar/",
                "/pages/",
            ]
            for pattern in forbidden:
                if pattern in text:
                    add(results, HARD, name, f"model imports UI boundary: {pattern}")

        if name.startswith("lib/infocutter/"):
            forbidden = [
                "package:infocutter_app/main.dart",
                "package:infocutter_app/app_bar/",
                "package:infocutter_app/pages/",
            ]
            for pattern in forbidden:
                if pattern in text:
                    add(results, HARD, name, f"domain imports UI/bootstrap boundary: {pattern}")


def check_raw_sql(root: Path, results: list[tuple[str, str, str]]) -> None:
    allowed = {"lib/services/browser_persistence.dart"}
    sql_pattern = re.compile(r"\braw(Query|Insert|Update|Delete)\s*\(")
    for path in iter_dart(root):
        name = rel(path, root)
        if name in allowed:
            continue
        if sql_pattern.search(read(path)):
            add(results, HARD, name, "raw SQL must stay behind persistence services")


def check_ui_boundary_imports(root: Path, results: list[tuple[str, str, str]]) -> None:
    ui_prefixes = ("lib/pages/", "lib/app_bar/")
    forbidden_patterns = [
        "import 'package:infocutter_app/main.dart'",
        'import "package:infocutter_app/main.dart"',
        "import 'package:sqflite/",
        'import "package:sqflite/',
        "import 'package:sqflite_common_ffi/",
        'import "package:sqflite_common_ffi/',
        "import 'package:sqlite3/",
        'import "package:sqlite3/',
    ]

    for path in iter_dart(root):
        name = rel(path, root)
        if not name.startswith(ui_prefixes):
            continue

        text = read(path)
        for pattern in forbidden_patterns:
            if pattern in text:
                add(results, HARD, name, f"UI boundary imports forbidden dependency: {pattern}")


def check_widget_ownership(root: Path, results: list[tuple[str, str, str]]) -> None:
    for path in (root / "lib" / "models").glob("*.dart"):
        text = read(path)
        name = rel(path, root)
        if re.search(r"\bList\s*<\s*Widget\s*>", text) or re.search(r"\bWidget\b", text):
            severity = WARN if name == "lib/models/webview_model.dart" else HARD
            add(results, severity, name, "model must not own Widget state")
        if re.search(r"\bBuildContext\b|\bGlobalKey\b", text):
            add(results, HARD, name, "model must not own BuildContext or GlobalKey")


def check_large_files(root: Path, results: list[tuple[str, str, str]]) -> None:
    thresholds = {
        "lib/app_bar/webview_tab_app_bar.dart": 700,
        "lib/webview_tab.dart": 500,
        "lib/pages/developers/storage_manager.dart": 500,
        "lib/pages/settings/cross_platform_settings.dart": 450,
        "lib/models/browser_model.dart": 300,
        "lib/models/webview_model.dart": 260,
        "lib/models/window_model.dart": 260,
    }
    for item, limit in thresholds.items():
        path = root / item
        if not path.exists():
            continue
        lines = len(read(path).splitlines())
        if lines > limit:
            add(results, WARN, item, f"{lines} lines exceeds refactor threshold {limit}")


def _line_number_for_offset(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _strip_multiline_strings(text: str) -> str:
    return re.sub(r"r?'''[\s\S]*?'''|r?\"\"\"[\s\S]*?\"\"\"", "", text)


def _max_if_nesting(text: str) -> tuple[int, int]:
    token = re.compile(r"\bif\s*\(|[{}]")
    pending_if_depths: list[int] = []
    block_stack: list[bool] = []
    max_depth = 0
    max_offset = 0

    for match in token.finditer(text):
        value = match.group(0)
        if value.startswith("if"):
            pending_if_depths.append(sum(1 for is_if in block_stack if is_if) + 1)
            continue
        if value == "{":
            if pending_if_depths:
                depth = pending_if_depths.pop()
                block_stack.append(True)
                if depth > max_depth:
                    max_depth = depth
                    max_offset = match.start()
            else:
                block_stack.append(False)
            continue
        if value == "}" and block_stack:
            block_stack.pop()

    return max_depth, _line_number_for_offset(text, max_offset)


def check_control_flow_hotspots(root: Path, results: list[tuple[str, str, str]]) -> None:
    per_file_if_limit = 25
    max_if_nesting_limit = 5
    excluded_prefixes = (
        "lib/l10n/generated/",
    )

    for path in iter_dart(root):
        name = rel(path, root)
        if name.startswith(excluded_prefixes):
            continue
        text = _strip_multiline_strings(read(path))
        if_count = len(re.findall(r"\bif\s*\(", text))
        if if_count > per_file_if_limit:
            add(
                results,
                WARN,
                name,
                f"{if_count} if statements; consider resolver/presenter/use-case extraction",
            )

        max_depth, line_number = _max_if_nesting(text)
        if max_depth > max_if_nesting_limit:
            add(
                results,
                WARN,
                f"{name}:{line_number}",
                f"if nesting depth {max_depth} exceeds threshold {max_if_nesting_limit}",
            )


def check_direct_plugin_managers(root: Path, results: list[tuple[str, str, str]]) -> None:
    ui_paths = [
        root / "lib" / "pages",
        root / "lib" / "app_bar",
    ]
    patterns = [
        "CookieManager.instance",
        "WebStorageManager.instance",
        "HttpAuthCredentialDatabase.instance",
        "WindowManagerPlus.createWindow",
    ]
    for base in ui_paths:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.dart")):
            text = read(path)
            for pattern in patterns:
                if pattern in text:
                    add(results, WARN, rel(path, root), f"direct plugin manager access: {pattern}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".", help="Infocutter app root")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    results: list[tuple[str, str, str]] = []

    check_required_files(root, results)
    check_forbidden_imports(root, results)
    check_raw_sql(root, results)
    check_ui_boundary_imports(root, results)
    check_widget_ownership(root, results)
    check_large_files(root, results)
    check_control_flow_hotspots(root, results)
    check_direct_plugin_managers(root, results)

    hard = [item for item in results if item[0] == HARD]
    warn = [item for item in results if item[0] == WARN]

    if not results:
        print("Infocutter quality audit passed with no findings.")
        return 0

    for severity, path, message in results:
        print(f"{severity}: {path}: {message}")

    print(f"\nSummary: {len(hard)} hard violation(s), {len(warn)} warning(s).")
    return 1 if hard else 0


if __name__ == "__main__":
    sys.exit(main())
