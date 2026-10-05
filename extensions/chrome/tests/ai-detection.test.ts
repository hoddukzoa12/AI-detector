import test from "node:test";
import assert from "node:assert/strict";

import { filterDetections } from "../src/shared/ai-detection.js";

void test("filterDetections keeps only enabled categories above the threshold", () => {
  const detections = [
    { selector: "#a", category: "sexual" as const, reason: "", confidence: 0.9 },
    { selector: "#b", category: "violence" as const, reason: "", confidence: 0.5 },
    { selector: "#c", category: "gore" as const, reason: "", confidence: 0.95 }
  ];
  const kept = filterDetections(detections, ["sexual", "violence"], 0.6);
  assert.deepEqual(kept.map((d) => d.selector), ["#a"]);
});
