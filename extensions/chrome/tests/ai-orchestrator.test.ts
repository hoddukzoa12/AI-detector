import test from "node:test";
import assert from "node:assert/strict";

import { decideAiAnalysis } from "../src/shared/ai-orchestrator.js";
import type { AiConfig } from "../src/shared/ai-config.js";
import type { AiRuleStore, AiRuleCategory } from "../src/shared/ai-types.js";

const baseConfig: AiConfig = { endpoint: "e", apiKey: "k", model: "m", analyzedHosts: [] };
const cats: AiRuleCategory[] = ["sexual"];
const baseStore: AiRuleStore = { version: 1, settings: { globalEnabled: true, enabledCategories: cats }, sites: [] };

void test("decideAiAnalysis proceeds when configured + enabled + has categories", () => {
  const d = decideAiAnalysis(baseConfig, baseStore);
  assert.ok(d.proceed);
  assert.deepEqual(d.categories, ["sexual"]);
  assert.equal(d.model, "m");
});

void test("decideAiAnalysis skips with blank api key", () => {
  const d = decideAiAnalysis({ ...baseConfig, apiKey: "   " }, baseStore);
  assert.ok(!d.proceed);
  assert.equal(d.reason, "no-api-key");
});

void test("decideAiAnalysis skips when globally disabled", () => {
  const d = decideAiAnalysis(baseConfig, { ...baseStore, settings: { globalEnabled: false, enabledCategories: cats } });
  assert.ok(!d.proceed);
  assert.equal(d.reason, "disabled");
});

void test("decideAiAnalysis skips with no enabled categories", () => {
  const empty: AiRuleCategory[] = [];
  const d = decideAiAnalysis(baseConfig, { ...baseStore, settings: { globalEnabled: true, enabledCategories: empty } });
  assert.ok(!d.proceed);
  assert.equal(d.reason, "no-categories");
});
