import { createHash, randomUUID } from 'node:crypto';
import { chromium, type Browser, type Frame, type Page, type Request } from 'playwright';
import { ContractError, validateEntryUrl } from '../core/validation.js';
import type { CollectedPage, RunCounts, RunError, ScanScope, TerminalRunState } from '../core/types.js';
import { captureDocument, frameSelector } from '../dom/index.js';

import type { CollectedImageOccurrence } from '../core/v2.js';
import { acquireCollectedImage, IMAGE_CAPTURE_DEFAULTS, type ImageCollectionOptions } from './images.js';
export { acquireCollectedImage, IMAGE_CAPTURE_DEFAULTS } from './images.js';
export type { ImageCollectionOptions, ImageAcquisitionResult } from './images.js';

export interface CrawlProgress { counts: RunCounts; activeUrls: string[]; errors: RunError[] }
export interface CollectedPageWithImages extends CollectedPage { images?: CollectedImageOccurrence[] }
export interface CrawlOptions {
  signal?: AbortSignal;
  images?: ImageCollectionOptions;
  onPage?: (page: CollectedPageWithImages) => void | Promise<void>;
  onProgress?: (progress: CrawlProgress) => void | Promise<void>;
  maxPages?: number; maxDurationMs?: number; navigationTimeoutMs?: number;
  dynamicWaitMs?: number; resourceWaitMs?: number; scrollSteps?: number; scrollWaitMs?: number; concurrency?: number;
  maxRequestsPerPage?: number; maxResponseBytesPerPage?: number; maxElementsPerFrame?: number; maxHtmlBytesPerFrame?: number;
  maxCapturedBytesPerFrame?: number; maxCollectedBytes?: number;
  executablePath?: string;
}
export interface CrawlResult {
  state: TerminalRunState; pages: CollectedPage[]; errors: RunError[]; scope: ScanScope; counts: RunCounts;
  /** Internal whole-crawl failure metadata; policy diagnostics and intentional halts are not fatal. */
  fatalError?: boolean;
}
export const CRAWL_DEFAULTS = {
  maxPages: 500, maxDurationMs: 28 * 60 * 1000, navigationTimeoutMs: 15000,
  dynamicWaitMs: 500, resourceWaitMs: 1000, scrollSteps: 3, scrollWaitMs: 150, concurrency: 2,
  maxRequestsPerPage: 5000, maxResponseBytesPerPage: 100 * 1024 * 1024,
  maxElementsPerFrame: 100000, maxHtmlBytesPerFrame: 50 * 1024 * 1024,
  maxCapturedBytesPerFrame: 50 * 1024 * 1024, maxCollectedBytes: 512 * 1024 * 1024,
} as const;

/** Visit identity preserves the full query and strips only the document fragment. */
export function visitKey(value: string): string { const url = new URL(value); url.hash = ''; return url.href; }
/** Comparison identity is independent from scheduling and never replaces captured URLs. */
export function comparisonKey(value: string): string {
  const url = new URL(value);
  const query = new URLSearchParams([...url.searchParams].sort(([leftKey, leftValue], [rightKey, rightValue]) =>
    leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : leftValue < rightValue ? -1 : leftValue > rightValue ? 1 : 0)).toString();
  return `//${url.host}${url.pathname.replace(/\/+$/, '')}${query ? '?' + query : ''}`;
}
function loginUrl(url: string): boolean { return /(?:^|\/)(?:login|signin|sign-in|log-in|auth|oauth|sso)(?:\/|$)/i.test(new URL(url).pathname); }
function acceptable(value: string, hostname: string): boolean {
  try { const url = new URL(value); return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password && url.hostname === hostname; }
  catch { return false; }
}
function errorMessage(error: unknown): string { return error instanceof Error ? error.message : 'Browser collection failed'; }

