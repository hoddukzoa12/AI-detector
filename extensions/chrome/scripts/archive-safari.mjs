#!/usr/bin/env node
/**
 * Safari iOS Xcode 프로젝트(safari-ios/) → Archive → .ipa export.
 * build-safari.mjs(pipe:safari) 다음 단계. App Store Connect(TestFlight) 업로드 직전.
 *
 * 사전(사람 게이트): Apple Distribution 인증서 + 프로비저닝 + Team ID.
 *   SAFARI_TEAM_ID            — Apple Developer Team ID(필수)
 *   SAFARI_SIGNING_IDENTITY   — 기본 "Apple Distribution"
 * 자격증명이 없으면 안내하고 종료 — 에이전트가 대신 발급/서명 못 함.
 */
import { execSync } from "node:child_process";
import { existsSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(fileURLToPath(new URL("..", import.meta.url)));
const projectDir = join(root, "safari-ios");
const teamID = process.env.SAFARI_TEAM_ID?.trim();
const identity = process.env.SAFARI_SIGNING_IDENTITY?.trim() || "Apple Distribution";

if (!existsSync(projectDir)) {
  console.error("safari-ios/ 가 없습니다 — 먼저 npm run pipe:safari.");
  process.exit(1);
}
if (!teamID) {
  console.error("SAFARI_TEAM_ID(env) 필요 — Apple Developer Team ID.");
  console.error("  export SAFARI_TEAM_ID=XXXXXXXXXX");
  console.error("  자격증명(Apple Distribution 인증서·프로비저닝)은 사람이 확보해야 함.");
  process.exit(1);
}

const project = readdirSync(projectDir, { withFileTypes: true })
  .find((e) => e.isFile() && e.name.endsWith(".xcodeproj"));
if (!project) {
  console.error("safari-ios/*.xcodeproj 가 없습니다 — pipe:safari 재실행.");
  process.exit(1);
}
const projectPath = join(projectDir, project.name);

let scheme;
try {
  const list = execSync(`xcodebuild -list -project "${projectPath}"`, { encoding: "utf8" });
  scheme = list.match(/Schemes:\s*\n\s*(\S+)/)?.[1];
} catch {
  scheme = undefined;
}
if (!scheme) {
  console.error("scheme 탐지 실패 — Xcode 프로젝트 손상 가능. open safari-ios/*.xcodeproj 확인.");
  process.exit(1);
}

const archivePath = join(projectDir, `${scheme}.xcarchive`);
const ipaDir = join(projectDir, "ipa");
const exportPlist = join(projectDir, "ExportOptions.plist");
rmSync(archivePath, { recursive: true, force: true });
rmSync(ipaDir, { recursive: true, force: true });

console.log(`→ xcodebuild archive (${scheme})`);
execSync(
  `xcodebuild archive -project "${projectPath}" -scheme "${scheme}" ` +
    `-archivePath "${archivePath}" ` +
    `CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="${teamID}" ` +
    `CODE_SIGN_IDENTITY="${identity}"`,
  { stdio: "inherit" }
);

writeFileSync(
  exportPlist,
  `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n` +
    `<plist version="1.0"><dict>\n` +
    `  <key>method</key><string>app-store</string>\n` +
    `  <key>teamID</key><string>${teamID}</string>\n` +
    `  <key>uploadBitcode</key><false/>\n` +
    `  <key>uploadSymbols</key><true/>\n` +
    `</dict></plist>\n`
);

console.log("→ xcodebuild -exportArchive (.ipa)");
execSync(
  `xcodebuild -exportArchive -archivePath "${archivePath}" ` +
    `-exportOptionsPlist "${exportPlist}" -exportPath "${ipaDir}"`,
  { stdio: "inherit" }
);

console.log("✓ .ipa export: " + ipaDir);
console.log("  다음: xcrun altool --upload-app -f <ipa> -t ios (또는 Xcode 직접 업로드)");
