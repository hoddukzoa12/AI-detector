import { createHash } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { emptyRunCounts, type CollectedImageOccurrence, type CapturedImageAssets } from '../../src/core/index.js';
import type { CollectedPageWithImages, CrawlOptions, CrawlResult, ImageAcquisitionResult } from '../../src/crawler/index.js';
export const imageUrl = 'https://public.example.test/images?version=1';
export function png(width = 1): Buffer {
  const chunk = (kind: string, bytes: Buffer) => {
    const payload = Buffer.concat([Buffer.from(kind), bytes]); let crc = 0xffffffff;
    for (const byte of payload) { crc ^= byte; for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0); }
    const result = Buffer.alloc(bytes.length + 12); result.writeUInt32BE(bytes.length); payload.copy(result, 4); result.writeUInt32BE((crc ^ 0xffffffff) >>> 0, result.length - 4); return result;
  };
  const header = Buffer.alloc(13); header.writeUInt32BE(width); header.writeUInt32BE(1, 4); header[8] = 8; header[9] = 6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', deflateSync(Buffer.alloc(1 + width * 4))), chunk('IEND', Buffer.alloc(0))]);
}
export function owner(imageId: string, location = '#banner', sourceKind: CollectedImageOccurrence['sourceKind'] = 'img', sourceIndex = 0): CollectedImageOccurrence {
  const bounds = { x: 0, y: 0, width: 20, height: 20 };
  return { imageId, url: imageUrl, frameUrl: imageUrl, framePath: [], snapshotId: 'image_snapshot', location, sourceKind, sourceIndex,
    selectedUrl: 'https://asset.example.test/banner.png', imageUrl: 'https://asset.example.test/banner.png', links: ['https://destination.example.test/path'],
    styles: [{ elementLocation: location, css: { opacity: '0' }, bounds }], bounds, documentBounds: bounds, concealment: ['TRANSPARENT'] };
}
export function imagePage(images: CollectedImageOccurrence[], dom = false): CollectedPageWithImages {
  const capturedAt = new Date().toISOString(), bounds = { x: 0, y: 0, width: 20, height: 20 };
  return { url: imageUrl, capturedAt, images: structuredClone(images), discoveredUrls: [], frames: [{ frameUrl: imageUrl, framePath: [], snapshotId: 'image_snapshot', capturedAt,
    html: '<p id="text" style="opacity:0">원본 글자</p><img id="banner">',
    elements: dom ? [{ location: '#text', rawText: '원본 글자', links: [], styles: [{ elementLocation: '#text', css: { opacity: '0' }, bounds }],
      tagName: 'p', attributes: {}, contextText: '', accessibility: { role: null, ariaHidden: null, ariaLabel: null }, bounds, documentBounds: bounds }] : [],
    viewport: { width: 800, height: 600, scrollX: 0, scrollY: 0 }, documentSize: { width: 800, height: 600 } }] };
}
export async function assets(root: string, imageId: string, width = 1): Promise<CapturedImageAssets> {
  const bytes = png(width), scratchPath = join(root, imageId + '.png'); await writeFile(scratchPath, bytes);
  const ref = { scratchPath, sha256: createHash('sha256').update(bytes).digest('hex'), mime: 'image/png' as const, byteLength: bytes.length };
  return { imageId, capturedAt: new Date().toISOString(), original: { ...ref }, input: { ...ref, width, height: 1, frameIndex: 0 } };
}
export function imageCrawler(page: CollectedPageWithImages, outcomes: ImageAcquisitionResult[], beforeImage?: (index: number, options: CrawlOptions) => void | Promise<void>) {
  return async (_entry: string, options: CrawlOptions = {}): Promise<CrawlResult> => {
    await options.onPage?.(structuredClone(page));
    for (const [index, image] of page.images!.entries()) {
      if (options.signal?.aborted) break;
      await beforeImage?.(index, options);
      const result = options.images!.enabled ? outcomes[index] : { status: 'not_selected' as const, reasonCode: 'OCR_NOT_SELECTED' as const, message: 'OCR not selected' };
      await options.images!.onImage(image, result);
    }
    return { state: options.signal?.aborted ? 'cancelled' : 'completed', pages: [page], counts: { ...emptyRunCounts(), discoveredPages: 1, scannedPages: 1 }, errors: [],
      scope: { hostname: new URL(imageUrl).hostname, framePolicy: 'embedded', skipped: [], unvisitedUrls: [] } };
  };
}
export function ocrResponse(status = 'readable', text = '읽힌 글자'): Response {
  return new Response(JSON.stringify({ model: 'google/gemini-3.8-flash', choices: [{ finish_reason: 'stop', message: { role: 'assistant', content: JSON.stringify({ status, text }) } }],
    usage: { prompt_tokens: 5, completion_tokens: 3, total_tokens: 8 } }));
}
