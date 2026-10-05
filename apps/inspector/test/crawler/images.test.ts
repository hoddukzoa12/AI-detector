import { afterAll, beforeAll, expect, it } from 'vitest';
import { chromium } from 'playwright';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { crawl } from '../../src/crawler/index.js';
import type { CollectedImageOccurrence } from '../../src/core/v2.js';
import type { ImageAcquisitionResult } from '../../src/crawler/images.js';
import { startOcrFixtureSite, type OcrFixtureSite } from '../fixtures/ocr-site.js';
import { assetTruth, imageTruth, menuTruth } from '../fixtures/ocr-truth.js';
let site: OcrFixtureSite;
const quick = { executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath(), maxPages: 1, dynamicWaitMs: 150, resourceWaitMs: 1000, scrollSteps: 0 };
beforeAll(async () => { site = await startOcrFixtureSite(); });
afterAll(async () => { await site.stop(); });
it('collects actual selected assets, URL layers, pseudos and all frame owners with independent byte truth', async () => {
  const seen: { occurrence: CollectedImageOccurrence; result: ImageAcquisitionResult; original?: Buffer; input?: Buffer }[] = [];
  await crawl(site.urls.images, { ...quick, images: { enabled: true, async onImage(occurrence, result) {
    seen.push({ occurrence, result, ...(result.status === 'captured' ? { original: await readFile(result.assets.original.scratchPath), input: await readFile(result.assets.input.scratchPath) } : {}) });
  } } });
  expect(seen.length).toBe(imageTruth.length);
  for (const truth of imageTruth) {
    const observed = seen.find(item => item.occurrence.location.endsWith(truth.selector) && item.occurrence.framePath.length === truth.framePath.length && item.occurrence.framePath.every((path, i) => (path.includes(truth.framePath[i]!.replace('iframe#', '#')) || (truth.framePath[i] === 'iframe#external' && path.includes(site.externalOrigin + '/frames/external')) || (truth.framePath[i] === 'iframe#nested' && path.includes(site.externalOrigin + '/frames/nested')))) && item.occurrence.sourceKind === truth.sourceKind && item.occurrence.sourceIndex === truth.sourceIndex);
    expect(observed, truth.id).toBeDefined();
    expect(observed!.result.status, truth.id).toBe('captured');
    const asset = assetTruth.find(asset => asset.id === truth.assetId)!;
    expect(createHash('sha256').update(observed!.original!).digest('hex'), truth.id).toBe(asset.sha256);
    expect(observed!.occurrence.links).toEqual(truth.relatedHref ? [site.origin + truth.relatedHref] : []);
    if (truth.concealment) expect(observed!.occurrence.concealment).toContain(truth.concealment);
    if (observed!.result.status === 'captured') {
      expect(observed!.result.assets.input).toMatchObject({ mime: 'image/png', width: asset.width, height: asset.height, frameIndex: 0 });
      expect(createHash('sha256').update(observed!.input!).digest('hex')).toBe(observed!.result.assets.input.sha256);
    }
  }
  expect(new Set(seen.map(item => item.occurrence.imageId)).size).toBe(seen.length);
  expect(site.requests.some(request => request.origin === 'external' && request.path === '/outside')).toBe(false);
}, 60000);
it('keeps the 22 menu titles free of sibling links and parent text while preserving direct owner text', async () => {
  const result = await crawl(site.urls.menu, quick);
  for (const truth of menuTruth) {
    const owner = result.pages[0]!.frames[0]!.elements.find(element => element.location === truth.selector)!;
    expect(owner.rawText).toBe(truth.rawText);
    expect(owner.links, truth.id).toEqual(truth.relatedHref ? [site.origin + truth.relatedHref] : []);
    expect(owner.contextText).toBe(truth.rawText);
  }
});
it('reports acquisition and decode failures by occurrence, preserving acquired original for decode failure', async () => {
  const seen: ImageAcquisitionResult[] = [];
  await crawl(site.urls.exceptions, { ...quick, images: { enabled: true, onImage(_occurrence, result) { seen.push(result); } } });
  expect(seen).toHaveLength(3);
  expect(seen[0]).toMatchObject({ status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', original: { byteLength: 16 } });
  expect(seen.slice(1).every(result => result.status === 'error' && result.reasonCode === 'IMAGE_FETCH_ERROR')).toBe(true);
});
it('unselected images only report occurrences and never start acquisition', async () => {
  const seen: ImageAcquisitionResult[] = [];
  await crawl(site.urls.exceptions, { ...quick, images: { enabled: false, onImage(_occurrence, result) { seen.push(result); } } });
  expect(seen).toHaveLength(3);
  expect(seen.every(result => result.status === 'not_selected')).toBe(true);
});
it('delivers every image identity and DOM snapshot before cancellation in onPage', async () => {
  const controller = new AbortController(); let discovered = 0; let callbacks = 0;
  const result = await crawl(site.urls.images, { ...quick, signal: controller.signal,
    onPage(page) { discovered = page.images!.length; for (const image of page.images!) expect(page.frames.some(frame => frame.snapshotId === image.snapshotId)).toBe(true); controller.abort(); },
    images: { enabled: true, onImage() { callbacks++; } } });
  expect(discovered).toBe(imageTruth.length); expect(callbacks).toBe(0); expect(result.state).toBe('cancelled'); expect(result.pages).toHaveLength(1);
});
it('preserves discovery and acquired bytes when the first image callback cancels further work', async () => {
  const controller = new AbortController(); let discovered = 0; let callbacks = 0; let scratch = '';
  const result = await crawl(site.urls.images, { ...quick, signal: controller.signal,
    onPage(page) { discovered = page.images!.length; }, images: { enabled: true, async onImage(_occurrence, result) {
      callbacks++; expect(discovered).toBe(imageTruth.length); expect(result.status).toBe('captured');
      if (result.status === 'captured') { scratch = result.assets.original.scratchPath; expect((await readFile(scratch)).length).toBe(result.assets.original.byteLength); }
      controller.abort();
    } } });
  expect(callbacks).toBe(1); expect(result.state).toBe('cancelled'); await expect(readFile(scratch)).rejects.toThrow();
});
it('enforces original byte and encoded pixel limits before analysis without turning failure into no_text', async () => {
  for (const limit of [{ maxImageBytes: 1 }, { maxImagePixels: 1 }]) {
    const seen: ImageAcquisitionResult[] = [];
    await crawl('maxImagePixels' in limit ? site.urls.images : site.urls.exceptions, { ...quick, images: { ...limit, enabled: true, onImage(_image, result) { seen.push(result); } } });
    expect(seen).toHaveLength('maxImagePixels' in limit ? imageTruth.length : 3); expect(seen.every(result => result.status !== 'captured')).toBe(true);
    if ('maxImagePixels' in limit) expect(seen.every(result => result.status === 'error' && result.reasonCode === 'RESOURCE_LIMIT' && result.original)).toBe(true);
  }
});
it('decodes animation frame zero to the independently authored first-frame pixels', async () => {
  let input: Buffer | undefined;
  await crawl(site.urls.images, { ...quick, images: { enabled: true, async onImage(image, result) {
    if (image.location === '#animation' && result.status === 'captured') input = await readFile(result.assets.input.scratchPath);
  } } });
  expect(input).toBeDefined();
  const truth = await readFile(new URL('../fixtures/ocr-assets/animation-first.png', import.meta.url));
  const browser = await chromium.launch({ executablePath: quick.executablePath });
  try { const page = await browser.newPage();
    const equal = await page.evaluate(async ({ actual, expected }) => {
      const pixels = async (value: string) => { const bitmap = await createImageBitmap(new Blob([Uint8Array.from(atob(value), character => character.charCodeAt(0))], { type: 'image/png' }));
        const canvas = new OffscreenCanvas(bitmap.width, bitmap.height); const context = canvas.getContext('2d')!; context.drawImage(bitmap, 0, 0); bitmap.close(); return context.getImageData(0, 0, canvas.width, canvas.height).data; };
      const left = await pixels(actual), right = await pixels(expected); return left.length === right.length && left.every((byte, i) => byte === right[i]);
    }, { actual: input!.toString('base64'), expected: truth.toString('base64') }); expect(equal).toBe(true);
  } finally { await browser.close(); }
}, 60000);
it('observes CSS escaped URL layers and hidden ancestors without changing DOM/style or using font size for images', async () => {
  const { captureDocument } = await import('../../src/dom/index.js');
  const browser = await chromium.launch({ executablePath: quick.executablePath });
  try { const page = await browser.newPage();
    await page.setContent(`<style>#surface::before{content:"";display:block;background-image:url("https://asset.invalid/a(b),c.png")}#tiny{font-size:0;width:20px;height:20px}#gradient{background-image:linear-gradient(white,black)}</style><div style="opacity:0"><div id="surface" style="width:20px;height:20px;background-image:url('https://asset.invalid/a(b),c.png'),linear-gradient(red,blue),url('https://asset.invalid/second.png')"></div></div><img id="tiny" src="https://asset.invalid/tiny.png"><div id="gradient">ordinary text</div>`);
    const before = await page.content(); const stylesBefore = await page.locator('#surface').evaluate(element => getComputedStyle(element).cssText);
    const data = await page.evaluate(captureDocument, { framePath: [], maxElements: 1000, maxHtmlBytes: 1000000, captureImages: true });
    expect(data.images.filter(image => image.location === '#surface').map(image => [image.sourceKind, image.sourceIndex, image.selectedUrl])).toEqual([
      ['css_background', 0, 'https://asset.invalid/a(b),c.png'], ['css_background', 1, 'https://asset.invalid/second.png'], ['css_before', 0, 'https://asset.invalid/a(b),c.png']]);
    expect(data.images.filter(image => image.location === '#surface').every(image => image.concealment.includes('TRANSPARENT'))).toBe(true);
    expect(data.images.find(image => image.location === '#tiny')!.concealment).not.toContain('OFFSCREEN');
    expect(data.images.some(image => image.location === '#gradient')).toBe(false);
    expect(await page.content()).toBe(before); expect(await page.locator('#surface').evaluate(element => getComputedStyle(element).cssText)).toBe(stylesBefore);
  } finally { await browser.close(); }
});
it('bounds redirect hops, forbids credential destinations and cancels an in-flight asset GET', async () => {
  const { createServer } = await import('node:http');
  const { acquireCollectedImage } = await import('../../src/crawler/images.js');
  const controller = new AbortController();
  const server = createServer((request, response) => {
    if (request.url === '/loop') { response.writeHead(302, { location: '/loop' }).end(); return; }
    if (request.url === '/credential') { response.writeHead(302, { location: 'http://user:pass@127.0.0.1/private' }).end(); return; }
    response.writeHead(200, { 'content-type': 'image/png' }); response.write(Buffer.from([137, 80, 78, 71])); if (request.url === '/slow') controller.abort();
  });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address(); if (!address || typeof address === 'string') throw new Error('Missing address');
  const origin = `http://127.0.0.1:${address.port}`;
  const browser = await chromium.launch({ executablePath: quick.executablePath });
  try { const page = await browser.newPage();
    const image: CollectedImageOccurrence = { imageId: 'image-observed', url: site.urls.images, frameUrl: site.urls.images, framePath: [], location: '#observed', snapshotId: 'snapshot-observed', sourceKind: 'img', sourceIndex: 0,
      selectedUrl: origin + '/loop', imageUrl: origin + '/loop', links: [], styles: [], concealment: [], bounds: { x: 0, y: 0, width: 20, height: 20 }, documentBounds: { x: 0, y: 0, width: 20, height: 20 } };
    for (const path of ['/loop', '/credential', '/slow', '/timeout']) {
      let result: ImageAcquisitionResult | undefined;
      await acquireCollectedImage(browser, page.mainFrame(), { ...image, selectedUrl: origin + path }, { enabled: true, maxRedirects: 1, imageTimeoutMs: 50, onImage(_image, acquired) { result = acquired; } }, path === '/slow' ? controller.signal : undefined);
      expect(result).toMatchObject(path === '/slow' ? { status: 'cancelled', reasonCode: 'USER_CANCELLED' } : { status: 'error', reasonCode: 'IMAGE_FETCH_ERROR' });
      expect(JSON.stringify(result)).not.toContain('user:pass'); expect(JSON.stringify(result)).not.toContain('base64');
    }
  } finally { await browser.close(); await new Promise<void>(resolve => { server.close(() => resolve()); server.closeAllConnections(); }); }
});
it('preserves owner concealment for pseudo assets and pseudo-specific computed styles', async () => {
  const { captureDocument } = await import('../../src/dom/index.js');
  const browser = await chromium.launch({ executablePath: quick.executablePath });
  try { const page = await browser.newPage();
    await page.setContent(`<style>#owner{opacity:0;width:30px;height:30px}#owner::before{content:"";display:block;opacity:1;background-image:url("https://asset.invalid/pseudo.png")}#visible{width:30px;height:30px}#visible::after{content:"";display:none;background-image:url("https://asset.invalid/pseudo.png")}</style><div id="owner"></div><div id="visible"></div>`);
    const data = await page.evaluate(captureDocument, { framePath: [], maxElements: 100, maxHtmlBytes: 100000, captureImages: true });
    expect(data.images.find(image => image.location === '#owner')!.concealment).toContain('TRANSPARENT');
    expect(data.images.find(image => image.location === '#visible')!.concealment).toContain('OFFSCREEN');
  } finally { await browser.close(); }
});
it('keeps public image-only content beside an excluded password form', async () => {
  const { createServer } = await import('node:http');
  const server = createServer((_request, response) => response.writeHead(200, { 'content-type': 'text/html' }).end(`<img id="public-image" src="${site.origin}/assets/logo.png"><form><input type="password"><img id="private-image" src="${site.origin}/assets/korean.png"></form>`));
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address(); if (!address || typeof address === 'string') throw new Error('Missing address');
  try { const seen: CollectedImageOccurrence[] = [];
    const result = await crawl(`http://127.0.0.1:${address.port}/`, { ...quick, images: { enabled: false, onImage(image) { seen.push(image); } } });
    expect(result.pages).toHaveLength(1); expect(seen.map(image => image.location)).toEqual(['#public-image']);
  } finally { await new Promise<void>(resolve => { server.close(() => resolve()); server.closeAllConnections(); }); }
});
