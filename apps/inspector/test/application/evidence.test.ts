import { mockAnalysisOptions } from './mock-transport.js';
import { expect, it } from 'vitest';
import { createServer } from 'node:http';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium, type Frame } from 'playwright';
import { InspectorApplication } from '../../src/application/index.js';
import { crawl } from '../../src/crawler/index.js';
import { emptyRunCounts, type CollectedPage, type EvidenceSnapshot } from '../../src/core/index.js';
const attr = (text: string) => text.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;');
it('stores frame-local style selectors from real top, nested and srcdoc DOM without changing captured raw text', async () => {
  const raw = '온라인 ㅋㅏㅈㅣㄴㅗ 가입 보너스 🧾';
  const deepest = `<html><body><section id="container"><p id='raw >>> "quoted"' style="opacity:0">${raw}</p></section></body></html>`;
  const middle = `<html><body><p id="middle" style="opacity:0">${raw}</p><iframe id="nested" srcdoc="${attr(deepest)}"></iframe></body></html>`;
  const html = `<html><body><p id="top" style="opacity:0">${raw}</p><iframe id="owner" srcdoc="${attr(middle)}"></iframe></body></html>`;
  const server = createServer((_request, response) => { response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); response.end(html); });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address(); if (!address || typeof address === 'string') throw new Error('No address');
  const url = `http://127.0.0.1:${address.port}`; const root = await mkdtemp(join(tmpdir(), 'frame-evidence-')); const captured: CollectedPage[] = [];
  const browser = await chromium.launch({ headless: true });
  try {
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: root, crawl: (entry, options) => crawl(entry, { ...options, dynamicWaitMs: 0, resourceWaitMs: 0, scrollSteps: 0,
      onPage: page => { captured.push(structuredClone(page)); return options?.onPage?.(page); } }) });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); expect((await app.wait(run.runId)).state).toBe('completed');
    const page = await browser.newPage(); await page.goto(url, { waitUntil: 'load' });
    const frames = captured[0].frames; expect(frames.map(frame => frame.framePath.length).sort()).toEqual([0, 1, 2]);
    for (const frame of frames) {
      const evidence = JSON.parse((await app.readEvidence(run.runId, frame.snapshotId)).toString()) as EvidenceSnapshot;
      expect(evidence.framePath).toEqual(frame.framePath); expect(evidence.html).toBe(frame.html);
      let target: Frame = page.mainFrame();
      for (const step of frame.framePath) { expect(await target.locator(step).count()).toBe(1); target = (await (await target.locator(step).elementHandle())!.contentFrame())!; }
      const owner = evidence.elements.find(element => element.rawText === raw)!; expect(owner).toBeDefined();
      const collected = frame.elements.find(element => element.location === owner.location)!;
      expect(owner.rawText).toBe(collected.rawText); expect(owner.styles).toHaveLength(collected.styles.length);
      for (const [index, style] of owner.styles.entries()) {
        expect(await target.locator(style.elementLocation).count(), `style selector in ${frame.framePath.join(' >>> ')}`).toBe(1);
        expect(style.css).toEqual(collected.styles[index].css); expect(style.bounds).toEqual(collected.styles[index].bounds);
      }
      expect(await target.locator(owner.styles[0].elementLocation).textContent()).toBe(raw);
      if(frame.framePath.length) expect(collected.styles[0].elementLocation).toContain(frame.framePath.join(' >>> ') + ' >>> ');
    }
    expect(app.findings(run.runId).findings.every(finding => finding.evidence_text === raw)).toBe(true);
  } finally { await browser.close(); await new Promise<void>(resolve => { server.close(() => resolve()); server.closeAllConnections(); }); await rm(root, { recursive: true, force: true }); }
}, 30000);
it('removes exactly the frame prefix while retaining delimiters inside quoted selector values', async () => {
  const root = await mkdtemp(join(tmpdir(), 'prefix-evidence-')); const url = 'https://public.test/article';
  const framePath = ['iframe[data-label="outer >>> value"]', 'iframe#nested']; const prefix = framePath.join(' >>> ') + ' >>> ';
  const selector = '[data-label="raw >>> value"]'; const raw = '온라인 카지노 가입 보너스'; const bounds = { x: 0, y: 0, width: 10, height: 10 }; const capturedAt = new Date().toISOString();
  const collected: CollectedPage = { url, capturedAt, discoveredUrls: [], frames: [{ frameUrl: 'about:srcdoc', framePath, capturedAt, snapshotId: 'quoted_snapshot', html: '<p>captured</p>',
    viewport: { width: 100, height: 100, scrollX: 0, scrollY: 0 }, documentSize: { width: 100, height: 100 }, elements: [{ location: prefix + selector, rawText: raw, links: [], tagName: 'p', attributes: {}, contextText: raw,
      accessibility: { role: null, ariaHidden: null, ariaLabel: null }, bounds, documentBounds: bounds,
      styles: [{ elementLocation: prefix + selector, css: { opacity: '0' }, bounds }, { elementLocation: 'body', css: {}, bounds }] }] }] };
  const before = structuredClone(collected);
  try {
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: root, crawl: async (_entry, options) => { await options!.onPage!(collected); return { pages: [collected], state: 'completed', errors: [], counts: { ...emptyRunCounts(), discoveredPages: 1, scannedPages: 1 }, scope: { hostname: 'public.test', framePolicy: 'embedded', skipped: [], unvisitedUrls: [] } }; } });
    const run = app.start({ entryUrl: url, ocrEnabled: false, externalAnalysisConsent: true }); expect((await app.wait(run.runId)).state).toBe('completed');
    const evidence = JSON.parse((await app.readEvidence(run.runId, 'quoted_snapshot')).toString()) as EvidenceSnapshot;
    expect(evidence.elements[0].styles.map(style => style.elementLocation)).toEqual([selector, 'body']); expect(evidence.elements[0].location).toBe(prefix + selector);
    expect(evidence.elements[0].rawText).toBe(raw); expect(collected).toEqual(before);
  } finally { await rm(root, { recursive: true, force: true }); }
});
