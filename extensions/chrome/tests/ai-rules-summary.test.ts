import test from "node:test";
import assert from "node:assert/strict";

import { summarizeAiRules } from "../src/options/ai-rules-summary.js";
import type { AiRuleStore } from "../src/shared/ai-types.js";

const store: AiRuleStore = {
  version: 1,
  settings: { globalEnabled: true, enabledCategories: ["sexual", "violence"] },
  sites: [
    {
      id: "s1", matchers: ["https://a.com/*"], enabled: true, generatedAt: "t",
      rules: [
        { id: "r1", selector: "#a", enabled: true, category: "sexual", reason: "", confidence: 0.9, model: "m", createdAt: "t" },
        { id: "r2", selector: "#b", enabled: false, category: "violence", reason: "", confidence: 0.8, model: "m", createdAt: "t" }
      ]
    },
    {
      id: "s2", matchers: ["https://b.com/*"], enabled: true, generatedAt: "t",
      rules: [
        { id: "r3", selector: "#c", enabled: true, category: "sexual", reason: "", confidence: 0.7, model: "m", createdAt: "t" }
      ]
    }
  ]
};

void test("summarizeAiRules counts sites, rules, and per-category totals", () => {
  const summary = summarizeAiRules(store);
  assert.equal(summary.totalSites, 2);
  assert.equal(summary.totalRules, 3);
  assert.equal(summary.byCategory.sexual, 2);
  assert.equal(summary.byCategory.violence, 1);
  assert.equal(summary.byCategory.gore, 0);
});
