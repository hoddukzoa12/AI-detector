#!/usr/bin/env bash
# Xcode 26: flutter_inappwebview_macos WebAuthenticationSession 컴파일 수정.
# protocol conformance 을 @available(macOS 10.15) extension + @MainActor 로 분리.
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import re

MARKER = "INFOCUTTER_WAS_PATCH_V2"
EXT = '''

// INFOCUTTER_WAS_PATCH_V2
@available(macOS 10.15, *)
extension WebAuthenticationSession: ASWebAuthenticationPresentationContextProviding {
    @MainActor
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
'''

n = 0
for path in (Path.home() / ".pub-cache").rglob("WebAuthenticationSession.swift"):
    if "macos" not in str(path).lower():
        continue
    text = path.read_text()
    if MARKER in text:
        continue
    # drop protocol from class list
    text2 = text.replace(
        "NSObject, ASWebAuthenticationPresentationContextProviding, Disposable",
        "NSObject, Disposable",
    )
    # remove in-class presentationAnchor
    text2 = re.sub(
        r"\n[ \t]*@available\(macOS 10\.\d+, \*\)\s*\n[ \t]*@MainActor\s*\n[ \t]*public func presentationAnchor\(for session: ASWebAuthenticationSession\)[^{]*\{[^}]*\}\s*",
        "\n",
        text2,
    )
    text2 = re.sub(
        r"\n[ \t]*@available\(macOS 10\.\d+, \*\)\s*\n[ \t]*public func presentationAnchor\(for session: ASWebAuthenticationSession\)[^{]*\{[^}]*\}\s*",
        "\n",
        text2,
    )
    if "extension WebAuthenticationSession: ASWebAuthenticationPresentationContextProviding" not in text2:
        text2 = text2.rstrip() + "\n" + EXT
    if text2 != text:
        path.chmod(0o644)
        path.write_text(text2)
        print(f"patched {path}")
        n += 1
print(f"done ({n} files)")
PY
