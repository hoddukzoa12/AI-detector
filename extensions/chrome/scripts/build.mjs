import { cp, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import { runBuild } from "@vibecode/ext-build/build";

const contentScriptFiles = [
  "src/content/selector-rules-package.js",
  "src/content/text-blocks-package.js",
  "src/content/watch-package.js",
  "src/content/constants.js",
  "src/content/peek.js",
  "src/content/toast.js",
  "src/content/state.js",
  "src/content/frame-context.js",
  "src/content/site-storage.js",
  "src/content/dom-block.js",
  "src/content/text-block-runtime.js",
  "src/content/watch-runtime.js",
  "src/content/selector-engine.js",
  "src/content/ai-runtime.js",
  "src/content/ai-collector.js",
  "src/content/render-coordinator.js",
  "src/content/picker-overlay.js",
  "src/content/picker-analysis.js",
  "src/content/picker-hover.js",
  "src/content/picker-session.js",
  "src/content/picker-iframe.js",
  "src/content/picker-refine-panel.js",
  "src/content/picker-session-panel.js",
  "src/content/picker-ui.js",
  "src/content/index.js"
];

const selectorRulesPackageExports = [
  "SELECTOR_RULE_STORE_VERSION",
  "infocutterMessageTypes",
  "generateSelectorRuleId",
  "createProfileCard",
  "emptyRuleProfile",
  "emptyRuleStore",
  "normalizeRuleStore",
  "normalizeRuleProfile",
  "groupRulesByCard",
  "getEnabledRules",
  "findMatchingRuleProfile",
  "isSameStoredRule",
  "buildActiveSiteState",
  "buildStoredRule",
  "profileContainsRule",
  "upsertRuleIntoProfile",
  "appendRuleToStore",
  "readBooleanSetting",
  "hostnameMatcher",
  "hostnameFromUrl",
  "profileNameFromMatcher",
  "matcherToRegExp",
  "matchesUrl",
  "maybeStableClassName",
  "stableClasses",
  "nthOfTypeSelector",
  "isUniqueSelector",
  "simpleSelectorCandidates",
  "isUniqueAmongSiblings",
  "isBareTagSelector",
  "preferredExactSegmentSelector",
  "buildForcedUniqueSelector",
  "selectorCss"
];

const watchPackageExports = [
  "WATCH_STORAGE_VERSION",
  "emptyWatchStore",
  "createWatchTarget",
  "normalizeWatchStore",
  "watchTerms",
  "matchTerms"
];

const textBlocksPackageExports = [
  "TEXT_BLOCK_STORAGE_VERSION",
  "DEFAULT_HIDDEN_OBJECT_TAGS",
  "generateTextBlockId",
  "normalizeObjectTags",
  "parseObjectTags",
  "defaultHiddenObjectTags",
  "emptyTextBlockStore",
  "emptyTextBlockProfile",
  "normalizeTextBlockRule",
  "normalizeTextBlockProfile",
  "normalizeTextBlockStore",
  "createTextBlockRule",
  "groupTextBlockRulesByObject",
  "textBlockRuleMatchesHiddenTags",
  "findMatchingTextBlockProfile",
  "buildActiveTextBlockState",
  "updateHiddenObjectTags"
];

async function buildContentGlobalPackage(projectRoot, distDir, packageName, globalName, exportNames, targetFile) {
  const sourcePath = path.join(projectRoot, "packages", packageName, "dist/index.js");
  const targetPath = path.join(distDir, "src/content", targetFile);
  const source = await readFile(sourcePath, "utf8");
  const script = source.replace(/^export\s+/gm, "");
  await writeFile(
    targetPath,
    `globalThis.${globalName} = (() => {\n${script}\n\nreturn {\n${exportNames.map((name) => `  ${name}`).join(",\n")}\n};\n})();\n`,
    "utf8"
  );
}

runBuild({
  contentScripts: contentScriptFiles,
  transformManifest: (manifest) => {
    manifest.options_page = "options.html";
  },
  afterCopy: async ({ projectRoot, distDir }) => {
    await mkdir(path.join(distDir, "vendor"), { recursive: true });
    await cp(path.join(projectRoot, "vendor/jspdf.js"), path.join(distDir, "vendor/jspdf.js"));
    await buildContentGlobalPackage(
      projectRoot,
      distDir,
      "infocutter-selector-rules",
      "InfocutterSelectorRules",
      selectorRulesPackageExports,
      "selector-rules-package.js"
    );
    await buildContentGlobalPackage(
      projectRoot,
      distDir,
      "infocutter-text-blocks",
      "InfocutterTextBlocks",
      textBlocksPackageExports,
      "text-blocks-package.js"
    );
    await buildContentGlobalPackage(
      projectRoot,
      distDir,
      "infocutter-watch",
      "InfocutterWatch",
      watchPackageExports,
      "watch-package.js"
    );
  }
});
