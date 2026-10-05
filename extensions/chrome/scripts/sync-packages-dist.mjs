import { cp, mkdir, rm } from "node:fs/promises";
import path from "node:path";

const projectRoot = process.cwd();
const packageNames = ["infocutter-text-blocks", "infocutter-selector-rules", "infocutter-filter-importer", "infocutter-watch"];

async function main() {
  await Promise.all(packageNames.map(async (packageName) => {
    const packageRoot = path.join(projectRoot, "packages", packageName);
    const sourceDir = path.join(projectRoot, "packages-dist", packageName, "src");
    const targetDir = path.join(packageRoot, "dist");

    await rm(targetDir, { force: true, recursive: true });
    await mkdir(targetDir, { recursive: true });
    await cp(sourceDir, targetDir, { recursive: true });
  }));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
