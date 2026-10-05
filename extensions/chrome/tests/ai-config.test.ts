import test from "node:test";
import assert from "node:assert/strict";

import { isHostAnalyzed, normalizeAiConfig } from "../src/shared/ai-config.js";

void test("normalizeAiConfig fills defaults for unknown input", () => {
  const config = normalizeAiConfig(undefined);
  assert.equal(config.endpoint, "https://llm.ranode.net/v1");
  assert.equal(config.apiKey, "");
  assert.equal(config.model, "");
  assert.deepEqual(config.analyzedHosts, []);
});

void test("isHostAnalyzed reflects the analyzedHosts list", () => {
  const config = normalizeAiConfig({ endpoint: "x", apiKey: "k", model: "m", analyzedHosts: ["example.com"] });
  assert.equal(isHostAnalyzed(config, "example.com"), true);
  assert.equal(isHostAnalyzed(config, "other.com"), false);
});
