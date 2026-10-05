# @vibecode/ext-runtime

Shared MV3 runtime scaffolding for the vibecode Chrome extensions:

- `i18n.ts` — `t(key, fallback)` over `chrome.i18n.getMessage` (byte-identical
  across extensions).
- `settings-store.ts` — `createSettingsStore<T>({ storageKey, normalize })`: the
  generic `chrome.storage` get / set / normalize / update plumbing. Each
  extension keeps only its own schema + `normalize`.
- `runtime-client.ts` — `sendRuntimeMessage<Req, Res>()` + `isExtensionContextValid()`.
- `messaging.ts` — `createMessageBus()`, a typed background handler registry
  wrapping the `{ ok, data, error }` envelope.

## SSOT + sync (why copies exist)

`packages/ext-runtime/src` is the single source of truth. Unlike a Node build
tool, this code runs in the browser from each extension's own tsc/esbuild
output, and an unbundled MV3 popup/service-worker can't resolve a bare
`@vibecode/ext-runtime` specifier. So each consumer keeps an in-tree copy at
`<extension>/packages/ext-runtime/src` (matching the repo's existing
`packages/*` + `sync-packages-dist` convention) imported by relative path:

```ts
export { t } from "../../packages/ext-runtime/src/i18n.js";
import { createSettingsStore } from "../../packages/ext-runtime/src/settings-store.js";
```

After editing the SSOT, refresh every consumer:

```bash
node packages/ext-runtime/sync-consumers.mjs
```

Each consumer also self-heals its copy on build: `pipe:build` runs
`pipe:sync-shared` (`scripts/sync-shared.mjs`) first, which re-copies the
repo-root SSOT into that extension's `packages/ext-runtime/src` before tsc. So a
stale or hand-edited copy can never reach a build — the SSOT always wins.

## Migrated

- `vibecode-chrome-extension-seo-check` — `src/shared/i18n.ts`, `src/shared/storage.ts` (settings scaffold), `src/shared/runtime-client.ts` (envelope unwrap + `isExtensionContextValid`).
- `vibecode-chrome-extension-youtube-evaluator` — same three.

## Not adopted (deliberately): the background message router

`createMessageBus` ships here but the two extensions keep their own
`src/background/message-router.ts`. Their router's `on<T>(type, handler)`
overload binds each handler's **payload and return type** to the message type
via the per-extension `AnyRequest` union + `ResponseOf<R>` conditional, and their
`sendRuntimeMessage<R extends AnyRequest>` returns the exact `ResponseOf<R>`.
A generic bus can't express that request→response mapping without either losing
the typing or duplicating it as a hand-written `Record` map — so the
domain-typed router is genuinely better per-extension and stays. The shared
`runtime-client` (envelope shape, unwrap, context-valid check) *is* adopted; the
per-ext `sendRuntimeMessage` is now a thin typed wrapper delegating to it.
