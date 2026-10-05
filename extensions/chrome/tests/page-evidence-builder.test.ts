import test from "node:test";
import assert from "node:assert/strict";

import { buildEvidenceInPage } from "../src/evidence/page-evidence-builder.js";

const META = {
  capturedAt: "2026-08-10T00:00:00Z",
  htmlExcerpt: "x",
  matchedTerm: "foo",
  pageTitle: "p",
  url: "https://example.com/a"
};

void test("페이지가 픽셀 한도를 초과하면 canvas 생성 없이 ok:false 를 낸다", async () => {
  const result = await buildEvidenceInPage({
    dpr: 1,
    meta: META,
    tiles: [],
    totalHeight: 100000,
    totalWidth: 100000
  });
  assert.equal(result.ok, false);
  assert.match(result.error ?? "", /너무 커/);
});

void test("dpr 0 은 1 로 정규화돼도 한도 초과 판정에 영향을 주지 않는다", async () => {
  const result = await buildEvidenceInPage({
    dpr: 0,
    meta: META,
    tiles: [],
    totalHeight: 100000,
    totalWidth: 100000
  });
  assert.equal(result.ok, false);
});
