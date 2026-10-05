import { createServer, type Server } from 'node:http';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { chromium } from 'playwright';
import { crawl } from '../../src/crawler/index.js';
import { captureDocument, frameSelector } from '../../src/dom/index.js';

let server: Server;
let origin: string;
const requests: { method: string; path: string }[] = [];
const options = { executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath(), dynamicWaitMs: 100, resourceWaitMs: 200, scrollSteps: 0, navigationTimeoutMs: 1000 };
beforeAll(async () => {
  server = createServer((request, response) => {
    const path = request.url ?? '/'; requests.push({ method: request.method ?? 'GET', path });
    if (path === '/redirect-a') { response.writeHead(302, { location: '/redirect-b' }).end(); return; }
    if (path === '/redirect-b') { response.writeHead(307, { location: '/target?q=%2F&x=1' }).end(); return; }
    if (path === '/loop') { response.writeHead(302, { location: '/loop' }).end(); return; }
    if (path === '/deny') { response.writeHead(401).end(); return; }
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    if (path === '/guard') response.end(`<p>Public text</p><form action="/form" method="post"><button>Write</button></form><script>
      for(const method of ['POST','PUT','PATCH','DELETE'])fetch('/mutation',{method,body:'blocked'}).catch(()=>{});
      window.open('/popup');</script>`);
    else if (path === '/password') response.end('<input type="password"><p>Sign in</p>');
    else if (path === '/article') response.end('<article><p id="public-article">공개 게시글 본문 원문</p></article><aside><form action="/form" method="post"><p id="sidebar-login">로그인 전용 안내</p><input type="password"><a href="/login-region-link">로그인 영역 링크</a><button>Log in</button></form></aside>');
    else if (path === '/article-frame') response.end('<iframe src="/article"></iframe>');
    else if (path === '/form-login') response.end('<form action="/form" method="post"><p>로그인 전용 안내</p><input type="password"><button>Log in</button></form>');
    else if (path === '/detach') response.end('<iframe src="/child"></iframe><script>setTimeout(()=>document.querySelector("iframe").remove(),30)</script>');
    else if (path === '/child') response.end('<p id="detached-text">Do not confirm detached frame</p>');
    else if (path === '/resources') response.end('<p>Resources</p><img src="/one"><img src="/two"><img src="/three">');
    else response.end('<p id="target">Public destination</p>');
  });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address(); if (!address || typeof address === 'string') throw new Error('TCP address missing');
  origin = `http://127.0.0.1:${address.port}`;
});
afterAll(async () => {
  await new Promise<void>((resolve, reject) => { server.close(error => error ? reject(error) : resolve()); server.closeAllConnections(); });
});

