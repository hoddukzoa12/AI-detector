import { createHash } from 'node:crypto';
import { mkdtemp, open, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { Browser, Frame } from 'playwright';
import type { CapturedImageAssets, CollectedImageOccurrence, ImageReasonCode, ImageScratchAsset } from '../core/v2.js';

export interface ImageCollectionOptions {
  enabled: boolean;
  /** DOM evidence onPage precedes this callback. Scratch files live until this promise settles. */
  onImage: (occurrence: CollectedImageOccurrence, result: ImageAcquisitionResult) => void | Promise<void>;
  scratchRoot?: string; maxImageBytes?: number; maxImagePixels?: number; imageTimeoutMs?: number; maxRedirects?: number;
}
export type ImageAcquisitionResult = { status: 'captured'; assets: CapturedImageAssets } | {
  status: 'error' | 'unsupported' | 'cancelled' | 'not_started' | 'not_selected';
  reasonCode: ImageReasonCode; message: string; original?: ImageScratchAsset; capturedAt?: string;
};
export const IMAGE_CAPTURE_DEFAULTS = { maxImageBytes: 8 * 1024 * 1024, maxImagePixels: 16_000_000, imageTimeoutMs: 20_000, maxRedirects: 5 } as const;
class ImageFailure extends Error {
  constructor(readonly reasonCode: ImageReasonCode, message: string) { super(message); }
}
function safeAssetUrl(value: string): URL {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) throw new ImageFailure('IMAGE_FETCH_ERROR', 'Image asset URL is not permitted');
  return url;
}
function sniff(bytes: Buffer, supplied: string): string {
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return 'image/png';
  if (bytes[0] === 255 && bytes[1] === 216) return 'image/jpeg';
  if (bytes.subarray(0, 2).toString() === 'BM') return 'image/bmp';
  if (bytes.subarray(0, 4).equals(Buffer.from([0, 0, 1, 0]))) return 'image/x-icon';
  if (/^GIF8[79]a/.test(bytes.subarray(0, 6).toString())) return 'image/gif';
  if (bytes.subarray(0, 4).toString() === 'RIFF' && bytes.subarray(8, 12).toString() === 'WEBP') return 'image/webp';
  if (bytes.subarray(4, 8).toString() === 'ftyp' && /avif|avis/.test(bytes.subarray(8, 32).toString())) return 'image/avif';
  const mime = supplied.split(';')[0]!.trim().toLowerCase();
  if (mime === 'image/svg+xml' || /^\s*(?:<\?xml[^>]*>\s*)?<svg[\s>]/i.test(bytes.subarray(0, 4096).toString())) return 'image/svg+xml';
  // Known malformed images remain decode errors, never unsupported successes.
  if (['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/avif', 'image/bmp', 'image/x-icon'].includes(mime)) return mime;
  throw new ImageFailure('IMAGE_UNSUPPORTED', 'Asset is outside supported image formats');
}
/** Read encoded dimensions before Chromium allocates raster pixels. */
function encodedSize(bytes: Buffer, mime: string): { width: number; height: number } | null {
  if (mime === 'image/png' && bytes.length >= 24) return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
  if (mime === 'image/gif' && bytes.length >= 10) return { width: bytes.readUInt16LE(6), height: bytes.readUInt16LE(8) };
  if (mime === 'image/bmp' && bytes.length >= 26) return { width: Math.abs(bytes.readInt32LE(18)), height: Math.abs(bytes.readInt32LE(22)) };
  if (mime === 'image/jpeg') for (let offset = 2; offset + 9 < bytes.length;) {
    if (bytes[offset] !== 255) { offset++; continue; }
    const marker = bytes[offset + 1]!;
    if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) return { height: bytes.readUInt16BE(offset + 5), width: bytes.readUInt16BE(offset + 7) };
    if (marker === 0xd8 || marker === 0xd9 || marker === 0x01 || marker >= 0xd0 && marker <= 0xd7) { offset += 2; continue; }
    const length = bytes.readUInt16BE(offset + 2); if (length < 2) break; offset += 2 + length;
  }
  if (mime === 'image/webp') for (let offset = 12; offset + 18 <= bytes.length;) {
    const kind = bytes.subarray(offset, offset + 4).toString(); const size = bytes.readUInt32LE(offset + 4); const data = offset + 8;
    if (kind === 'VP8X' && data + 10 <= bytes.length) return { width: 1 + bytes.readUIntLE(data + 4, 3), height: 1 + bytes.readUIntLE(data + 7, 3) };
    if (kind === 'VP8 ' && data + 10 <= bytes.length) return { width: bytes.readUInt16LE(data + 6) & 0x3fff, height: bytes.readUInt16LE(data + 8) & 0x3fff };
    if (kind === 'VP8L' && data + 5 <= bytes.length) { const bits = bytes.readUInt32LE(data + 1); return { width: (bits & 0x3fff) + 1, height: ((bits >>> 14) & 0x3fff) + 1 }; }
    offset += 8 + size + (size % 2);
  }
  if (mime === 'image/avif') {
    const index = bytes.indexOf('ispe');
    if (index >= 4 && index + 16 <= bytes.length && bytes.readUInt32BE(index - 4) >= 20) return { width: bytes.readUInt32BE(index + 8), height: bytes.readUInt32BE(index + 12) };
  }
  return null;
}
/** Only called for an observed image, never an arbitrary user proxy URL. Files are scoped to this callback. */
export async function acquireCollectedImage(browser: Browser, frame: Frame, occurrence: CollectedImageOccurrence,
  options: ImageCollectionOptions, signal?: AbortSignal): Promise<void> {
  if (!options.enabled) { await options.onImage(occurrence, { status: 'not_selected', reasonCode: 'OCR_NOT_SELECTED', message: 'OCR was not selected' }); return; }
  if (signal?.aborted) { await options.onImage(occurrence, { status: 'not_started', reasonCode: signal.reason === 'TIME_LIMIT' ? 'TIME_LIMIT' : 'USER_CANCELLED', message: 'Image work was not started' }); return; }
  const limits = { ...IMAGE_CAPTURE_DEFAULTS, ...options };
  const directory = await mkdtemp(join(options.scratchRoot ?? tmpdir(), 'inspector-image-'));
  const timeout = new AbortController();
  const timer = setTimeout(() => timeout.abort('TIME_LIMIT'), limits.imageTimeoutMs);
  const workSignal = signal ? AbortSignal.any([signal, timeout.signal]) : timeout.signal;
  let original: ImageScratchAsset | undefined, capturedAt: string | undefined;
  let outcome: ImageAcquisitionResult;
  let stage: 'fetch' | 'decode' = 'fetch';
  try {
    let mime = ''; let finalUrl: string | null = null;
    const scratchPath = join(directory, 'original.bin');
    const handle = await open(scratchPath, 'wx', 0o600);
    const digest = createHash('sha256'); let byteLength = 0;
    try {
      if (occurrence.selectedUrl.startsWith('data:') || occurrence.selectedUrl.startsWith('blob:')) {
        const local = await frame.evaluate(async ({ url, maxBytes, timeoutMs }) => {
          const response = await fetch(url, { signal: AbortSignal.timeout(timeoutMs) });
          if (!response.ok || !response.body) throw new Error('Selected local image unavailable');
          const reader = response.body.getReader(); const chunks: Uint8Array[] = []; let size = 0;
          try { while (true) { const chunk = await reader.read(); if (chunk.done) break; size += chunk.value.length;
            if (size > maxBytes) throw new Error('RESOURCE_LIMIT'); chunks.push(chunk.value); } }
          finally { await reader.cancel().catch(() => {}); }
          const bytes = new Uint8Array(size); let offset = 0;
          for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
          let binary = ''; for (let i = 0; i < bytes.length; i += 16384) binary += String.fromCharCode(...bytes.subarray(i, i + 16384));
          return { base64: btoa(binary), mime: response.headers.get('content-type') ?? '' };
        }, { url: occurrence.selectedUrl, maxBytes: limits.maxImageBytes, timeoutMs: limits.imageTimeoutMs });
        workSignal.throwIfAborted();
        const bytes = Buffer.from(local.base64, 'base64');
        if (bytes.length > limits.maxImageBytes) throw new ImageFailure('RESOURCE_LIMIT', 'Image original byte limit reached');
        mime = local.mime; byteLength = bytes.length; digest.update(bytes); await handle.writeFile(bytes);
      } else {
        let url = safeAssetUrl(occurrence.selectedUrl);
        for (let redirects = 0; ; redirects++) {
          workSignal.throwIfAborted();
          const response = await fetch(url, { redirect: 'manual', signal: workSignal, credentials: 'omit' });
          if (response.status >= 300 && response.status < 400) {
            await response.body?.cancel();
            if (redirects >= limits.maxRedirects) throw new ImageFailure('IMAGE_FETCH_ERROR', 'Image redirect limit reached');
            const location = response.headers.get('location');
            if (!location) throw new ImageFailure('IMAGE_FETCH_ERROR', 'Image redirect has no destination');
            url = safeAssetUrl(new URL(location, url).href); continue;
          }
          if (!response.ok || !response.body) { await response.body?.cancel(); throw new ImageFailure('IMAGE_FETCH_ERROR', `Image asset returned HTTP ${response.status}`); }
          if (Number(response.headers.get('content-length')) > limits.maxImageBytes) { await response.body.cancel(); throw new ImageFailure('RESOURCE_LIMIT', 'Image original byte limit reached'); }
          mime = response.headers.get('content-type') ?? ''; finalUrl = url.href;
          const reader = response.body.getReader();
          try { while (true) { const chunk = await reader.read(); if (chunk.done) break;
            workSignal.throwIfAborted(); byteLength += chunk.value.byteLength;
            if (byteLength > limits.maxImageBytes) throw new ImageFailure('RESOURCE_LIMIT', 'Image original byte limit reached');
            digest.update(chunk.value); await handle.writeFile(chunk.value); } }
          finally { await reader.cancel().catch(() => {}); }
          break;
        }
      }
    } finally { await handle.close(); }
    if (!byteLength) throw new ImageFailure('IMAGE_DECODE_ERROR', 'Image asset is empty');
    const bytes = await readFile(scratchPath);
    // Preserve bounded fetched originals even for unsupported or malformed content.
    original = { scratchPath, sha256: digest.digest('hex'), mime: mime.split(';')[0]!.trim() || 'application/octet-stream', byteLength };
    capturedAt = new Date().toISOString();
    occurrence.imageUrl = finalUrl;
    stage = 'decode'; mime = sniff(bytes, mime); original.mime = mime;
    const dimensions = encodedSize(bytes, mime);
    if (dimensions && (!dimensions.width || !dimensions.height || dimensions.width * dimensions.height > limits.maxImagePixels)) throw new ImageFailure('RESOURCE_LIMIT', 'Image pixel limit reached');
    const decoder = await browser.newContext({ serviceWorkers: 'block', acceptDownloads: false });
    let abortDecoder: () => void = () => {};
    try {
      await decoder.route('**/*', route => route.abort('blockedbyclient'));
      const page = await decoder.newPage();
      abortDecoder = () => { void decoder.close().catch(() => {}); };
      workSignal.addEventListener('abort', abortDecoder, { once: true }); workSignal.throwIfAborted();
      const decoded = await page.evaluate(async ({ base64, mime, maxPixels, maxBytes }) => {
        const bytes = Uint8Array.from(atob(base64), character => character.charCodeAt(0));
        if (mime === 'image/svg+xml') {
          const svg = new DOMParser().parseFromString(new TextDecoder().decode(bytes), 'image/svg+xml').documentElement;
          const viewBox = (svg.getAttribute('viewBox') ?? '').trim().split(/[\s,]+/).map(Number);
          const width = parseFloat(svg.getAttribute('width') ?? '') || viewBox[2] || 300;
          const height = parseFloat(svg.getAttribute('height') ?? '') || viewBox[3] || 150;
          if (width * height > maxPixels) throw new Error('RESOURCE_LIMIT');
        }
        const blob = new Blob([bytes], { type: mime });
        const globals = globalThis as unknown as { ImageDecoder?: { new(options: { data: Uint8Array; type: string }): { tracks: { ready: Promise<void> }; decode(options: { frameIndex: number }): Promise<{ image: VideoFrame }>; close(): void }; isTypeSupported(mime: string): Promise<boolean> } };
        let image: CanvasImageSource; let width: number; let height: number; let release: () => void;
        if (globals.ImageDecoder && await globals.ImageDecoder.isTypeSupported(mime)) {
          const decoder = new globals.ImageDecoder({ data: bytes, type: mime });
          try { await decoder.tracks.ready; const frame = (await decoder.decode({ frameIndex: 0 })).image;
            image = frame; width = frame.displayWidth; height = frame.displayHeight; release = () => { frame.close(); decoder.close(); }; }
          catch (error) { decoder.close(); throw error; }
        } else {
          // SVG is only an image resource in an isolated blank document: scripts and external requests cannot execute.
          const url = URL.createObjectURL(blob); const element = new Image(); element.src = url;
          try { await element.decode(); } catch (error) { URL.revokeObjectURL(url); throw error; }
          image = element; width = element.naturalWidth; height = element.naturalHeight; release = () => URL.revokeObjectURL(url);
        }
        try {
          if (!width || !height || width * height > maxPixels) throw new Error('RESOURCE_LIMIT');
          const canvas = new OffscreenCanvas(width, height); const context = canvas.getContext('2d');
          if (!context) throw new Error('Image decode unavailable'); context.drawImage(image, 0, 0);
          const png = await canvas.convertToBlob({ type: 'image/png' });
          if (png.size > maxBytes) throw new Error('RESOURCE_LIMIT');
          const output = new Uint8Array(await png.arrayBuffer()); let binary = '';
          for (let i = 0; i < output.length; i += 16384) binary += String.fromCharCode(...output.subarray(i, i + 16384));
          return { base64: btoa(binary), width, height };
        } finally { release(); }
      }, { base64: bytes.toString('base64'), mime, maxPixels: limits.maxImagePixels, maxBytes: limits.maxImageBytes });
      workSignal.throwIfAborted();
      const png = Buffer.from(decoded.base64, 'base64'); const inputPath = join(directory, 'input.png');
      await writeFile(inputPath, png, { mode: 0o600, flag: 'wx' });
      outcome = { status: 'captured', assets: { imageId: occurrence.imageId, capturedAt, original,
        input: { scratchPath: inputPath, sha256: createHash('sha256').update(png).digest('hex'), mime: 'image/png', byteLength: png.length, width: decoded.width, height: decoded.height, frameIndex: 0 } } };
    } finally { workSignal.removeEventListener('abort', abortDecoder); await decoder.close().catch(() => {}); }
  } catch (error) {
    const limit = error instanceof Error && error.message.includes('RESOURCE_LIMIT');
    const reasonCode: ImageReasonCode = workSignal.aborted ? (signal?.aborted ? (signal.reason === 'TIME_LIMIT' ? 'TIME_LIMIT' : signal.reason === 'RESOURCE_LIMIT' ? 'RESOURCE_LIMIT' : 'USER_CANCELLED') : stage === 'decode' ? 'IMAGE_DECODE_ERROR' : 'IMAGE_FETCH_ERROR') : limit ? 'RESOURCE_LIMIT' : error instanceof ImageFailure ? error.reasonCode : stage === 'decode' ? 'IMAGE_DECODE_ERROR' : 'IMAGE_FETCH_ERROR';
    outcome = { status: reasonCode === 'USER_CANCELLED' ? 'cancelled' : reasonCode === 'IMAGE_UNSUPPORTED' ? 'unsupported' : 'error', reasonCode,
      message: reasonCode === 'RESOURCE_LIMIT' ? 'Image resource limit reached' : timeout.signal.aborted && !signal?.aborted ? (stage === 'decode' ? 'Image decoding timed out' : 'Image acquisition timed out') : reasonCode === 'TIME_LIMIT' ? 'Image work deadline reached' : reasonCode === 'USER_CANCELLED' ? 'Image work cancelled' : stage === 'decode' ? 'Image decoding failed' : 'Image acquisition failed', ...(original ? { original, capturedAt } : {}) };
  } finally { clearTimeout(timer); }
  try { await options.onImage(occurrence, outcome); }
  finally { await rm(directory, { recursive: true, force: true }); }
}
