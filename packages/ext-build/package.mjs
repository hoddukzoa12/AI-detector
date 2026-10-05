import { mkdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { distDir, logStep, packageDir, packageJsonPath, readJson, run } from "./lib.mjs";

export async function packageExtension() {
  const packageJson = await readJson(packageJsonPath);
  const version = packageJson.version;
  const name = packageJson.name;
  const archive = path.join(packageDir, `${name}-v${version}.zip`);

  logStep(`패키지 생성: ${archive}`);
  await mkdir(packageDir, { recursive: true });
  await run("zip", ["-r", "-X", archive, "."], { cwd: distDir });
}

export function runPackage() {
  packageExtension().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
