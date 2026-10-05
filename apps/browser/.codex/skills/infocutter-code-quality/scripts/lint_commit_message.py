#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


ALLOWED_TYPES = {
    "feat",
    "fix",
    "refactor",
    "test",
    "docs",
    "chore",
    "ci",
    "build",
    "perf",
    "revert",
}

APP_SCOPE = "infocutter-app"
MAX_SUBJECT_LENGTH = 72
VAGUE_SUMMARIES = {
    "change",
    "changes",
    "cleanup",
    "fix",
    "fix stuff",
    "stuff",
    "update",
    "updates",
    "wip",
    "work in progress",
}

CONVENTIONAL_RE = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[a-z0-9_.-]+)\))?!?: (?P<summary>.+)$"
)
MERGE_RE = re.compile(r"^Merge branch '.+' into '.+'$")


def first_subject(raw: str) -> str:
    for line in raw.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            return stripped
    return ""


def lint_subject(subject: str) -> list[str]:
    errors: list[str] = []

    if not subject:
        return ["commit subject is empty"]

    if len(subject) > MAX_SUBJECT_LENGTH:
        errors.append(
            f"subject is {len(subject)} characters; max is {MAX_SUBJECT_LENGTH}"
        )

    if subject.endswith("."):
        errors.append("subject must not end with a period")

    if MERGE_RE.match(subject):
        return errors

    match = CONVENTIONAL_RE.match(subject)
    if not match:
        errors.append(
            "subject must match '<type>(infocutter-app): <summary>' "
            "or allowed repo-wide '<type>: <summary>'"
        )
        return errors

    commit_type = match.group("type")
    scope = match.group("scope")
    summary = match.group("summary").strip()

    if commit_type not in ALLOWED_TYPES:
        errors.append(
            f"type '{commit_type}' is not allowed; use one of "
            f"{', '.join(sorted(ALLOWED_TYPES))}"
        )

    if scope is None and commit_type not in {"chore", "ci", "build", "revert"}:
        errors.append(f"app code commits must use scope '({APP_SCOPE})'")
    elif scope is not None and scope != APP_SCOPE:
        errors.append(f"scope '{scope}' is not allowed; use '{APP_SCOPE}'")

    if summary.lower() in VAGUE_SUMMARIES:
        errors.append("summary is too vague")

    if summary[:1].isupper():
        errors.append("summary should start lowercase")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--message", help="commit message text or subject")
    source.add_argument("--file", help="path to a commit message file")
    args = parser.parse_args()

    raw = args.message
    if args.file:
      raw = Path(args.file).read_text(encoding="utf-8")

    subject = first_subject(raw or "")
    errors = lint_subject(subject)
    if errors:
        for error in errors:
            print(f"HARD: commit message: {error}")
        return 1

    print(f"Commit message lint passed: {subject}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
