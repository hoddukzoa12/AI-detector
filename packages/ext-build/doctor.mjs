import path from "node:path";
import process from "node:process";

import { distDir, fileExists, logStep, manifestPath, packageJsonPath, projectRoot, publicDir, readJson } from "./lib.mjs";

const DEFAULT_ICONS = [
  "icons/icon-16.png",
  "icons/icon-32.png",
  "icons/icon-48.png",
  "icons/icon-128.png"
];

/**
 * Shared MV3 doctor. Every check that varies per extension is passed in.
 *
 * @param {object} [config]
 * @param {string[]} [config.requiredPermissions]     manifest.permissions must include these
 * @param {string[]} [config.requiredHostPermissions] manifest.host_permissions must include these
 * @param {string[]} [config.requiredIcons]           public/ icon paths that must exist
 * @param {string[]} [config.requiredArtifacts]       dist/ artifacts that must exist post-build
 * @param {(ctx: { manifest: object, packageJson: object, projectRoot: string, distDir: string, publicDir: string, manifestPath: string, fileExists: (p: string) => Promise<boolean>, problems: string[] }) => Promise<void> | void} [config.extraChecks]
 *        escape hatch for per-extension checks; push Korean messages onto ctx.problems.
 */
export async function doctor(config = {}) {
  const {
    requiredPermissions = [],
    requiredHostPermissions = [],
    requiredIcons = DEFAULT_ICONS,
    requiredArtifacts = ["manifest.json"],
    extraChecks
  } = config;

  logStep("환경 점검 시작");

  const packageJson = await readJson(packageJsonPath);
  const manifest = await readJson(manifestPath);
  const problems = [];

  if (packageJson.type !== "module") {
    problems.push("package.json 의 type 값이 module 이어야 합니다.");
  }

  if (manifest.manifest_version !== 3) {
    problems.push("manifest_version 은 3 이어야 합니다.");
  }

  for (const permission of requiredPermissions) {
    if (!manifest.permissions?.includes(permission)) {
      problems.push(`manifest 권한 누락: ${permission}`);
    }
  }

  for (const hostPermission of requiredHostPermissions) {
    if (!manifest.host_permissions?.includes(hostPermission)) {
      problems.push(`host_permissions 에 ${hostPermission} 가 필요합니다.`);
    }
  }

  for (const iconPath of requiredIcons) {
    if (!(await fileExists(path.join(publicDir, iconPath)))) {
      problems.push(`아이콘 파일 누락: public/${iconPath}`);
    }
  }

  for (const artifact of requiredArtifacts) {
    if (!(await fileExists(path.join(distDir, artifact)))) {
      problems.push(`빌드 산출물 누락: dist/${artifact} (먼저 npm run pipe:build)`);
    }
  }

  if (typeof extraChecks === "function") {
    await extraChecks({ manifest, packageJson, projectRoot, distDir, publicDir, manifestPath, fileExists, problems });
  }

  process.stdout.write(`Node: ${process.version}\n`);
  process.stdout.write(`Project: ${packageJson.name}@${packageJson.version}\n`);
  process.stdout.write(`Manifest: MV${manifest.manifest_version}\n`);

  if (problems.length > 0) {
    process.stderr.write(`\n[${packageJson.name}] 진단 실패\n`);
    for (const problem of problems) {
      process.stderr.write(`- ${problem}\n`);
    }
    process.exitCode = 1;
    return;
  }

  process.stdout.write(`\n[${packageJson.name}] 진단 통과\n`);
}

export function runDoctor(config = {}) {
  doctor(config).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
