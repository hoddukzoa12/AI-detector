import test from "node:test";
import assert from "node:assert/strict";

import { findMatchingAiSite, normalizeAiRuleStore } from "../src/shared/ai-rule-storage.js";

void test("normalizeAiRuleStore returns an empty v1 store for unknown input", () => {
  const store = normalizeAiRuleStore(undefined);
  assert.equal(store.version, 1);
  assert.equal(store.settings.globalEnabled, true);
  assert.deepEqual(store.sites, []);
});

void test("normalizeAiRuleStore coerces an unknown category to 'other' and drops selectorless rules", () => {
  const store = normalizeAiRuleStore({
    version: 1,
    settings: { globalEnabled: false },
    sites: [{
      id: "s1",
      matchers: ["https://example.com/*"],
      enabled: true,
      generatedAt: "2026-05-30T00:00:00.000Z",
      rules: [
        { id: "r1", selector: ".ad", enabled: true, category: "nonsense", reason: "x", confidence: 0.9, model: "m", createdAt: "t" },
        { id: "r2", enabled: true }
      ]
    }]
  });
  assert.equal(store.settings.globalEnabled, false);
  assert.equal(store.sites.length, 1);
  const site = store.sites[0];
  assert.ok(site);
  assert.equal(site.rules.length, 1);
  const rule = site.rules[0];
  assert.ok(rule);
  assert.equal(rule.category, "other");
});

void test("findMatchingAiSite matches by URL matcher", () => {
  const store = normalizeAiRuleStore({
    version: 1,
    settings: { globalEnabled: true },
    sites: [{ id: "s1", matchers: ["https://example.com/*"], enabled: true, generatedAt: "t", rules: [] }]
  });
  assert.equal(findMatchingAiSite(store, "https://example.com/page")?.id, "s1");
  assert.equal(findMatchingAiSite(store, "https://other.com/")?.id, undefined);
});

void test("normalizeAiRuleStore defaults enabledCategories to all categories and filters unknown ones", () => {
  const def = normalizeAiRuleStore(undefined);
  assert.equal(def.settings.enabledCategories.length, 6);

  const narrowed = normalizeAiRuleStore({
    version: 1,
    settings: { globalEnabled: true, enabledCategories: ["sexual", "nonsense"] },
    sites: []
  });
  assert.deepEqual(narrowed.settings.enabledCategories, ["sexual"]);
});
