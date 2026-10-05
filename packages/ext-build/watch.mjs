import { spawn } from "node:child_process";
import process from "node:process";

import { logStep, projectRoot, run } from "./lib.mjs";

export async function watch() {
  logStep("watch 모드 시작 — Ctrl+C 로 종료");
  await run("npm", ["run", "pipe:build"]);

  const tsc = spawn("npx", ["tsc", "-p", "tsconfig.json", "--watch", "--preserveWatchOutput"], {
    cwd: projectRoot,
    stdio: "inherit",
    shell: false
  });

  const handleExit = () => {
    if (!tsc.killed) {
      tsc.kill("SIGTERM");
    }
  };
  process.on("SIGINT", handleExit);
  process.on("SIGTERM", handleExit);

  tsc.on("exit", (code) => {
    process.exitCode = code ?? 0;
  });
}

export function runWatch() {
  watch().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
