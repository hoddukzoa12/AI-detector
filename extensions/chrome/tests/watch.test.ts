import test from "node:test";
import assert from "node:assert/strict";

import {
  WATCH_STORAGE_VERSION,
  createWatchTarget,
  emptyWatchStore,
  normalizeWatchStore,
  watchTerms,
  matchTerms
} from "../packages/infocutter-watch/src/index.js";
import { applyWatchMutation } from "../src/shared/watch-storage.js";

void test("emptyWatchStore returns versioned empty store", () => {
  const store = emptyWatchStore();
  assert.equal(store.version, WATCH_STORAGE_VERSION);
  assert.equal(store.settings.globalEnabled, true);
  assert.equal(store.settings.autoMask, true);
  assert.deepEqual(store.targets, []);
});

void test("createWatchTarget normalizes name and aliases", () => {
  const target = createWatchTarget({ name: "  김철순 ", aliases: ["철순", "  ", "철순"] });
  assert.equal(target.name, "김철순");
  assert.deepEqual(target.aliases, ["철순"]);
  assert.equal(target.enabled, true);
  assert.equal(typeof target.id, "string");
  assert.ok(target.id.length > 0);
});

void test("normalizeWatchStore drops invalid targets and coerces settings", () => {
  const store = normalizeWatchStore({
    version: 1,
    settings: { globalEnabled: false, autoMask: "nope" },
    targets: [
      { id: "a", name: "김철순", aliases: ["철순"], enabled: true, createdAt: "x", updatedAt: "y" },
      { id: "b", name: "", aliases: [] },
      "garbage"
    ]
  });
  assert.equal(store.settings.globalEnabled, false);
  assert.equal(store.settings.autoMask, true);
  assert.equal(store.targets.length, 1);
  assert.equal(store.targets[0]?.name, "김철순");
});

void test("watchTerms excludes disabled targets and short terms", () => {
  const store = normalizeWatchStore({
    targets: [
      { name: "김철순", aliases: ["철", "철순이"], enabled: true },
      { name: "이영희", aliases: [], enabled: false }
    ]
  });
  const terms = watchTerms(store);
  assert.ok(terms.includes("김철순"));
  assert.ok(terms.includes("철순이"));
  assert.ok(!terms.includes("철"), "1글자 별칭은 제외");
  assert.ok(!terms.includes("이영희"), "비활성 대상 제외");
});

void test("matchTerms returns matched term via substring, case/space-insensitive", () => {
  const terms = watchTerms(normalizeWatchStore({ targets: [{ name: "김철순", aliases: [] }] }));
  assert.equal(matchTerms("어제  김철순 씨가", terms), "김철순");
  assert.equal(matchTerms("관계 없는 문장", terms), null);
});

void test("applyWatchMutation add/toggle/remove target", () => {
  let store = emptyWatchStore();
  store = applyWatchMutation(store, { kind: "add", name: "김철순", aliases: ["철순이"] });
  assert.equal(store.targets.length, 1);
  const added = store.targets[0];
  assert.ok(added);
  const id = added.id;

  store = applyWatchMutation(store, { kind: "toggle", id, enabled: false });
  assert.equal(store.targets[0]?.enabled, false);

  store = applyWatchMutation(store, { kind: "setGlobalEnabled", enabled: false });
  assert.equal(store.settings.globalEnabled, false);

  store = applyWatchMutation(store, { kind: "remove", id });
  assert.equal(store.targets.length, 0);
});
