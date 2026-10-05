# @vibecode/ext-build

Shared MV3 build pipeline for the vibecode Chrome extensions. Replaces the
copy-pasted `scripts/{lib,build,dev,doctor,watch,package}.mjs` with one
parameterized module. The log tag is derived from the consumer's
`package.json` name, so output stays per-extension without per-extension code.

## Consume it

Add a dependency (no root workspace exists, so use a relative `file:` link):

```jsonc
// <extension>/package.json
"dependencies": { "@vibecode/ext-build": "file:../packages/ext-build" }
```

`npm install` links it into `node_modules`. Each `scripts/*.mjs` becomes a thin
wrapper:

```js
// scripts/build.mjs
import { runBuild } from "@vibecode/ext-build/build";
runBuild({ contentScripts: [/* only if the manifest has content_scripts */] });

// scripts/doctor.mjs
import { runDoctor } from "@vibecode/ext-build/doctor";
runDoctor({
  requiredPermissions: ["storage", "activeTab", "scripting"],
  requiredHostPermissions: ["<all_urls>"],   // optional
  requiredArtifacts: ["manifest.json", /* ... */] // optional, defaults to manifest.json
});

// scripts/{dev,watch,package}.mjs
import { runDev }     from "@vibecode/ext-build/dev";     runDev();
import { runWatch }   from "@vibecode/ext-build/watch";   runWatch();
import { runPackage } from "@vibecode/ext-build/package"; runPackage();
```

`build(config)` defaults (service worker, popup, icon set) match every current
consumer; pass only what differs:

- `contentScripts` — sets `content_scripts[0].js` (skipped if the manifest has none).
- `transformManifest(manifest)` — mutate any other manifest field (e.g. `options_ui.page`, `options_page`).
- `afterCopy({ projectRoot, distDir, publicDir })` — runs after `public/` is copied
  into `dist/` and before the manifest is written; the escape hatch for bespoke
  asset steps (vendor copies, content-package IIFE bundling). infocutter uses this.

`doctor(config)` likewise takes an `extraChecks({ manifest, packageJson, projectRoot,
distDir, publicDir, fileExists, problems })` hook — push Korean problem messages onto
`problems` for per-extension checks (extra public files, `options_page`,
`web_accessible_resources`, ...). seo-check and youtube-evaluator use it.

Some consumers keep a bespoke `dev`/`watch`/`package.mjs` (custom messages, zip
naming) but still import the shared `run`/`logStep`/`distDir`/... from
`@vibecode/ext-build/lib` instead of a local `lib.mjs`.

## Migrated

- `vibecode-chrome-extension-block-selector`
- `vibecode-chrome-extension-page-saver`
- `vibecode-chrome-extension-screen-capture` — `transformManifest` sets `options_ui.page`.
- `vibecode-chrome-extension-infocutter` — `afterCopy` copies `vendor/jspdf.js` and
  builds the three `globalThis.Infocutter*` content packages; `transformManifest`
  sets `options_page`. Output is byte-identical to its former standalone build.
- `vibecode-chrome-extension-seo-check` — `transformManifest` sets `options_page`;
  `doctor` uses `extraChecks` (options/archive html, `web_accessible_resources`);
  keeps a bespoke `watch`/`package.mjs` importing from `@vibecode/ext-build/lib`.
- `vibecode-chrome-extension-youtube-evaluator` — same shape;
  `requiredHostPermissions` for the YouTube/API hosts, `extraChecks` for popup/options html.

`gaya-capture` has no build pipeline (a no-build MV3 extension), so nothing to migrate.
