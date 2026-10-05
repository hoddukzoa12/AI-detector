import { cp, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const DEFAULT_ICON = { "16": "icons/icon-16.png", "32": "icons/icon-32.png" };
const DEFAULT_ICONS = {
  "16": "icons/icon-16.png",
  "32": "icons/icon-32.png",
  "48": "icons/icon-48.png",
  "128": "icons/icon-128.png"
};

/**
 * Shared MV3 build step: copy public/ into dist/ and rewrite the manifest so it
 * points at the compiled JS. Every field is configurable so each extension only
 * passes what differs from the defaults.
 *
 * @param {object} [config]
 * @param {string} [config.serviceWorker]  manifest.background.service_worker
 * @param {string} [config.defaultPopup]   manifest.action.default_popup
 * @param {object} [config.defaultIcon]    manifest.action.default_icon
 * @param {object} [config.icons]          manifest.icons
 * @param {string[]} [config.contentScripts] manifest.content_scripts[0].js (skipped when absent)
 * @param {(ctx: { projectRoot: string, distDir: string, publicDir: string }) => Promise<void> | void} [config.afterCopy]
 *        runs after public/ is copied into dist/ and before the manifest is read/written.
 *        Escape hatch for per-extension asset steps (vendor copies, content-package bundling, ...).
 * @param {(manifest: object) => void} [config.transformManifest] escape hatch for anything else
 */
export async function build(config = {}) {
  const {
    serviceWorker = "src/background/service-worker.js",
    defaultPopup = "popup.html",
    defaultIcon = DEFAULT_ICON,
    icons = DEFAULT_ICONS,
    contentScripts,
    afterCopy,
    transformManifest
  } = config;

  const projectRoot = process.cwd();
  const distDir = path.join(projectRoot, "dist");
  const publicDir = path.join(projectRoot, "public");

  await mkdir(distDir, { recursive: true });
  await cp(publicDir, distDir, { recursive: true });

  if (typeof afterCopy === "function") {
    await afterCopy({ projectRoot, distDir, publicDir });
  }

  const manifestPath = path.join(distDir, "manifest.json");
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));

  if (manifest.background) {
    manifest.background.service_worker = serviceWorker;
  }
  if (manifest.action) {
    manifest.action.default_popup = defaultPopup;
    manifest.action.default_icon = defaultIcon;
  }
  manifest.icons = icons;

  if (Array.isArray(contentScripts) && Array.isArray(manifest.content_scripts)) {
    manifest.content_scripts[0].js = contentScripts;
  }

  if (typeof transformManifest === "function") {
    transformManifest(manifest);
  }

  await writeFile(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
}

/**
 * Run build(config) as a script entry point, mirroring the previous per-extension
 * build.mjs error handling.
 */
export function runBuild(config = {}) {
  build(config).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
