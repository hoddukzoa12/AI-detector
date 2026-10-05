#!/usr/bin/env node
/**
 * SSOT sync for @vibecode/ext-runtime.
 *
 * The runtime scaffold is loaded at browser runtime from each extension's own
 * tsc/esbuild output, so the shared source must live in-tree per consumer
 * (bare specifiers can't resolve in an unbundled MV3 popup/service-worker).
 * packages/ext-runtime/src is the single source of truth; run this script
 * after editing it to refresh every consumer's packages/ext-runtime/src.
 *
 * Usage: node packages/ext-runtime/sync-consumers.mjs
 */

import { cp, mkdir, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const packageDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(packageDir, "..", "..");
const sourceSrc = path.join(packageDir, "src");
const sourcePkgJson = path.join(packageDir, "package.json");

const consumers = [
  "vibecode-chrome-extension-seo-check",
  "vibecode-chrome-extension-youtube-evaluator"
];

async function main() {
  await Promise.all(consumers.map(async (consumer) => {
    const target = path.join(repoRoot, consumer, "packages", "ext-runtime");
    await rm(path.join(target, "src"), { force: true, recursive: true });
    await mkdir(target, { recursive: true });
    await cp(sourceSrc, path.join(target, "src"), { recursive: true });
    await cp(sourcePkgJson, path.join(target, "package.json"));
    process.stdout.write(`synced -> ${consumer}/packages/ext-runtime\n`);
  }));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
