import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { chromium, type Frame } from 'playwright';
import { describe, expect, it } from 'vitest';
import { startOcrFixtureSite } from './ocr-site.js';
import { imageTruth, menuTruth, assetTruth, imageExceptionTruth } from './ocr-truth.js';

async function resolve(frame: Frame, path: readonly string[]): Promise<Frame> {
  for (const selector of path) {
    expect(await frame.locator(selector).count()).toBe(1);
    const owner = await frame.$(selector);
    const next = await owner!.contentFrame();
    expect(next).not.toBeNull();
    frame = next!;
  }
  return frame;
}

describe('independent OCR assets and ownership truth', () => {
  it('serves exact checked-in bytes with fixed hashes and declared media types', async () => {
    const site = await startOcrFixtureSite();
    try {
      for (const asset of assetTruth) {
        const bytes = await readFile(new URL(`./ocr-assets/${asset.file}`, import.meta.url));
        expect(createHash('sha256').update(bytes).digest('hex'), asset.id).toBe(asset.sha256);
        expect(bytes.byteLength, asset.id).toBe(asset.byteLength);
        if (asset.mime === 'image/png') expect(bytes.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a');
        if (asset.mime === 'image/jpeg') expect(bytes.subarray(0, 3).toString('hex')).toBe('ffd8ff');
        if (asset.mime === 'image/webp') expect(bytes.subarray(8, 12).toString()).toBe('WEBP');
        if (asset.mime === 'image/avif') expect(bytes.subarray(4, 12).toString()).toBe('ftypavif');
        if (asset.mime === 'image/gif') expect(bytes.subarray(0, 6).toString()).toBe('GIF89a');
        const response = await fetch(site.origin + '/assets/' + asset.file);
        expect(response.headers.get('content-type')).toBe(asset.mime);
        expect(Buffer.from(await response.arrayBuffer())).toEqual(bytes);
      }
      expect((await fetch(site.origin + '/assets/../ocr-truth.ts')).status).toBe(404);
      expect((await fetch(site.origin, { method: 'POST' })).status).toBe(405);
    } finally { await site.stop(); await site.stop(); }
  });

  it('exposes each unique frame/owner/layer with actual selected asset bytes in Chromium', async () => {
    const site = await startOcrFixtureSite();
    const browser = await chromium.launch({ headless: true });
    try {
      const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
      await page.goto(site.urls.images);
      await page.waitForFunction(() => document.body.dataset.ready === 'true');
      const identities = new Set<string>();
      for (const truth of imageTruth) {
        const frame = await resolve(page.mainFrame(), truth.framePath);
        const owner = frame.locator(truth.selector);
        expect(await owner.count(), truth.id).toBe(1);
        const observed = await owner.evaluate((element, item) => {
          const style = getComputedStyle(element, item.kind === 'css_before' ? '::before' : item.kind === 'css_after' ? '::after' : null);
          const urls = Array.from(style.backgroundImage.matchAll(/url\("?([^")]+)"?\)/g), match => match[1]);
          return { url: item.kind === 'img' ? (element as HTMLImageElement).currentSrc : urls[item.index], display: style.display, opacity: style.opacity, left: element.getBoundingClientRect().left, relatedHref: element.closest('a[href]')?.getAttribute('href') ?? null, directText: Array.from(element.childNodes).filter(node => node.nodeType === Node.TEXT_NODE).map(node => node.textContent).join('') };
        }, { kind: truth.sourceKind, index: truth.sourceIndex });
        expect(observed.url, truth.id).toBeTruthy();
        const selectedHash = await frame.evaluate(async url => {
          const bytes = await (await fetch(url)).arrayBuffer();
          return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), value => value.toString(16).padStart(2, '0')).join('');
        }, observed.url);
        expect(selectedHash, truth.id).toBe(assetTruth.find(asset => asset.id === truth.assetId)!.sha256);
        if (truth.concealment === 'TRANSPARENT') expect(observed.opacity).toBe('0');
        if (truth.concealment === 'OFFSCREEN') expect(observed.display === 'none' || observed.left < -1000).toBe(true);
        expect(observed.directText, truth.id).toBe(truth.directText);
        expect(observed.relatedHref, truth.id).toBe(truth.relatedHref);
        if (truth.sourceKind === 'img') expect(await owner.evaluate(element => [(element as HTMLImageElement).naturalWidth, (element as HTMLImageElement).naturalHeight]), truth.id).toEqual([640, 160]);
        if (truth.external) expect(new URL(frame.url()).hostname).toBe('localhost');
        const identity = [...truth.framePath, truth.selector, truth.sourceKind, String(truth.sourceIndex)].join(' >>> ');
        expect(identities.has(identity), truth.id).toBe(false); identities.add(identity);
      }
      expect(await page.locator('#selected').getAttribute('src')).toBe('/assets/logo.png');
      expect(await page.locator('#selected').evaluate(element => (element as HTMLImageElement).currentSrc)).toBe(site.origin + '/assets/korean.png');
      expect(await page.locator('#layers').evaluate(element => getComputedStyle(element).backgroundImage)).toContain('linear-gradient');
      expect(await page.locator('#same-a').getAttribute('src')).toBe(await page.locator('#same-b').getAttribute('src'));
      expect(await page.locator('#blank').getAttribute('src')).toBeNull();
      expect(site.requests.some(request => request.path === '/outside' || request.path === '/destination')).toBe(false);
    } finally { await browser.close(); await site.stop(); }
  });

  it('exposes malformed supported-format and failed HTTP images as independent errors', async () => {
    const site = await startOcrFixtureSite();
    const browser = await chromium.launch({ headless: true });
    try {
      const page = await browser.newPage(); await page.goto(site.urls.exceptions);
      for (const item of imageExceptionTruth) {
        const response = await fetch(site.origin + item.imagePath);
        expect(response.status).toBe(item.httpStatus);
        if (item.sha256) {
          const bytes = Buffer.from(await response.arrayBuffer());
          expect(bytes.length).toBe(item.byteLength);
          expect(createHash('sha256').update(bytes).digest('hex')).toBe(item.sha256);
        }
        const owner = page.locator(item.selector);
        expect(await owner.count()).toBe(1);
        expect(await owner.evaluate(element => [(element as HTMLImageElement).complete, (element as HTMLImageElement).naturalWidth])).toEqual([true, 0]);
      }
    } finally { await browser.close(); await site.stop(); }
  });

  it('decodes GIF frame zero to the independent first-frame reference in Chromium', async () => {
    const site = await startOcrFixtureSite();
    const browser = await chromium.launch({ headless: true });
    try {
      const page = await browser.newPage(); await page.goto(site.urls.images);
      const pixels = await page.evaluate(async () => {
        const png = new Image(); png.src = '/assets/animation-first.png'; await png.decode();
        const Decoder = (globalThis as unknown as { ImageDecoder: new (options: { data: ArrayBuffer; type: string }) => { decode(options: { frameIndex: number }): Promise<{ image: CanvasImageSource & { close(): void } }>; close(): void } }).ImageDecoder;
        const decoder = new Decoder({ data: await (await fetch('/assets/animated.gif')).arrayBuffer(), type: 'image/gif' });
        const first = await decoder.decode({ frameIndex: 0 });
        const digest = async (image: CanvasImageSource) => {
          const canvas = document.createElement('canvas'); canvas.width = 640; canvas.height = 160;
          const context = canvas.getContext('2d')!; context.drawImage(image, 0, 0);
          const bytes = context.getImageData(0, 0, 640, 160).data;
          return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), value => value.toString(16).padStart(2, '0')).join('');
        };
        try { return { gif: await digest(first.image), png: await digest(png) }; }
        finally { first.image.close(); decoder.close(); }
      });
      expect(pixels.gif).toBe(pixels.png);
    } finally { await browser.close(); await site.stop(); }
  });

  it('keeps MEMBER/MENU titles separate from sibling links and preserves direct parent/child positives', async () => {
    const site = await startOcrFixtureSite();
    const browser = await chromium.launch({ headless: true });
    try {
      const page = await browser.newPage(); await page.goto(site.urls.menu);
      for (const truth of menuTruth) {
        const target = page.locator(truth.selector);
        expect(await target.count()).toBe(1);
        const observed = await target.evaluate(element => ({
          raw: Array.from(element.childNodes).filter(node => node.nodeType === Node.TEXT_NODE).map(node => node.textContent).join(''),
          href: element.closest('a[href]')?.getAttribute('href') ?? null,
          style: { opacity: getComputedStyle(element).opacity, fontSize: getComputedStyle(element).fontSize },
          transparentAncestor: Array.from((function*(){let owner: Element | null = element; while(owner){yield owner;owner=owner.parentElement;}})()).some(owner=>getComputedStyle(owner).opacity==='0'),
          hiddenAside: element.closest('aside') ? getComputedStyle(element.closest('aside')!).display : null,
        }));
        expect(observed.raw, truth.id).toBe(truth.rawText);
        expect(observed.href, truth.id).toBe(truth.relatedHref);
        if (truth.technique === 'TRANSPARENT') expect(observed.transparentAncestor).toBe(true);
        if (truth.technique === 'OFFSCREEN' && truth.label === 'illegal_ad') expect(observed.style.fontSize).toBe('0px');
        if (truth.label === 'non_ad') expect(observed.hiddenAside).toBe('none');
      }
      expect(menuTruth.filter(item => item.label === 'non_ad' && /^(MEMBER|MENU)$/.test(item.rawText))).toHaveLength(22);
      expect(await page.locator('#aggregate').evaluate(element => Array.from(element.childNodes).filter(node => node.nodeType === Node.TEXT_NODE).map(node => node.textContent).join(''))).toBe('');
      expect(site.requests.some(request => request.path === '/destination')).toBe(false);
    } finally { await browser.close(); await site.stop(); }
  });
});
