import { afterAll, beforeAll, expect, it } from 'vitest';
import { chromium } from 'playwright';
import { crawl, type CollectedPageWithImages } from '../../src/crawler/index.js';
import { detectImageCandidates, detectPage } from '../../src/detection/index.js';
import { analyzeCandidate, countStateTokens, planCandidateChunks } from '../../src/classification/index.js';
import { classifyAiAnalysis, type OcrImageOccurrence } from '../../src/core/index.js';
import { startOcrFixtureSite, type OcrFixtureSite } from '../fixtures/ocr-site.js';
import { assetTruth, imageTruth, menuTruth } from '../fixtures/ocr-truth.js';
let site: OcrFixtureSite;
beforeAll(async () => { site = await startOcrFixtureSite(); });
afterAll(async () => { await site.stop(); });
const options = { executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath(), maxPages: 1, dynamicWaitMs: 200, resourceWaitMs: 300, scrollSteps: 0 };
const answer = (choice: string) => ({ model: 'cloudflare/clef', answers: { ad_class: { type: 'choice', choice, confidence: .9,
  probabilities: Object.fromEntries(['illegal_ad', 'general_ad', 'non_ad', 'uncertain'].map(k => [k, k === choice ? .9 : .1 / 3])) } }, usage: { input_tokens: 5, output_tokens: 1 } });

it('sends 22 menu title observations without unrelated links while preserving five direct positives through actual T2 collection', async () => {
  const result = await crawl(site.urls.menu, options); expect(result.state).toBe('partial'); // maxPages=1 retains unvisited owned links.
  const page = result.pages[0]; const before = structuredClone(page); const candidates = detectPage(page);
  for (const truth of menuTruth) {
    const candidate = candidates.find(c => c.location === truth.selector)!; expect(candidate).toBeDefined();
    expect(candidate.rawText).toBe(truth.rawText); expect(candidate.techniques).toEqual([truth.technique]);
    expect(candidate.links).toEqual(truth.relatedHref ? [site.origin + truth.relatedHref] : []);
    const ai = await analyzeCandidate(candidate, 'unit-test-placeholder', new AbortController().signal, { fetch: async (_url, init) => {
      const body = JSON.parse(init!.body as string);
      expect(body.state).toEqual({ rawText: truth.rawText, normalizedText: candidate.normalizedText, links: candidate.links });
      expect(Object.keys(body.state)).toEqual(['rawText', 'normalizedText', 'links']);
      expect(countStateTokens(body.state)).toBeLessThanOrEqual(1500);
      return new Response(JSON.stringify(answer(truth.label)));
    } });
    expect(classifyAiAnalysis(ai).confirmed).toBe(truth.label === 'illegal_ad');
  }
  expect(candidates.filter(c => /^(MEMBER|MENU)$/u.test(c.rawText))).toHaveLength(22);
  expect(page).toEqual(before);
}, 15000);

it('builds owner OCR groups from actual collected image layers with independent authored extraction strings', async () => {
  let page: CollectedPageWithImages | undefined;
  await crawl(site.urls.images, { ...options, images: { enabled: false, onImage() {} }, onPage(captured) { page = captured; } });
  expect(page).toBeDefined();
  const collected = page!.images!; const images: OcrImageOccurrence[] = [];
  expect(collected).toHaveLength(imageTruth.length);
  for (const owner of collected) {
    const truth = imageTruth.find(t => owner.location.endsWith(t.selector) && owner.framePath.length === t.framePath.length && owner.framePath.every((path, index) => path.includes(t.framePath[index]!.replace('iframe#', '#')) || (t.framePath[index] === 'iframe#external' && path.includes(site.externalOrigin + '/frames/external')) || (t.framePath[index] === 'iframe#nested' && path.includes(site.externalOrigin + '/frames/nested'))) && owner.sourceKind === t.sourceKind && owner.sourceIndex === t.sourceIndex)!;
    expect(truth, JSON.stringify({ location: owner.location, sourceKind: owner.sourceKind, sourceIndex: owner.sourceIndex, framePath: owner.framePath })).toBeDefined(); const asset = assetTruth.find(a => a.id === truth.assetId)!;
    images.push({ ...owner, capturedAt: null, original: null, input: null, status: 'completed', extractionStatus: asset.extractionStatus,
      text: asset.text, confidence: null, model: 'google/gemini-3.8-flash', promptVersion: 'fixture-v1', cacheOf: null,
      attemptCount: 1, usage: { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null }, reasonCode: asset.extractionStatus === 'unreadable' ? 'OCR_UNREADABLE' : null });
  }
  const before = structuredClone({ images, collected }); const cs = detectImageCandidates(images, collected);
  const multi = cs.find(c => c.location === '#multi')!; expect(multi.sourceIds).toHaveLength(4);
  expect(multi.rawText).toBe(['korean', 'english', 'general', 'notice'].map(id => assetTruth.find(a => a.id === id)!.text).join('\n'));
  for (const c of cs) {
    expect(c.techniques).toEqual([]);
    for (const range of c.sourceTextRanges) expect(c.rawText.slice(range.rawStart, range.rawEnd)).toBe(images.find(i => i.imageId === range.imageId)!.text);
    if (c.rawText) for (const chunk of planCandidateChunks(c)) expect(chunk.stateTokens).toBe(countStateTokens(chunk.state!));
  }
  const domMixed = detectPage(page!).find(c => c.location === '#mixed')!;
  expect(domMixed.candidateId).not.toBe(cs.find(c => c.location === '#mixed')!.candidateId);
  expect(cs.find(c => c.location === '#linked')!.links).toEqual([site.origin + '/destination']);
  expect(cs.find(c => c.location === '#no-text')!.rawText).toBe(''); expect(cs.find(c => c.location === '#unreadable')!.rawText).toBe('');
  expect(new Set(cs.map(c => c.candidateId)).size).toBe(cs.length);
  expect(cs.filter(c => c.location.endsWith('#frame-image')).length).toBe(6);
  expect({ images, collected }).toEqual(before);
}, 15000);
