import test from "node:test";
import assert from "node:assert/strict";

import { buildEvidencePdf } from "../src/evidence/pdf-builder.js";
import type { JsPdfLike } from "../src/evidence/pdf-builder.js";

function mockDoc(pageHeight = 800): { doc: JsPdfLike; text: string[]; addPages: { count: number } } {
  const text: string[] = [];
  const addPages = { count: 0 };
  const doc: JsPdfLike = {
    internal: { pageSize: { getWidth: () => 600, getHeight: () => pageHeight } },
    setFontSize: () => undefined,
    text: (input) => {
      text.push(input);
    },
    splitTextToSize: (t) => (t.length > 60 ? t.match(/.{1,60}/g) ?? [t] : [t]),
    addPage: () => {
      addPages.count += 1;
    },
    output: () => "data:application/pdf;base64,JVBERi0=",
  };
  return { doc, text, addPages };
}

void test("buildEvidencePdf returns base64 (data uri 접미사 제외)", () => {
  const { doc } = mockDoc();
  const out = buildEvidencePdf(
    { url: "https://example.com/a", pageTitle: "예제", capturedAt: "2026-08-09T00:00:00Z" },
    "본문.",
    doc
  );
  assert.equal(out, "JVBERi0=");
});

void test("메타(제목·URL·캡처시각·매치·해시) 가 모두 기록된다", () => {
  const { doc, text } = mockDoc();
  buildEvidencePdf(
    {
      url: "https://example.com/a",
      pageTitle: "예제 페이지",
      capturedAt: "2026-08-09T00:00:00Z",
      matchedTerm: "foo",
      hash: "abc123",
    },
    "x",
    doc
  );
  assert.ok(text.some((t) => t.includes("예제 페이지")));
  assert.ok(text.some((t) => t.includes("example.com")));
  assert.ok(text.some((t) => t.includes("2026-08-09")));
  assert.ok(text.some((t) => t.includes("foo")));
  assert.ok(text.some((t) => t.includes("abc123")));
});

void test("본문이 페이지를 넘기면 addPage 가 호출된다", () => {
  const { doc, addPages } = mockDoc(200);
  buildEvidencePdf(
    { url: "u", pageTitle: "p", capturedAt: "now" },
    "y".repeat(2000),
    doc
  );
  assert.ok(addPages.count > 0);
});
