import test from "node:test";
import assert from "node:assert/strict";

import { buildAiDetectionPrompt, parseAiDetectionResponse } from "../src/shared/ai-llm-client.js";

void test("buildAiDetectionPrompt includes the enabled categories and block selectors", () => {
  const prompt = buildAiDetectionPrompt(
    [{ selector: "#ad1", text: "광고", imageAlt: "", imageSrc: "" }],
    ["sexual", "violence"]
  );
  assert.ok(prompt.includes("sexual"));
  assert.ok(prompt.includes("violence"));
  assert.ok(prompt.includes("#ad1"));
  assert.ok(prompt.toUpperCase().includes("JSON"));
});

void test("parseAiDetectionResponse extracts a JSON array, coerces category, drops malformed", () => {
  const body = "여기 결과입니다:\n```json\n[" +
    '{"selector":"#ad1","category":"sexual","reason":"r","confidence":0.9},' +
    '{"selector":"#ad2","category":"weird","reason":"r","confidence":0.7},' +
    '{"category":"gore","reason":"no selector","confidence":0.8}' +
    "]\n```";
  const result = parseAiDetectionResponse(body);
  assert.equal(result.length, 2);
  const first = result[0];
  const second = result[1];
  assert.ok(first);
  assert.ok(second);
  assert.equal(first.category, "sexual");
  assert.equal(second.category, "other");
  assert.equal(second.selector, "#ad2");
});

void test("parseAiDetectionResponse clamps confidence into [0,1] and zeroes non-finite", () => {
  const body = "[" +
    '{"selector":"#a","category":"sexual","reason":"r","confidence":5},' +
    '{"selector":"#b","category":"gore","reason":"r","confidence":-0.5},' +
    '{"selector":"#c","category":"hate","reason":"r","confidence":0.42}' +
    "]";
  const result = parseAiDetectionResponse(body);
  const a = result[0]; assert.ok(a); assert.equal(a.confidence, 1);
  const b = result[1]; assert.ok(b); assert.equal(b.confidence, 0);
  const c = result[2]; assert.ok(c); assert.equal(c.confidence, 0.42);
});