describe('collection boundaries', () => {
  it('uses the actual final URL and original query after internal redirect chains', async () => {
    const result = await crawl(origin + '/redirect-a', options);
    expect(result.state, JSON.stringify(result.errors)).toBe('completed'); expect(result.pages[0].url).toBe(origin + '/target?q=%2F&x=1');
    expect(result.pages[0].frames[0].frameUrl).toBe(result.pages[0].url);
    expect(result.counts.discoveredPages).toBe(1);
    const loop = await crawl(origin + '/loop', options);
    expect(loop.state).toBe('failed'); expect(loop.errors.some(e => e.code === 'NAVIGATION_ERROR')).toBe(true);
  });
  it('blocks all write methods and popups without automatic form operations', async () => {
    const result = await crawl(origin + '/guard', options);
    expect(result.state).toBe('partial');
    for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) expect(result.errors.some(e => e.message.includes(method))).toBe(true);
    expect(result.errors.some(e => e.message.includes('Popup blocked'))).toBe(true);
    expect(requests.some(r => ['/mutation', '/form', '/popup'].includes(r.path))).toBe(false);
    expect(requests.every(r => ['GET', 'HEAD'].includes(r.method))).toBe(true);
  });
  it('reports password forms, access denial and detached frames without confirmed snapshots', async () => {
    for (const path of ['/password', '/deny']) {
      const result = await crawl(origin + path, options);
      expect(result.pages).toHaveLength(0); expect(result.scope.skipped[0].reasonCode).toBe('LOGIN_REQUIRED');
      expect(result.counts.failedPages).toBe(0);
    }
    const result = await crawl(origin + '/detach', options);
    expect(result.state).toBe('partial'); expect(result.errors.some(e => e.code === 'FRAME_UNAVAILABLE' && e.message.includes('detached'))).toBe(true);
    expect(result.pages.flatMap(p => p.frames).flatMap(f => f.elements).some(e => e.location.includes('#detached-text'))).toBe(false);
  });
  it('reports hard request, response-byte and HTML bounds', async () => {
    for (const overrides of [{ maxRequestsPerPage: 1 }, { maxResponseBytesPerPage: 1 }, { maxHtmlBytesPerFrame: 1 },
      { maxCapturedBytesPerFrame: 1 }, { maxCollectedBytes: 1 }]) {
      const result = await crawl(origin + '/resources', { ...options, ...overrides });
      expect(result.state).not.toBe('completed'); expect(result.errors.some(e => e.code === 'RESOURCE_LIMIT')).toBe(true);
    }
  });
  it('keeps public articles beside excluded password forms, including embedded frames', async () => {
    for (const path of ['/article', '/article-frame']) {
      const result = await crawl(origin + path, options);
      expect(result.pages).toHaveLength(1); expect(result.counts.skippedPages).toBe(0);
      const elements = result.pages.flatMap(page => page.frames).flatMap(frame => frame.elements);
      expect(elements.some(element => element.rawText === '공개 게시글 본문 원문')).toBe(true);
      expect(elements.some(element => element.rawText.includes('로그인 전용 안내'))).toBe(false);
      expect(result.errors.some(error => error.code === 'LOGIN_REQUIRED')).toBe(true);
      expect(result.counts.discoveredPages).toBe(1);
    }
    const pure = await crawl(origin + '/form-login', options);
    expect(pure.pages).toHaveLength(0); expect(pure.counts.skippedPages).toBe(1);
    expect(pure.scope.skipped[0].reasonCode).toBe('LOGIN_REQUIRED');
    expect(requests.some(request => ['/form', '/login-region-link'].includes(request.path))).toBe(false);
  });
  it('preserves over 120 owners, mixed direct text, context and unique duplicate-ID locations', async () => {
    const browser = await chromium.launch({ executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath() });
    try {
      const page = await browser.newPage();
      await page.setContent(`<!doctype html><main>${Array.from({ length: 135 }, (_, i) => `<p id="duplicate">owner ${i}</p>`).join('')}
        <div id="mixed" style="visibility:hidden"> first <span>child</span> last <a href="https://public.invalid/?q=1">link</a></div>
        <script>const codeMarker='must not collect';</script><style>body{color:red}</style><noscript>not a text owner</noscript>
        <iframe src="about:blank"></iframe><iframe src="about:blank"></iframe><iframe></iframe></main>`);
      const data = await page.evaluate(captureDocument, { framePath: [], maxElements: 1000, maxHtmlBytes: 1000000 });
      expect(data.elements.filter(e => e.rawText.startsWith('owner '))).toHaveLength(135);
      for (const element of data.elements) expect(await page.locator(element.location).count()).toBe(1);
      const mixed = data.elements.find(e => e.location === '#mixed')!;
      expect(mixed.rawText).toBe(' first  last '); expect(mixed.contextText).toBe(mixed.rawText); expect(mixed.links).toEqual([]);
      const link = data.elements.find(element => element.tagName === 'a')!;
      expect(link.links).toEqual(['https://public.invalid/?q=1']);
      expect(mixed.styles[0].css.visibility).toBe('hidden');
      expect(data.elements.some(e => /script|style|noscript/.test(e.tagName))).toBe(false);
      const frames = await page.locator('iframe').elementHandles();
      const selectors = await Promise.all(frames.map(frame => frame.evaluate(frameSelector)));
      expect(new Set(selectors).size).toBe(3);
      for (const selector of selectors) expect(await page.locator(selector).count()).toBe(1);
      const detached = await page.evaluateHandle(() => document.createElement('iframe'));
      await expect(detached.evaluate(frameSelector)).rejects.toThrow('detached');
      await detached.dispose();
    } finally { await browser.close(); }
  });
});
