import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { chromium, type Frame } from 'playwright';
import { startFixtureSite, type FixtureSite } from './site.js';

describe('independent inspection fixtures', () => {
  let site: FixtureSite;
  beforeAll(async () => { site = await startFixtureSite(); });
  afterAll(async () => { await site?.stop(); });

  it('offers two different hostnames and all literal truth techniques', () => {
    expect(new URL(site.origin).hostname).toBe('127.0.0.1');
    expect(new URL(site.externalOrigin).hostname).toBe('localhost');
    expect(new Set(site.expectedFindings.map(item => item.technique))).toEqual(new Set(['HOMOGLYPH', 'JAMO', 'TRANSPARENT', 'OFFSCREEN']));
    expect(site.expectedFindings.every(item => item.rawEvidence.length > 0 && item.location.length > 0)).toBe(true);
    expect(site.expectedFindings.find(item => item.caseId === 'long-tail')!.rawEvidence.length).toBeGreaterThan(200);
    expect(site.expectedFindings.filter(item => item.caseId === 'combined')).toHaveLength(2);
  });

  it('serves independently authored raw text and negative cases unchanged', async () => {
    const html = await (await fetch(site.urls.types)).text();
    for (const item of site.expectedFindings.filter(item => item.pagePath === '/cases/types')) {
      expect(html).toContain(item.rawEvidence);
    }
    const negatives = await (await fetch(site.urls.negatives)).text();
    for (const item of site.negativeCases) expect(negatives).toContain(item.rawEvidence);
    expect(site.negativeCases.map(item => item.caseId)).toEqual(['news', 'numbers', 'jamo-explanation', 'accessibility', 'below-fold']);
  });

  it('contains unique duplicate-source frames, nested external frames and srcdoc truth', async () => {
    const html = await (await fetch(site.urls.frames)).text();
    expect(html).toContain(`src="${site.externalOrigin}/frames/external"`);
    expect(html.match(/src="\/frames\/shared"/g)).toHaveLength(2);
    expect(html).toContain('srcdoc=');
    expect(html).toContain('id="unavailable-frame" src="/failure"');
    const locations = site.expectedFindings.filter(item => item.pagePath === '/cases/frames').map(item => item.location);
    expect(new Set(locations).size).toBe(locations.length);
    expect(locations.some(location => location.split(' >>> ').length === 3)).toBe(true);
  });

  it('resolves every authored DOM/frame location to one exact raw text owner', async () => {
    const browser = await chromium.launch({ headless: true });
    try {
      const page = await browser.newPage();
      for (const pagePath of new Set(site.expectedFindings.map(item => item.pagePath))) {
        await page.goto(site.origin + pagePath, { waitUntil: 'load' });
        for (const item of site.expectedFindings.filter(item => item.pagePath === pagePath)) {
          let frame: Frame = page.mainFrame();
          for (const step of item.location.split(' >>> ').slice(0, -1)) {
            const absoluteSrc = /^iframe\[src="([^"]+)"\]$/.exec(step)?.[1];
            const owners = absoluteSrc
              ? await frame.$$('iframe')
              : await frame.$$(step);
            const matches = [];
            for (const owner of owners) {
              if (!absoluteSrc || await owner.evaluate((element, expected) => {
                const raw = element.getAttribute('src');
                return raw !== null && new URL(raw, element.ownerDocument.URL).href === expected;
              }, absoluteSrc)) matches.push(owner);
            }
            expect(matches, item.caseId + ' frame owner').toHaveLength(1);
            const child = await matches[0].contentFrame();
            expect(child, item.caseId + ' loaded frame').not.toBeNull();
            frame = child!;
          }
          const target = frame.locator(item.selector);
          expect(await target.count(), item.caseId + ' unique owner').toBe(1);
          expect(await target.textContent(), item.caseId + ' raw Unicode').toBe(item.rawEvidence);
        }
      }
    } finally { await browser.close(); }
  });

  it('provides query-distinct pages, redirects, failures and detectable writes', async () => {
    expect(await (await fetch(site.urls.queryOne)).text()).toContain('query-one');
    expect(await (await fetch(site.urls.queryTwo)).text()).toContain('query-two');
    expect((await fetch(site.urls.redirect, { redirect: 'manual' })).headers.get('location')).toBe(site.externalOrigin + '/outside');
    expect((await fetch(site.urls.failure)).status).toBe(503);
    expect((await fetch(site.origin + '/missing')).status).toBe(404);
    expect(await (await fetch(site.urls.dynamic)).text()).toContain('dynamic-link');
    expect(await (await fetch(site.urls.login)).text()).toContain('type="password"');
    expect((await fetch(site.urls.write, { method: 'POST' })).status).toBe(405);
    expect(site.requests.filter(request => request.method === 'POST')).toHaveLength(1);
  });

  it('keeps an intentionally pending request controllable by abort and server stop', async () => {
    const controller = new AbortController();
    const pending = fetch(site.urls.never, { signal: controller.signal });
    await vi.waitFor(() => { expect(site.requests.some(request => request.path === '/never')).toBe(true); });
    controller.abort();
    await expect(pending).rejects.toThrow();
  });
});