/** Fresh browser context; callbacks receive local raw snapshots, never remote AI submissions. */
export async function crawl(entryUrl: string, options: CrawlOptions = {}): Promise<CrawlResult> {
  validateEntryUrl(entryUrl);
  const settings = { ...CRAWL_DEFAULTS, ...options };
  for (const key of Object.keys(CRAWL_DEFAULTS) as (keyof typeof CRAWL_DEFAULTS)[]) {
    const value = settings[key];
    const allowZero = ['dynamicWaitMs', 'resourceWaitMs', 'scrollSteps', 'scrollWaitMs'].includes(key);
    if (typeof value !== 'number' || !Number.isFinite(value) || value < (allowZero ? 0 : 1) || !Number.isInteger(value)) {
      throw new ContractError('INVALID_CONFIG', `${key} must be a ${allowZero ? 'nonnegative' : 'positive'} integer`);
    }
  }
  if (options.images) {
    if (typeof options.images.enabled !== 'boolean' || typeof options.images.onImage !== 'function') throw new ContractError('INVALID_CONFIG', 'Invalid image collection configuration');
    for (const [key, fallback] of Object.entries(IMAGE_CAPTURE_DEFAULTS)) {
      const value = options.images[key as keyof typeof IMAGE_CAPTURE_DEFAULTS] ?? fallback;
      if (!Number.isInteger(value) || value < (key === 'maxRedirects' ? 0 : 1)) throw new ContractError('INVALID_CONFIG', 'Invalid image collection limit');
    }
  }
  const imageAbort = new AbortController();
  const hostname = new URL(entryUrl).hostname;
  const pages: CollectedPage[] = [], errors: RunError[] = [];
  const scope: ScanScope = { hostname, framePolicy: 'embedded', skipped: [], unvisitedUrls: [] };
  const accepted = new Map<string, string>([[visitKey(entryUrl), entryUrl]]);
  const queue = [entryUrl], active = new Set<string>(), finished = new Set<string>();
  let attempted = 0, failedPages = 0, stop: 'cancelled' | 'time' | 'resource' | null = null;
  let collectedBytes = 0, fatalError = false;
  let browser: Browser | undefined;
  let closingBrowser: Promise<void> | undefined;
  let resolveHalted: () => void = () => {};
  const halted = new Promise<void>(resolve => { resolveHalted = resolve; });
  // Closing only a context can leave its in-flight newPage RPC unresolved.
  // Close the owned browser once so pending protocol calls reject and every batch drains.
  function closeBrowser(): Promise<void> {
    if (!browser) return Promise.resolve();
    closingBrowser ??= browser.close().catch(() => {});
    return closingBrowser;
  }
  function counts(): RunCounts {
    return { discoveredPages: accepted.size, scannedPages: pages.length, failedPages,
      skippedPages: scope.skipped.length, pendingPages: [...accepted.keys()].filter(key => !finished.has(key)).length,
      confirmedFindings: 0, reviewCandidates: 0 };
  }
  function addError(code: RunError['code'], url: string | null, message: string, errorScope: RunError['scope'] = 'page') {
    if (!errors.some(e => e.code === code && e.url === url && e.message === message)) errors.push({ scope: errorScope, code, url, candidateId: null, message });
  }
  function skip(url: string, reasonCode: RunError['code']) {
    if (!scope.skipped.some(s => s.url === url && s.reasonCode === reasonCode)) scope.skipped.push({ url, reasonCode });
  }
  async function callerCallback(callback: () => void | Promise<void>, failed: () => void) {
    if (stop) return;
    // Promise.race installs rejection handlers on the original task even after a halt wins.
    // Callers must observe their signal to stop their own work; crawler state stays isolated.
    const task = Promise.resolve().then(() => { if (!stop) return callback(); });
    try { await Promise.race([task, halted]); }
    catch { if (!stop) failed(); }
  }
  async function progress() {
    await callerCallback(() => options.onProgress?.({ counts: counts(), activeUrls: [...active], errors: errors.map(error => ({ ...error })) }),
      () => addError('RUNTIME_ERROR', null, 'Progress callback failed', 'runtime'));
  }
  function halt(reason: 'cancelled' | 'time' | 'resource') {
    if (stop) return;
    stop = reason;
    imageAbort.abort(reason === 'time' ? 'TIME_LIMIT' : reason === 'resource' ? 'RESOURCE_LIMIT' : 'USER_CANCELLED');
    resolveHalted();
    addError(reason === 'time' ? 'TIME_LIMIT' : reason === 'resource' ? 'RESOURCE_LIMIT' : 'RUNTIME_ERROR', null,
      reason === 'time' ? 'Crawl work-time limit reached' : reason === 'resource' ? 'Crawl resource limit reached' : 'Crawl cancelled by caller',
      reason === 'cancelled' ? 'runtime' : 'limit');
    void closeBrowser();
  }
  const abort = () => halt(options.signal?.reason === 'TIME_LIMIT' ? 'time' : options.signal?.reason === 'RESOURCE_LIMIT' ? 'resource' : 'cancelled');
  options.signal?.addEventListener('abort', abort, { once: true });
  if (options.signal?.aborted) abort();
  const timer = setTimeout(() => halt('time'), settings.maxDurationMs);
  function discover(urls: string[]) {
    for (const url of urls) {
      if (!acceptable(url, hostname)) continue; // Excluded external links are not collection failures.
      const key = visitKey(url);
      if (!accepted.has(key)) { accepted.set(key, url); queue.push(url); }
    }
  }
  try {
    if (!stop) {
      browser = await chromium.launch({ headless: true, ...(options.executablePath ? { executablePath: options.executablePath } : {}) });
      if (stop) { await closeBrowser(); throw new Error('Crawl halted before context creation'); }
      const context = await browser.newContext({ serviceWorkers: 'block', acceptDownloads: false,
        // A fulfilled top document has no remote IP. Chromium otherwise blocks the independent
        // loopback fixture's embedded localhost frames; grant this only for loopback entry hosts.
        permissions: ['localhost', '127.0.0.1', '[::1]'].includes(hostname) ? ['local-network-access'] : [] });
      if (stop) { await closeBrowser(); throw new Error('Crawl halted before context setup'); }
      context.on('page', page => { void page.opener().then(opener => {
        if (opener) { if (!stop) addError('RUNTIME_ERROR', jobs.get(opener)?.url ?? null, 'Popup blocked'); return page.close(); }
      }).catch(() => {}); });
      // Pages are never clicked, filled or submitted. Site-initiated writes are blocked before HTTP dispatch.
      const jobs = new Map<Page, { url: string; pending: Set<Request>; frameFailures: Map<Frame, string>; requests: number; bytes: number; hardLimit: boolean; redirectUrl: string | null }>();
      await context.routeWebSocket('**/*', socket => {
        if (!stop) addError('RUNTIME_ERROR', null, 'Blocked bidirectional WebSocket connection', 'runtime');
        void socket.close().catch(() => {});
      });
      await context.route('**/*', async route => {
        try {
        if (stop) { await route.abort('aborted').catch(() => {}); return; }
        const request = route.request();
        let frame: Frame;
        try { frame = request.frame(); }
        catch {
          addError('RUNTIME_ERROR', null, 'Popup blocked before frame creation');
          await route.abort('blockedbyclient'); return;
        }
        const page = frame.page(); const job = jobs.get(page);
        if (!job) { await route.abort('blockedbyclient'); return; }
        if (!['GET', 'HEAD'].includes(request.method())) {
          addError('RUNTIME_ERROR', job.url, `Blocked non-reading ${request.method()} request`, 'page');
          await route.abort('blockedbyclient'); return;
        }
        if (request.isNavigationRequest() && frame === page.mainFrame()) {
          if (!acceptable(request.url(), hostname)) {
            skip(job.url, 'OUT_OF_SCOPE'); addError('OUT_OF_SCOPE', job.url, 'Blocked external top-level navigation');
            await route.abort('blockedbyclient'); return;
          }
          if (loginUrl(request.url())) {
            skip(job.url, 'LOGIN_REQUIRED'); addError('LOGIN_REQUIRED', job.url, 'Login navigation excluded');
            await route.abort('blockedbyclient'); return;
          }
        }
        job.requests++;
        if (job.requests > settings.maxRequestsPerPage) {
          job.hardLimit = true; addError('RESOURCE_LIMIT', job.url, 'Page request limit reached', 'limit');
          await route.abort('blockedbyclient'); void page.close().catch(() => {}); return;
        }
        if (request.isNavigationRequest() && frame === page.mainFrame()) {
          // Playwright does not route subsequent requests in an HTTP redirect chain.
          // Fetch only this response and inspect Location before Chromium sees it.
          try {
            const response = await route.fetch({ maxRedirects: 0, timeout: settings.navigationTimeoutMs });
            if (stop) { await route.abort('aborted').catch(() => {}); return; }
            const location = response.headers()['location'];
            if ([401, 403].includes(response.status())) {
              skip(job.url, 'LOGIN_REQUIRED'); addError('LOGIN_REQUIRED', job.url, `Public access denied: HTTP ${response.status()}`);
              await route.abort('blockedbyclient');
            } else if (response.status() >= 300 && response.status() < 400 && location) {
              const destination = new URL(location, request.url()).href;
              if (!acceptable(destination, hostname)) {
                skip(job.url, 'OUT_OF_SCOPE'); addError('OUT_OF_SCOPE', job.url, 'Blocked external top-level redirect');
              } else if (loginUrl(destination)) {
                skip(job.url, 'LOGIN_REQUIRED'); addError('LOGIN_REQUIRED', job.url, 'Login redirect excluded');
              } else job.redirectUrl = destination;
              await route.abort(job.redirectUrl ? 'aborted' : 'blockedbyclient');
            } else if ((await response.body()).byteLength > settings.maxResponseBytesPerPage) {
              job.hardLimit = true; addError('RESOURCE_LIMIT', job.url, 'Navigation response byte limit reached', 'limit');
              await route.abort('blockedbyclient');
            } else await route.fulfill({ response });
          } catch {
            if (!stop) addError('NAVIGATION_ERROR', job.url, 'Navigation response unavailable');
            await route.abort('failed').catch(() => {});
          }
          return;
        }
        await route.continue();
        } catch {
          if (!stop) addError('RUNTIME_ERROR', null, 'Browser request interception failed', 'runtime');
          await route.abort('failed').catch(() => {});
        }
      });
      async function collect(url: string) {
        if (stop) return;
        const key = visitKey(url);
        if (loginUrl(url)) {
          skip(url, 'LOGIN_REQUIRED'); addError('LOGIN_REQUIRED', url, 'Login page excluded'); finished.add(key); return;
        }
        const page = await context.newPage();
        if (stop) { await page.close().catch(() => {}); return; }
        const job = { url, pending: new Set<Request>(), frameFailures: new Map<Frame, string>(), requests: 0, bytes: 0, hardLimit: false, redirectUrl: null as string | null };
        jobs.set(page, job);
        page.on('framedetached', frame => {
          if (jobs.has(page) && !stop) addError('FRAME_UNAVAILABLE', frame.url(), 'Embedded frame detached during collection', 'frame');
        });
        page.on('request', request => job.pending.add(request));
        page.on('requestfailed', request => {
          job.pending.delete(request);
          if (request.isNavigationRequest() && request.frame() !== page.mainFrame()) {
            job.frameFailures.set(request.frame(), request.failure()?.errorText ?? 'Frame navigation failed');
          }
        });
        const measurements = new Set<Promise<void>>();
        page.on('requestfinished', request => {
          job.pending.delete(request);
          if (stop) return;
          const task = (async () => {
            try {
              const sizes = await request.sizes();
              if (stop) return;
              job.bytes += sizes.responseBodySize;
              if (job.bytes > settings.maxResponseBytesPerPage && !job.hardLimit) {
                job.hardLimit = true; addError('RESOURCE_LIMIT', url, 'Page response byte limit reached', 'limit'); await page.close();
              }
            } catch { /* Interrupted requests are already reflected in pending/navigation errors. */ }
          })();
          measurements.add(task); void task.finally(() => measurements.delete(task));
        });
        page.on('response', response => {
          if (stop) return;
          const request = response.request();
          if (request.isNavigationRequest() && response.status() >= 400) job.frameFailures.set(request.frame(), `HTTP ${response.status()}`);
          const size = Number(response.headers()['content-length']);
          if (size > settings.maxResponseBytesPerPage) {
            job.hardLimit = true; addError('RESOURCE_LIMIT', url, 'Response content-length exceeds byte limit', 'limit'); void page.close().catch(() => {});
          }
        });
        try {
          let destination = url;
          let response;
          const redirectKeys = new Set<string>();
          while (!stop) {
            if (redirectKeys.has(visitKey(destination))) throw new Error('Navigation redirect loop');
            redirectKeys.add(visitKey(destination)); job.redirectUrl = null;
            try { response = await page.goto(destination, { waitUntil: 'domcontentloaded', timeout: settings.navigationTimeoutMs }); break; }
            catch (error) { if (!job.redirectUrl || stop) throw error; destination = job.redirectUrl; }
          }
          if (stop) return;
          if (response && [401, 403].includes(response.status())) {
            skip(url, 'LOGIN_REQUIRED'); addError('LOGIN_REQUIRED', url, `Public access denied: HTTP ${response.status()}`); finished.add(key); return;
          }
          if (!response || response.status() >= 400) throw new Error(`Navigation ${response ? 'HTTP ' + response.status() : 'response unavailable'}`);
          if (!acceptable(page.url(), hostname)) throw new Error('Out-of-scope final page URL');
          const actualUrl = page.url();
          await page.waitForTimeout(settings.dynamicWaitMs);
          for (let i = 0; i < settings.scrollSteps && !stop; i++) {
            await page.evaluate(() => window.scrollBy(0, window.innerHeight));
            await page.waitForTimeout(settings.scrollWaitMs);
          }
          const waitUntil = Date.now() + settings.resourceWaitMs;
          while (job.pending.size && Date.now() < waitUntil && !stop) await page.waitForTimeout(Math.min(25, Math.max(1, waitUntil - Date.now())));
          await Promise.all([...measurements]);
          if (stop) return;
          if (job.pending.size) addError('RESOURCE_LIMIT', actualUrl, `${job.pending.size} resources still loading at collection limit`, 'limit');
          const result: CollectedPage = { url: actualUrl, frames: [], discoveredUrls: [], capturedAt: new Date().toISOString() };
          const images: { frame: Frame; occurrence: CollectedImageOccurrence }[] = [];
          let hasLoginRegion = false;
          async function capture(frame: Frame, path: string[]) {
            if (stop) return;
            if (frame.isDetached()) { addError('FRAME_UNAVAILABLE', frame.url(), 'Frame detached before capture', 'frame'); return; }
            const unavailable = job.frameFailures.get(frame);
            if (unavailable) { addError('FRAME_UNAVAILABLE', frame.url(), unavailable, 'frame'); return; }
            try {
              if (frame !== page.mainFrame() && loginUrl(frame.url())) {
                hasLoginRegion = true;
                addError('LOGIN_REQUIRED', frame.url(), 'Embedded login document excluded', 'frame'); return;
              }
              const frameUrl = frame.url();
              const data = await frame.evaluate(captureDocument, { framePath: path, maxElements: settings.maxElementsPerFrame,
                maxHtmlBytes: settings.maxHtmlBytesPerFrame, maxCaptureBytes: settings.maxCapturedBytesPerFrame, captureImages: Boolean(options.images) });
              if (stop) return;
              if (frame.isDetached() || frame.url() !== frameUrl || page.url() !== actualUrl) throw new Error('Frame detached or navigated during capture');
              const { discoveredUrls, excludedLoginRegions, images: frameImages, ...captured } = data;
              if (excludedLoginRegions.length) {
                hasLoginRegion = true;
                for (const region of excludedLoginRegions) addError('LOGIN_REQUIRED', frame.url(), `Login region excluded: ${region}`,
                  frame === page.mainFrame() ? 'page' : 'frame');
              }
              const snapshotId = randomUUID();
              result.frames.push({ ...captured, frameUrl: frame.url(), framePath: path, snapshotId, capturedAt: new Date().toISOString() });
              for (const image of frameImages) images.push({ frame, occurrence: { ...image, imageId: 'image-' + createHash('sha256').update(JSON.stringify([actualUrl, path, image.location, image.sourceKind, image.sourceIndex])).digest('hex').slice(0, 32), url: actualUrl, frameUrl: frame.url(), framePath: path, snapshotId } });
              // Included external frame links never expand the page crawl queue.
              if (frame === page.mainFrame() || acceptable(frame.url(), hostname)) {
                result.discoveredUrls.push(...discoveredUrls.filter(link => acceptable(link, hostname)));
              }
              for (const child of frame.childFrames()) {
                if (stop) break;
                try {
                  const element = await child.frameElement();
                  const selector = await element.evaluate(frameSelector);
                  const src = await element.getAttribute('src');
                  const srcdoc = await element.getAttribute('srcdoc');
                  await element.dispose();
                  if (src && srcdoc === null && ['about:blank', 'chrome-error://chromewebdata/'].includes(child.url())) {
                    throw new Error('Embedded frame navigation is incomplete');
                  }
                  await capture(child, [...path, selector]);
                } catch { if (!stop) addError('FRAME_UNAVAILABLE', child.url(), 'Frame location unavailable or detached', 'frame'); }
              }
            } catch (error) {
              if (stop) return;
              const message = errorMessage(error);
              addError(message.includes('RESOURCE_LIMIT') ? 'RESOURCE_LIMIT' : 'FRAME_UNAVAILABLE', frame.url(), message,
                message.includes('RESOURCE_LIMIT') ? 'limit' : 'frame');
            }
          }
          await capture(page.mainFrame(), []);
          if (stop) return;
          if (!result.frames.some(f => f.framePath.length === 0)) { failedPages++; finished.add(key); return; }
          if (hasLoginRegion && !result.frames.some(frame => frame.elements.length) && !images.length) {
            skip(actualUrl, 'LOGIN_REQUIRED'); finished.add(key); return;
          }
          result.discoveredUrls = [...new Set(result.discoveredUrls)];
          collectedBytes += Buffer.byteLength(JSON.stringify({ ...result, images: images.map(image => image.occurrence) }));
          if (collectedBytes > settings.maxCollectedBytes) { halt('resource'); return; }
          discover(result.discoveredUrls); pages.push(result); finished.add(key);
          let pageCallbackFailed = false;
          await callerCallback(() => options.onPage?.(structuredClone({ ...result, images: images.map(image => image.occurrence) })),
            () => { pageCallbackFailed = true; addError('RUNTIME_ERROR', actualUrl, 'Page callback failed', 'runtime'); });
          if (pageCallbackFailed) return;
          // Every snapshot is handed off before any image can create downstream findings.
          if (options.images) for (const { frame, occurrence } of images) {
            if (stop) break;
            try { await acquireCollectedImage(browser!, frame, occurrence, options.images, imageAbort.signal); }
            catch { if (!stop) addError('RUNTIME_ERROR', actualUrl, 'Image callback failed', 'runtime'); }
          }
        } catch (error) {
          if (!stop) {
            if (!scope.skipped.some(s => s.url === url)) failedPages++;
            finished.add(key);
            if (!scope.skipped.some(s => s.url === url) && !job.hardLimit) addError('NAVIGATION_ERROR', url, errorMessage(error));
          }
        } finally {
          jobs.delete(page); await page.close().catch(() => {});
        }
      }
      // Batches keep scheduling deterministic while allowing simultaneous independent page reads.
      while (queue.length && !stop && attempted < settings.maxPages) {
        const batch = queue.splice(0, Math.min(settings.concurrency, settings.maxPages - attempted));
        attempted += batch.length;
        for (const url of batch) active.add(url);
        await progress();
        if (stop) { for (const url of batch) active.delete(url); break; }
        await Promise.all(batch.map(async url => {
          try { await collect(url); }
          catch { if (!stop) { failedPages++; finished.add(visitKey(url)); addError('RUNTIME_ERROR', url, 'Page creation failed', 'runtime'); } }
          finally { active.delete(url); }
        }));
        await progress();
      }
      if (queue.length && !stop) addError('RESOURCE_LIMIT', null, 'Maximum page count reached with pending URLs', 'limit');
    }
  } catch (error) {
    if (!stop) { fatalError = true; addError('RUNTIME_ERROR', null, errorMessage(error), 'runtime'); }
  } finally {
    await closeBrowser();
  }
  scope.unvisitedUrls = [...accepted].filter(([key]) => !finished.has(key)).map(([, url]) => url);
  try { await progress(); }
  finally { clearTimeout(timer); options.signal?.removeEventListener('abort', abort); }
  const state: TerminalRunState = stop === 'cancelled' ? 'cancelled' :
    errors.length || scope.unvisitedUrls.length ? (pages.length || stop === 'time' || stop === 'resource' ? 'partial' : 'failed') : 'completed';
  return { state, pages, errors, scope, counts: counts(), fatalError };
}
