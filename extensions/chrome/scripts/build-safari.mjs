#!/usr/bin/env node
/**
 * Infocutter 확장을 빌드(dist)하고 Safari Web Extension(iOS Xcode 프로젝트)로 변환.
 *
 * 안2(플랫폼 분리, issue #12 D): iOS = Safari 확장, Android = Flutter.
 * 코어 숨김(content scripts + storage + declarativeNetRequest)은 iOS Safari 정식 지원.
 * Google 로그인은 브라우저가 처리 → 임베디드 웹뷰 정책 차단 원천 해소.
 * 출력(safari-ios/)은 빌드 산물(.gitignore). 소스가 진실이고 converter 로 재생성.
 * 다음 단계: Xcode 로 safari-ios/ 열고 Archive → App Store Connect(TestFlight).
 * 한계: chrome.offscreen 미지원 → 증거 PDF 파이프라인은 제외/재설계.
 */
import { execSync } from "node:child_process";
import { existsSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(fileURLToPath(new URL("..", import.meta.url)));
const dist = join(root, "dist");
const out = join(root, "safari-ios");

if (!existsSync(join(dist, "manifest.json"))) {
  console.log("→ pipe:build (dist 생성)");
  execSync("npm run pipe:build", { cwd: root, stdio: "inherit" });
}
if (!existsSync(join(dist, "manifest.json"))) {
  console.error("dist/manifest.json 이 없습니다 — pipe:build 실패.");
  process.exit(1);
}

rmSync(out, { recursive: true, force: true });
console.log(`→ safari-web-extension-converter (iOS) → ${out}`);
try {
  execSync(
    `xcrun safari-web-extension-converter "${dist}" ` +
      `--project-location "${out}" --ios-only --copy-resources --no-open --no-prompt --force`,
    { stdio: "inherit" }
  );
} catch {
  console.error("converter 실행 실패 — Xcode(safari-web-extension-converter) 설치를 확인.");
  process.exit(1);
}

console.log("✓ Safari iOS Xcode 프로젝트 생성: " + out);
console.log("  다음: open safari-ios/*.xcodeproj → Archive → App Store Connect.");
