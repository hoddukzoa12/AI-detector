import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { chromium, type Browser } from 'playwright';
import type { CollectedPage } from '../../src/core/types.js';
import { captureDocument } from '../../src/dom/index.js';
import { detectPage } from '../../src/detection/index.js';

let browser: Browser;
beforeAll(async () => {
  browser = await chromium.launch({ executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath() });
});
afterAll(async () => { await browser?.close(); });

const raw = '카지노 가입 지금 방문 보너스';
async function capture(body: string) {
  const page = await browser.newPage();
  try {
    await page.setContent(`<!doctype html><html><body>${body}</body></html>`);
    const beforeHtml = await page.content();
    const observed = await page.locator('[id]').evaluateAll(elements => elements.map(element => ({
      location: '#' + element.id, color: getComputedStyle(element).color,
      fontSize: getComputedStyle(element).fontSize,
    })));
    const captured = await page.evaluate(captureDocument, { framePath: [], maxElements: 1000, maxHtmlBytes: 1000000 });
    expect(await page.content()).toBe(beforeHtml);
    const input: CollectedPage = {
      url: 'https://public.example/direct-owners', capturedAt: '2026-10-04T00:00:00Z', discoveredUrls: captured.discoveredUrls,
      frames: [{ ...captured, frameUrl: page.url(), framePath: [], snapshotId: 'direct-owner-snapshot', capturedAt: '2026-10-04T00:00:00Z' }],
    };
    const original = structuredClone(input);
    const candidates = detectPage(input);
    expect(input).toEqual(original);
    expect(await page.content()).toBe(beforeHtml);
    expect(await page.locator('[id]').evaluateAll(elements => elements.map(element => ({
      location: '#' + element.id, color: getComputedStyle(element).color,
      fontSize: getComputedStyle(element).fontSize,
    })))).toEqual(observed);
    for (const owner of captured.elements) {
      const style = observed.find(element => element.location === owner.location)!;
      expect(owner.styles[0].elementLocation).toBe(owner.location);
      expect(owner.styles[0].css.color).toBe(style.color);
      expect(owner.styles[0].css['font-size']).toBe(style.fontSize);
    }
    return { input, candidates, elements: captured.elements };
  } finally { await page.close(); }
}

describe('actual direct text owners from Chromium capture to detector', () => {
  it.each([
    { style: 'color:transparent', visibleStyle: 'color:black', technique: 'TRANSPARENT' },
    { style: 'font-size:0', visibleStyle: 'font-size:16px', technique: 'OFFSCREEN' },
  ])('keeps a $technique parent whose direct text repeats its visible child', async ({ style, visibleStyle, technique }) => {
    const { input, candidates, elements } = await capture(`<div id="parent" style="${style}">${raw}<span id="child" style="${visibleStyle}">${raw}</span></div>`);
    expect(elements.map(owner => [owner.location, owner.rawText])).toEqual([['#parent', raw], ['#child', raw]]);
    expect(elements[1].styles[1].elementLocation).toBe('#parent');
    expect(candidates.map(candidate => ({ url: candidate.url, location: candidate.location, rawText: candidate.rawText, techniques: candidate.techniques }))).toEqual([
      { url: input.url, location: '#parent', rawText: raw, techniques: [technique] },
    ]);
    expect(candidates[0].observationIds.length).toBeGreaterThan(0);
  });

  it('keeps identical direct text in hidden parent, child and sibling; repeated captures merge only the same owner', async () => {
    const { input, candidates, elements } = await capture(`<div id="parent" style="color:transparent">${raw}<span id="child">${raw}</span></div><p id="sibling" style="color:transparent">${raw}</p>`);
    expect(elements.map(owner => [owner.location, owner.rawText])).toEqual([['#parent', raw], ['#child', raw], ['#sibling', raw]]);
    expect(candidates.map(candidate => [candidate.location, candidate.rawText, candidate.techniques])).toEqual([
      ['#parent', raw, ['TRANSPARENT']], ['#child', raw, ['TRANSPARENT']], ['#sibling', raw, ['TRANSPARENT']],
    ]);
    expect(new Set(candidates.map(candidate => candidate.candidateId)).size).toBe(3);
    const repeated = structuredClone(input);
    repeated.frames[0].elements.push(...structuredClone(elements));
    expect(detectPage(repeated)).toEqual(candidates);
  });

  it('captures an aggregate-only parent through its leaves without double counting its descendant text', async () => {
    const { candidates, elements } = await capture(`<div id="aggregate" style="opacity:0"><span id="one">${raw}</span><span id="two">${raw}</span></div>`);
    expect(elements.map(owner => [owner.location, owner.rawText])).toEqual([['#one', raw], ['#two', raw]]);
    expect(elements.every(owner => owner.styles[1].elementLocation === '#aggregate')).toBe(true);
    expect(candidates.map(candidate => [candidate.location, candidate.rawText, candidate.techniques])).toEqual([
      ['#one', raw, ['TRANSPARENT']], ['#two', raw, ['TRANSPARENT']],
    ]);
  });

  it('preserves separate direct fragments and normal visible same-text controls', async () => {
    const { candidates, elements } = await capture(`<div id="mixed" style="color:transparent"> ${raw}<span id="visible-child" style="color:black">${raw}</span> ${raw} </div><p id="visible">${raw}</p>`);
    expect(elements.map(owner => [owner.location, owner.rawText])).toEqual([
      ['#mixed', ` ${raw} ${raw} `], ['#visible-child', raw], ['#visible', raw],
    ]);
    expect(candidates.map(candidate => [candidate.location, candidate.rawText, candidate.techniques])).toEqual([
      ['#mixed', ` ${raw} ${raw} `, ['TRANSPARENT']],
    ]);
  });
});
