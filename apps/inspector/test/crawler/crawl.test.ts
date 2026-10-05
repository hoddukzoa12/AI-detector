import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { chromium, type Browser } from 'playwright';
import { crawl, visitKey, comparisonKey } from '../../src/crawler/index.js';
import type { CollectedPage } from '../../src/core/types.js';
import { startFixtureSite, type FixtureSite } from '../fixtures/site.js';

let site: FixtureSite;
const quick = { executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath(), dynamicWaitMs: 100, resourceWaitMs: 150, scrollSteps: 1, scrollWaitMs: 10, navigationTimeoutMs: 1000 };
beforeAll(async () => { site = await startFixtureSite(); });
afterAll(async () => { await site.stop(); });
describe('public browser crawl', () => {
  it('keeps official comparison normalization separate from resource visit identities', () => {
    const baseline = 'http://example.test/article/?b=2&a=1&a=0#first';
    const reordered = 'https://example.test/article?a=0&b=2&a=1#second';
    expect(comparisonKey(baseline)).toBe(comparisonKey(reordered));
    expect(comparisonKey('http://example.test/')).toBe(comparisonKey('https://example.test#anchor'));
    expect(comparisonKey(baseline)).not.toBe(comparisonKey('https://example.test/article?a=0&b=3&a=1'));
    expect(visitKey(baseline)).not.toBe(visitKey(reordered));
    expect(visitKey('http://example.test/article')).not.toBe(visitKey('https://example.test/article'));
    expect(visitKey('https://example.test/article/')).not.toBe(visitKey('https://example.test/article'));
    expect(visitKey('https://example.test/article?a=1&b=2')).not.toBe(visitKey('https://example.test/article?b=2&a=1'));
    expect(visitKey(baseline)).toBe('http://example.test/article/?b=2&a=1&a=0');
  });
  it('marks a caught whole-crawl exception as fatal regardless of diagnostic wording', async () => {
    const launch = vi.spyOn(chromium, 'launch').mockRejectedValue(new Error('Crawl cancelled by caller'));
    try {
      const result = await crawl(site.urls.types, quick);
      expect(result.fatalError).toBe(true); expect(result.state).toBe('failed');
      expect(result.errors).toEqual([expect.objectContaining({ scope: 'runtime', code: 'RUNTIME_ERROR', message: 'Crawl cancelled by caller' })]);
      expect(result.scope.unvisitedUrls).toEqual([site.urls.types]); expect(result.counts.scannedPages).toBe(0);
    } finally { launch.mockRestore(); }
  });
  it('does not mark launch rejection caused by an intentional halt as fatal', async () => {
    for (const reason of ['USER_CANCELLED', 'TIME_LIMIT', 'RESOURCE_LIMIT']) {
      const controller = new AbortController();
      const launch = vi.spyOn(chromium, 'launch').mockImplementation(async () => {
        controller.abort(reason); throw new Error('Unexpected-looking browser launch rejection');
      });
      try {
        const result = await crawl(site.urls.types, { ...quick, signal: controller.signal });
        expect(result.fatalError).not.toBe(true);
        expect(result.state).toBe(reason === 'USER_CANCELLED' ? 'cancelled' : 'partial');
        expect(result.errors).toHaveLength(1);
        expect(result.errors[0].code).toBe(reason === 'USER_CANCELLED' ? 'RUNTIME_ERROR' : reason);
        expect(result.scope.unvisitedUrls).toEqual([site.urls.types]);
      } finally { launch.mockRestore(); }
    }
  });
  it('retains every raw owner and ancestor style without duplicate parent text', async () => {
    const result = await crawl(site.urls.types, quick);
    expect(result.state).toBe('completed'); expect(result.fatalError).not.toBe(true);
    const frame = result.pages[0].frames[0];
    for (const truth of site.expectedFindings.filter(t => t.url === site.urls.types)) {
      expect(frame.elements.find(e => e.location === truth.location)?.rawText).toBe(truth.rawEvidence);
    }
    expect(frame.elements.find(e => e.location === '#long-tail')!.rawText.length).toBeGreaterThan(200);
    expect(frame.elements.find(e => e.location === '#ancestor-child')!.styles[1].css.opacity).toBe('0');
    expect(frame.elements.some(e => e.tagName === 'section')).toBe(false);
    expect(frame.snapshotId).toBeTruthy(); expect(Date.parse(frame.capturedAt)).toBeGreaterThan(0);
  });
  it('captures relative, duplicate-src, srcdoc, nested and external frames with exact paths', async () => {
    const result = await crawl(site.urls.frames, quick);
    expect(result.state).toBe('partial'); expect(result.fatalError).not.toBe(true);
    expect(result.errors.some(e => e.code === 'FRAME_UNAVAILABLE' && e.url === site.urls.failure)).toBe(true);
    for (const truth of site.expectedFindings.filter(t => t.url === site.urls.frames)) {
      expect(result.pages[0].frames.flatMap(f => f.elements).find(e => e.location === truth.location)?.rawText).toBe(truth.rawEvidence);
    }
    expect(result.counts.discoveredPages).toBe(1);
    expect(result.pages[0].frames[0].html).toContain('src="../frames/relative"');
    expect(new Set(result.pages[0].frames.map(f => f.snapshotId)).size).toBe(result.pages[0].frames.length);
    expect(site.requests.some(r => r.origin === 'external' && r.path === '/outside')).toBe(false);
  });
  it('preserves query visit identities and normal below-fold document coordinates', async () => {
    expect(visitKey(site.urls.queryOne)).not.toBe(visitKey(site.urls.queryTwo));
    expect(comparisonKey(site.urls.queryOne + '#a')).toBe(comparisonKey(site.urls.queryOne + '#b'));
    const result = await crawl(site.urls.negatives, quick);
    for (const truth of site.negativeCases) expect(result.pages[0].frames[0].elements.find(e => e.location === truth.selector)?.rawText).toBe(truth.rawEvidence);
    const owner = result.pages[0].frames[0].elements.find(e => e.location === '#below-fold')!;
    expect(owner.documentBounds.y).toBeGreaterThan(2000);
    expect(owner.documentBounds.y).toBe(owner.bounds.y + result.pages[0].frames[0].viewport.scrollY);
  });
  it('reports failures, login, resource loading and write guards as partial; external redirect is never requested', async () => {
    const pages: string[] = [];
    const result = await crawl(site.urls.entry, { ...quick, onPage: page => { pages.push(page.url); } });
    expect(result.state).toBe('partial'); expect(result.fatalError).not.toBe(true);
    expect(pages).toContain(site.urls.queryOne); expect(pages).toContain(site.urls.queryTwo);
    expect(result.scope.skipped.some(s => s.url === site.urls.login && s.reasonCode === 'LOGIN_REQUIRED')).toBe(true);
    expect(result.errors.some(e => e.code === 'RESOURCE_LIMIT' && e.url === site.urls.loading)).toBe(true);
    expect(result.errors.some(e => e.url === site.urls.write && e.message.includes('POST'))).toBe(true);
    expect(site.requests.some(r => !['GET', 'HEAD'].includes(r.method))).toBe(false);
    expect(site.requests.some(r => r.origin === 'external' && r.path === '/outside')).toBe(false);
    expect(result.counts.discoveredPages).toBe(12);
    expect(result.counts.pendingPages).toBe(0);
  }, 20000);
  it('discovers dynamically inserted links', async () => {
    const result = await crawl(site.urls.dynamic, quick);
    expect(result.pages.map(p => p.url)).toContain(site.urls.queryTwo);
  });
  it('marks page/time/resource caps and cancellation without claiming completion', async () => {
    const capped = await crawl(site.urls.entry, { ...quick, maxPages: 1 });
    expect(capped.state).toBe('partial'); expect(capped.fatalError).not.toBe(true); expect(capped.scope.unvisitedUrls.length).toBeGreaterThan(0);
    expect(capped.counts.pendingPages).toBe(capped.scope.unvisitedUrls.length);
    const timed = await crawl(site.urls.never, { ...quick, maxDurationMs: 100 });
    expect(timed.errors.some(e => e.code === 'TIME_LIMIT')).toBe(true); expect(timed.fatalError).not.toBe(true);
    expect(timed.scope.unvisitedUrls).toContain(site.urls.never);
    const controller = new AbortController();
    const pending = crawl(site.urls.never, { ...quick, signal: controller.signal });
    setTimeout(() => controller.abort(), 100);
    const cancelled = await pending;
    expect(cancelled.state).toBe('cancelled'); expect(cancelled.fatalError).not.toBe(true); expect(cancelled.scope.unvisitedUrls).toContain(site.urls.never);
    expect(cancelled.errors.some(e => e.message.includes('cancel'))).toBe(true);
    const limited = await crawl(site.urls.types, { ...quick, maxElementsPerFrame: 1 });
    expect(limited.state).toBe('failed'); expect(limited.fatalError).not.toBe(true); expect(limited.errors.some(e => e.code === 'RESOURCE_LIMIT')).toBe(true);
  });
  it('rejects malformed or credential URLs and invalid options before browsing', async () => {
    for (const url of ['javascript:alert(1)', 'http://u:p@example.test/', ' http://example.test/']) await expect(crawl(url, quick)).rejects.toThrow('INVALID_URL');
    await expect(crawl(site.urls.types, { maxPages: 0 })).rejects.toThrow('INVALID_CONFIG');
  });
  it('distinguishes coordinator limit signals from user cancellation without echoing arbitrary reasons', async () => {
    for (const reason of ['TIME_LIMIT', 'RESOURCE_LIMIT', 'private caller reason']) {
      const controller = new AbortController(); controller.abort(reason);
      const result = await crawl(site.urls.never, { ...quick, signal: controller.signal });
      expect(result.state).toBe(reason === 'private caller reason' ? 'cancelled' : 'partial'); expect(result.fatalError).not.toBe(true);
      expect(result.errors[0].code).toBe(reason === 'private caller reason' ? 'RUNTIME_ERROR' : reason);
      expect(result.scope.unvisitedUrls).toEqual([site.urls.never]); expect(result.counts.pendingPages).toBe(1);
      expect(JSON.stringify(result.errors)).not.toContain('private caller reason');
    }
  });
  it('returns on deadline even when a caller callback remains pending', async () => {
    const context = { on: vi.fn(), route: vi.fn(async () => {}), routeWebSocket: vi.fn(async () => {}),
      newPage: vi.fn(async () => { throw new Error('중단 후 새 페이지를 만들면 안 됩니다'); }) };
    const close = vi.fn(async () => {});
    const newContext = vi.fn(async () => context);
    const browser = { newContext, close } as unknown as Browser;
    const launch = vi.spyOn(chromium, 'launch').mockResolvedValue(browser);
    const pendingCallback = new Promise<void>(() => {});
    const onProgress = vi.fn(() => pendingCallback);
    let guard: ReturnType<typeof setTimeout> | undefined;
    const startedAt = Date.now(); const deadlineMs = 20;
    try {
      const result = await Promise.race([
        crawl(site.urls.types, { ...quick, maxDurationMs: deadlineMs, onProgress }),
        new Promise<'callback still pending'>(resolve => { guard = setTimeout(() => resolve('callback still pending'), 1000); }),
      ]);
      expect(result).not.toBe('callback still pending');
      if (typeof result === 'string') return;
      expect(launch).toHaveBeenCalledTimes(1); expect(newContext).toHaveBeenCalledTimes(1);
      expect(onProgress).toHaveBeenCalledTimes(1); expect(onProgress.mock.results[0].value).toBe(pendingCallback);
      expect(onProgress).toHaveBeenCalledWith(expect.objectContaining({ activeUrls: [site.urls.types] }));
      expect(Date.now() - startedAt).toBeGreaterThanOrEqual(deadlineMs);
      expect(result.state).toBe('partial'); expect(result.fatalError).not.toBe(true); expect(result.errors.some(e => e.code === 'TIME_LIMIT')).toBe(true);
      expect(result.scope.unvisitedUrls).toEqual([site.urls.types]); expect(result.counts.pendingPages).toBe(1);
      expect(context.newPage).not.toHaveBeenCalled(); expect(close).toHaveBeenCalledTimes(1);
    } finally { if (guard) clearTimeout(guard); launch.mockRestore(); }
  });
  it('returns on abort from a pending page callback and isolates late mutations/rejection', async () => {
    const controller = new AbortController();
    let callbackPage: CollectedPage | undefined;
    let rejectCallback: (error: Error) => void = () => {};
    const pending = crawl(site.urls.types, { ...quick, signal: controller.signal, onPage: page => {
      callbackPage = page;
      setTimeout(() => controller.abort(), 20);
      return new Promise<void>((_resolve, reject) => { rejectCallback = reject; });
    } });
    const result = await Promise.race([pending, new Promise<'callback still pending'>(resolve => setTimeout(() => resolve('callback still pending'), 2000))]);
    expect(result).not.toBe('callback still pending');
    if (typeof result === 'string') return;
    expect(result.state).toBe('cancelled'); expect(result.fatalError).not.toBe(true); expect(result.pages).toHaveLength(1);
    const originalText = result.pages[0].frames[0].elements[0].rawText;
    callbackPage!.url = 'https://late-mutation.invalid/'; callbackPage!.frames[0].elements[0].rawText = 'late mutation';
    rejectCallback(new Error('late callback rejection'));
    await new Promise<void>(resolve => setTimeout(resolve, 20));
    expect(result.pages[0].url).toBe(site.urls.types);
    expect(result.pages[0].frames[0].elements[0].rawText).toBe(originalText);
    expect(result.errors.some(error => error.message.includes('late callback rejection'))).toBe(false);
  });
  it('실행 중 다음 배치 페이지 생성에 시간·자원 중단이 겹쳐도 확인한 원문과 미방문 범위를 반환한다', async () => {
    for (const reason of ['TIME_LIMIT', 'RESOURCE_LIMIT']) {
      const controller = new AbortController();
      const delivered: CollectedPage[] = [];
      let scheduled = false;
      const result = await crawl(site.urls.entry, { executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath(), signal: controller.signal,
        onPage: page => { delivered.push(page); },
        onProgress: progress => {
          if (!scheduled && progress.activeUrls.includes(site.urls.frames)) {
            scheduled = true; setTimeout(() => controller.abort(reason), 5);
          }
        } });
      expect(scheduled).toBe(true); expect(result.state).toBe('partial'); expect(result.fatalError).not.toBe(true);
      expect(result.errors.some(error => error.code === reason)).toBe(true);
      expect(result.pages.map(page => page.url)).toEqual(delivered.map(page => page.url));
      expect(result.pages).toHaveLength(3); expect(result.counts.scannedPages).toBe(3);
      expect(result.scope.unvisitedUrls).toContain(site.urls.frames);
      expect(result.scope.unvisitedUrls).toContain(site.urls.queryOne);
      expect(result.counts.pendingPages).toBe(result.scope.unvisitedUrls.length);
      const snapshot = JSON.stringify(result);
      await new Promise<void>(resolve => setTimeout(resolve, 20));
      expect(JSON.stringify(result)).toBe(snapshot);
    }
  });
});
