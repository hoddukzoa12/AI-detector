import { createServer } from 'node:http';
import { once } from 'node:events';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ImageScratchInput } from '../../src/core/v2.js';
import { validateOcrFile } from '../../src/core/validation-v2.js';
import type { OcrImageOccurrence } from '../../src/core/v2.js';
import { OCR_MODEL } from '../../src/core/v2.js';
import { OcrRunSession, OCR_ENDPOINT, OCR_PROMPT_VERSION, validateOcrResponse } from '../../src/ocr/index.js';

const mockKey = 'mock-only-credential';
function envelope(status = 'readable', text = ' 한글\nEnglish 😀 ', usage: unknown = { prompt_tokens: 20, completion_tokens: 8, total_tokens: 28, cost: .001 }) {
  return { model: OCR_MODEL, choices: [{ finish_reason: 'stop', message: { role: 'assistant', content: JSON.stringify({ status, text }) } }], usage };
}
function reply(value: unknown = envelope(), status = 200) { return new Response(JSON.stringify(value), { status }); }
function transport(handler: (input: string | URL | Request, init?: RequestInit) => Promise<Response>) { return vi.fn(handler) as typeof fetch & ReturnType<typeof vi.fn>; }
let dir: string;
let input: ImageScratchInput;
beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), 'ocr-adapter-'));
  const bytes = await readFile(new URL('../fixtures/ocr-assets/korean.png', import.meta.url));
  const scratchPath = join(dir, 'input.png'); await writeFile(scratchPath, bytes);
  input = { scratchPath, sha256: createHash('sha256').update(bytes).digest('hex'), byteLength: bytes.length, mime: 'image/png', width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), frameIndex: 0 };
});
afterEach(async () => { vi.restoreAllMocks(); await rm(dir, { recursive: true, force: true }); });
function session(fetchFn: typeof fetch, extra = {}) { return new OcrRunSession({ runId: 'test-run', enabled: true, apiKey: mockKey, fetch: fetchFn, ...extra }); }

describe('fixed PNG OCR contract', () => {
  it('sends one PNG to the fixed endpoint/model with strict schema and preserves raw extraction/usage', async () => {
    const http = transport(async (endpoint, init) => {
      expect(endpoint).toBe(OCR_ENDPOINT); expect(init?.method).toBe('POST'); expect(init?.redirect).toBe('error');
      expect(init?.headers).toEqual({ Authorization: `Bearer ${mockKey}`, 'Content-Type': 'application/json' });
      const body = JSON.parse(init?.body as string);
      expect(body.model).toBe(OCR_MODEL); expect(body.max_tokens).toBe(4096); expect(body.provider).toEqual({ require_parameters: true, allow_fallbacks: false });
      expect(body.response_format.type).toBe('json_schema'); expect(body.response_format.json_schema.strict).toBe(true);
      expect(body.response_format.json_schema.schema).toMatchObject({ additionalProperties: false, required: ['status', 'text'] });
      expect(body.messages[0].content).toMatch(/untrusted/i); expect(body.messages[0].content).toMatch(/do not infer/i);
      const items = body.messages[1].content; expect(items).toHaveLength(1); expect(items[0].type).toBe('image_url');
      expect(Buffer.from(items[0].image_url.url.replace('data:image/png;base64,', ''), 'base64')).toEqual(await readFile(input.scratchPath));
      expect(JSON.stringify(body)).not.toContain(mockKey); expect(JSON.stringify(body)).not.toContain(input.scratchPath);
      return reply();
    });
    const run = session(http); const result = await run.analyzeImage('image-a', input, new AbortController().signal);
    expect(result).toMatchObject({ status: 'completed', extractionStatus: 'readable', text: ' 한글\nEnglish 😀 ', confidence: null, model: OCR_MODEL, promptVersion: OCR_PROMPT_VERSION, cacheOf: null, attemptCount: 1, reasonCode: null, usage: { promptTokens: 20, completionTokens: 8, totalTokens: 28, costUsd: .001 } });
    expect(run.requestCount).toBe(1); expect(http).toHaveBeenCalledTimes(1);
  });
  it.each([['partial', '일부'], ['partial', ''], ['no_text', ''], ['unreadable', '']])('preserves %s as completed response with correct review reason', async (status, text) => {
    const run = session(transport(async () => reply(envelope(status, text, undefined))));
    const result = await run.analyzeImage('image-a', input, new AbortController().signal);
    expect(result.extractionStatus).toBe(status); expect(result.text).toBe(text); expect(result.confidence).toBeNull();
    expect(result.reasonCode).toBe(['partial', 'unreadable'].includes(status) ? 'OCR_UNREADABLE' : null);
  });
  it('preserves absent usage as unknown and validates provider usage', () => {
    const value = envelope(); delete (value as { usage?: unknown }).usage;
    expect(validateOcrResponse(value).usage).toEqual({ promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null });
    for (const usage of [{ cost: -1 }, { prompt_tokens: 1.5 }, { completion_tokens: '2' }, { total_tokens: Infinity }, 'bad']) expect(() => validateOcrResponse(envelope('readable', 'x', usage))).toThrow('Invalid OCR response');
  });
  it.each([
    ['other model', (v: ReturnType<typeof envelope>) => { v.model = 'other' as typeof OCR_MODEL; }],
    ['length', (v: ReturnType<typeof envelope>) => { v.choices[0].finish_reason = 'length'; }],
    ['abnormal finish', (v: ReturnType<typeof envelope>) => { v.choices[0].finish_reason = 'error'; }],
    ['refusal', (v: ReturnType<typeof envelope>) => { Object.assign(v.choices[0].message, { refusal: 'secret-response' }); }],
    ['extra extraction key', (v: ReturnType<typeof envelope>) => { v.choices[0].message.content = '{"status":"readable","text":"x","confidence":0.9}'; }],
    ['wrong type', (v: ReturnType<typeof envelope>) => { v.choices[0].message.content = '{"status":"readable","text":1}'; }],
    ['empty readable', (v: ReturnType<typeof envelope>) => { v.choices[0].message.content = '{"status":"readable","text":""}'; }],
    ['nonempty no_text', (v: ReturnType<typeof envelope>) => { v.choices[0].message.content = '{"status":"no_text","text":"x"}'; }],
    ['nonempty unreadable', (v: ReturnType<typeof envelope>) => { v.choices[0].message.content = '{"status":"unreadable","text":"x"}'; }],
    ['bad JSON', (v: ReturnType<typeof envelope>) => { v.choices[0].message.content = '```json\n{}\n```'; }],
    ['multiple choices', (v: ReturnType<typeof envelope>) => { v.choices.push(v.choices[0]); }],
    ['tool call', (v: ReturnType<typeof envelope>) => { Object.assign(v.choices[0].message, { tool_calls: [{}] }); }],
  ])('rejects %s without retry or empty success', async (_label, mutate) => {
    const value = envelope(); mutate(value); const http = transport(async () => reply(value));
    const result = await session(http).analyzeImage('image-a', input, new AbortController().signal);
    expect(result.status).toBe('error'); expect(result.reasonCode).toBe('OCR_RESPONSE_INVALID'); expect(result.text).toBeNull(); expect(result.attemptCount).toBe(1); expect(http).toHaveBeenCalledTimes(1);
  });
  it('rejects oversized JSON and non-JSON responses', async () => {
    for (const body of ['x'.repeat(32769), 'malformed-provider-response']) {
      const http = transport(async () => new Response(body));
      expect(await session(http).analyzeImage('image-a', input, new AbortController().signal)).toMatchObject({ status: 'error', text: null, reasonCode: 'OCR_RESPONSE_INVALID' });
    }
  });
});

describe('actual attempts, limits, cache and interruption', () => {
  it.each([429, 500, 503])('retries HTTP %s once with identical payload and counts actual calls', async status => {
    const bodies: unknown[] = []; const observed: number[] = [];
    const http = transport(async (_url, init) => { bodies.push(init?.body); return bodies.length === 1 ? reply({ private: 'response' }, status) : reply(); });
    const run = session(http, { onRequestStart: (count: number) => observed.push(count) });
    expect(await run.analyzeImage('image-a', input, new AbortController().signal)).toMatchObject({ status: 'completed', attemptCount: 2 });
    expect(bodies[0]).toBe(bodies[1]); expect(observed).toEqual([1, 2]); expect(run.requestCount).toBe(2);
  });
  it.each([400, 401, 402, 403, 404])('does not retry HTTP %s', async status => {
    const http = transport(async () => reply({}, status));
    expect(await session(http).analyzeImage('image-a', input, new AbortController().signal)).toMatchObject({ status: 'error', reasonCode: 'OCR_HTTP_ERROR', attemptCount: 1 });
    expect(http).toHaveBeenCalledTimes(1);
  });
  it('stops after one retry and request limits include retries', async () => {
    const http = transport(async () => reply({}, 503)); const run = session(http);
    expect((await run.analyzeImage('image-a', input, new AbortController().signal)).attemptCount).toBe(2);
    const capped = session(http, { maxRequests: 1 });
    expect(await capped.analyzeImage('image-b', input, new AbortController().signal)).toMatchObject({ status: 'error', reasonCode: 'OCR_HTTP_ERROR', attemptCount: 1 });
    expect(await capped.analyzeImage('image-c', input, new AbortController().signal)).toMatchObject({ status: 'not_started', reasonCode: 'RESOURCE_LIMIT', attemptCount: 0 }); expect(capped.requestCount).toBe(1);
  });
  it.each(['readable', 'no_text'])('shares only completed %s within the same run without copying cost or occurrence identity', async status => {
    const http = transport(async () => reply(envelope(status, status === 'readable' ? '원문' : ''))); const run = session(http, { maxRequests: 1 });
    await run.analyzeImage('original-image', input, new AbortController().signal);
    expect(await run.analyzeImage('other-image', input, new AbortController().signal)).toMatchObject({ cacheOf: 'original-image', attemptCount: 0, usage: { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null } });
    expect(run.requestCount).toBe(1); expect(http).toHaveBeenCalledTimes(1);
    await session(http).analyzeImage('new-run-image', input, new AbortController().signal); expect(http).toHaveBeenCalledTimes(2);
  });
  it.each(['partial', 'unreadable', 'error'])('does not cache %s', async status => {
    const http = transport(async () => status === 'error' ? reply({}, 401) : reply(envelope(status, ''))); const run = session(http);
    await run.analyzeImage('image-a', input, new AbortController().signal); const result = await run.analyzeImage('image-b', input, new AbortController().signal);
    expect(result.cacheOf).toBeNull(); expect(http).toHaveBeenCalledTimes(2);
  });
  it('checks actual bytes, SHA, metadata and limits before transport/cache', async () => {
    const http = transport(async () => reply()); const run = session(http);
    for (const bad of [{ ...input, sha256: '0'.repeat(64) }, { ...input, width: input.width + 1 }, { ...input, mime: 'image/jpeg' as 'image/png' }, { ...input, frameIndex: 1 as 0 }, { ...input, byteLength: input.byteLength + 1 }]) {
      expect(await run.analyzeImage('image-bad', bad, new AbortController().signal)).toMatchObject({ status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', attemptCount: 0 });
    }
    for (const limits of [{ maxImageBytes: 1 }, { maxImagePixels: 1 }]) expect(await session(http, limits).analyzeImage('image-big', input, new AbortController().signal)).toMatchObject({ status: 'not_started', reasonCode: 'RESOURCE_LIMIT' });
    expect(http).not.toHaveBeenCalled();
  });
  it('does not cache mutated inputs or input PNG hash substitutions', async () => {
    const http = transport(async () => reply()); const run = session(http);
    await run.analyzeImage('image-a', input, new AbortController().signal); await writeFile(input.scratchPath, 'not PNG');
    expect(await run.analyzeImage('image-b', input, new AbortController().signal)).toMatchObject({ status: 'error', reasonCode: 'IMAGE_DECODE_ERROR', attemptCount: 0, cacheOf: null }); expect(http).toHaveBeenCalledTimes(1);
  });
  it('disabled OCR, missing credentials, elapsed run deadline and pre-abort start zero requests', async () => {
    const http = transport(async () => reply());
    expect(() => session(http, { apiKey: '' })).toThrow('OCR key must be configured');
    const off = session(http, { enabled: false, apiKey: '' }); expect(await off.analyzeImage('image-a', null, new AbortController().signal)).toMatchObject({ status: 'not_selected', reasonCode: 'OCR_NOT_SELECTED', model: null, attemptCount: 0 });
    const controller = new AbortController(); controller.abort(new Error(mockKey));
    expect(await session(http).analyzeImage('image-a', input, controller.signal)).toMatchObject({ status: 'not_started', reasonCode: 'USER_CANCELLED', attemptCount: 0 });
    expect(await session(http, { deadline: Date.now() - 1 }).analyzeImage('image-a', input, new AbortController().signal)).toMatchObject({ status: 'not_started', reasonCode: 'TIME_LIMIT' }); expect(http).not.toHaveBeenCalled();
  });
  it('counts started transport and blocks late success after cancellation', async () => {
    const controller = new AbortController(); let complete!: (r: Response) => void;
    let calls = 0;
    const http = transport(async () => { if (++calls > 1) return reply(); controller.abort(); return new Promise<Response>(resolve => { complete = resolve; }); });
    const run = session(http); const result = await run.analyzeImage('image-a', input, controller.signal);
    expect(result).toMatchObject({ status: 'cancelled', reasonCode: 'USER_CANCELLED', attemptCount: 1, text: null }); expect(run.requestCount).toBe(1);
    complete(reply()); await new Promise(resolve => setTimeout(resolve, 0));
    expect(result.text).toBeNull(); expect(result.cacheOf).toBeNull();
    await run.analyzeImage('image-b', input, new AbortController().signal); expect(http).toHaveBeenCalledTimes(2);
  });
  it('request observer cancellation prevents an unstarted transport', async () => {
    const controller = new AbortController(); const http = transport(async () => reply());
    const run = session(http, { onProgress: () => controller.abort() });
    expect(await run.analyzeImage('image-a', input, controller.signal)).toMatchObject({ status: 'not_started', attemptCount: 0, reasonCode: 'USER_CANCELLED' }); expect(run.requestCount).toBe(0); expect(http).not.toHaveBeenCalled();
  });
  it('times out fetch and response body even when mock ignores AbortSignal', async () => {
    for (const fn of [async () => new Promise<Response>(() => {}), async () => new Response(new ReadableStream({ start() {} }))]) {
      const http = transport(fn); const run = session(http, { requestTimeoutMs: 10 });
      expect(await run.analyzeImage('image-a', input, new AbortController().signal)).toMatchObject({ status: 'error', reasonCode: 'OCR_TIMEOUT', attemptCount: 1 }); expect(http).toHaveBeenCalledTimes(1);
    }
  });
  it('never logs raw transport exceptions or provider payloads', async () => {
    const log = vi.spyOn(console, 'log'); const warn = vi.spyOn(console, 'warn'); const error = vi.spyOn(console, 'error');
    const http = transport(async () => { throw new Error(`${mockKey} data:image/png;base64,private response`); });
    const run = session(http); expect(JSON.stringify(run)).not.toContain(mockKey);
    const result = await run.analyzeImage('image-a', input, new AbortController().signal);
    expect(result).toMatchObject({ status: 'error', reasonCode: 'OCR_HTTP_ERROR', text: null }); expect(JSON.stringify(result)).not.toContain(mockKey); expect(log).not.toHaveBeenCalled(); expect(warn).not.toHaveBeenCalled(); expect(error).not.toHaveBeenCalled();
  });
});

describe('bounded scheduling and real loopback mock HTTP', () => {
  it('bounds concurrency and pending queue, removing a cancelled queued image without transport', async () => {
    const releases: ((r: Response) => void)[] = []; let active = 0, peak = 0;
    const http = transport(async () => {
      active++; peak = Math.max(peak, active);
      const r = await new Promise<Response>(resolve => releases.push(resolve)); active--; return r;
    });
    const run = session(http, { concurrency: 2, maxPending: 1 });
    const a = run.analyzeImage('image-a', input, new AbortController().signal);
    const b = run.analyzeImage('image-b', input, new AbortController().signal);
    await vi.waitFor(() => expect(http).toHaveBeenCalledTimes(2));
    const queued = new AbortController(); const c = run.analyzeImage('image-c', input, queued.signal);
    const d = await run.analyzeImage('image-d', input, new AbortController().signal);
    expect(d).toMatchObject({ status: 'not_started', reasonCode: 'RESOURCE_LIMIT', attemptCount: 0 });
    queued.abort(); expect(await c).toMatchObject({ status: 'not_started', reasonCode: 'USER_CANCELLED', attemptCount: 0 });
    releases.forEach(resolve => resolve(reply())); await Promise.all([a, b]);
    expect(peak).toBe(2); expect(run.requestCount).toBe(2); expect(http).toHaveBeenCalledTimes(2);
  });
  it('enforces a shared request cap across concurrent tasks and retries', async () => {
    const http = transport(async () => reply({}, 429)); const run = session(http, { maxRequests: 3 });
    const results = await Promise.all(['a', 'b', 'c', 'd'].map(id => run.analyzeImage(id, input, new AbortController().signal)));
    expect(run.requestCount).toBe(3); expect(http).toHaveBeenCalledTimes(3);
    expect(results.reduce((n, r) => n + r.attemptCount, 0)).toBe(3);
    expect(results.filter(r => r.attemptCount === 0).every(r => r.status === 'not_started' && r.reasonCode === 'RESOURCE_LIMIT')).toBe(true);
  });
  it('run deadline interrupts in-flight and queued work distinctly', async () => {
    const http = transport(async () => new Promise<Response>(() => {}));
    const run = session(http, { concurrency: 1, deadline: Date.now() + 100, requestTimeoutMs: 200 });
    const a = run.analyzeImage('image-a', input, new AbortController().signal);
    await vi.waitFor(() => expect(http).toHaveBeenCalledTimes(1), { interval: 1 });
    const b = run.analyzeImage('image-b', input, new AbortController().signal);
    expect(await a).toMatchObject({ status: 'cancelled', reasonCode: 'TIME_LIMIT', attemptCount: 1 });
    expect(await b).toMatchObject({ status: 'not_started', reasonCode: 'TIME_LIMIT', attemptCount: 0 });
    expect(http).toHaveBeenCalledTimes(1);
  });
  it('rejects a streamed response exceeding the byte cap and malformed UTF8', async () => {
    for (const chunks of [[Buffer.alloc(20000, 120), Buffer.alloc(20000, 121)], [Buffer.from([0xff])]]) {
      const http = transport(async () => new Response(new ReadableStream({ start(controller) { chunks.forEach(c => controller.enqueue(c)); controller.close(); } })));
      expect(await session(http).analyzeImage('image-a', input, new AbortController().signal)).toMatchObject({ status: 'error', reasonCode: 'OCR_RESPONSE_INVALID', attemptCount: 1 });
    }
  });
  it('progress and request observers cannot mutate session outcomes', async () => {
    const http = transport(async () => reply());
    const run = session(http, { onProgress: (value: { analysis: { text: string | null; usage: { costUsd: number | null } } }) => { value.analysis.text = 'mutated'; value.analysis.usage.costUsd = 999; throw new Error('observer'); }, onRequestStart: () => { throw new Error('observer'); } });
    const result = await run.analyzeImage('image-a', input, new AbortController().signal);
    expect(result).toMatchObject({ status: 'completed', text: ' 한글\nEnglish 😀 ', usage: { costUsd: .001 } });
    result.text = 'caller mutation';
    expect(await run.analyzeImage('image-b', input, new AbortController().signal)).toMatchObject({ text: ' 한글\nEnglish 😀 ', cacheOf: 'image-a' });
  });
  it('uses actual Node HTTP against an explicitly redirected local test transport only', async () => {
    const bodies: Buffer[] = []; let calls = 0;
    const server = createServer(async (request, response) => {
      const chunks: Buffer[] = []; for await (const part of request) chunks.push(part as Buffer);
      bodies.push(Buffer.concat(chunks)); calls++;
      response.writeHead(calls === 1 ? 429 : 200, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify(calls === 1 ? { error: 'mock retry' } : envelope()));
    });
    server.listen(0, '127.0.0.1'); await once(server, 'listening');
    const address = server.address(); if (!address || typeof address === 'string') throw new Error('Missing mock address');
    try {
      const run = session(transport(async (endpoint, init) => { expect(endpoint).toBe(OCR_ENDPOINT); return fetch(`http://127.0.0.1:${address.port}/chat/completions`, init); }));
      const result = await run.analyzeImage('image-a', input, new AbortController().signal);
      expect(result).toMatchObject({ status: 'completed', attemptCount: 2 }); expect(run.requestCount).toBe(2); expect(bodies[0]).toEqual(bodies[1]);
    } finally { server.closeAllConnections(); await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve())); }
  });
});

describe('core consumer callback contract', () => {
  it('emits only valid mergeable occurrence projections and keeps actual counts on synchronous transport throw', async () => {
    const image: OcrImageOccurrence = {
      imageId: 'image-a', url: 'https://example.test/', frameUrl: 'https://example.test/', framePath: [], location: '#image', snapshotId: 'snapshot-a', sourceKind: 'img', sourceIndex: 0,
      imageUrl: 'https://example.test/image.png', capturedAt: '2026-10-04T00:00:00Z', original: { assetId: 'original-a', path: 'images/original.png', sha256: input.sha256, mime: input.mime, byteLength: input.byteLength },
      input: { assetId: 'input-a', path: 'images/input.png', sha256: input.sha256, mime: input.mime, byteLength: input.byteLength, width: input.width, height: input.height, frameIndex: 0 },
      styles: [], concealment: [], status: 'captured', extractionStatus: null, text: null, confidence: null, model: OCR_MODEL, promptVersion: OCR_PROMPT_VERSION, cacheOf: null, attemptCount: 0,
      usage: { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null }, reasonCode: null,
    };
    const validate = () => validateOcrFile({ schemaVersion: 2, runId: 'test-run', enabled: true, model: OCR_MODEL, images: [image] });
    const observed: number[] = [], states: string[] = [];
    const http = vi.fn(() => { throw new Error('mock synchronous transport failure'); }) as typeof fetch;
    const run = session(http, { onProgress: ({ analysis }: { analysis: Partial<OcrImageOccurrence> }) => { Object.assign(image, analysis); validate(); states.push(image.status); }, onRequestStart: (count: number) => observed.push(count) });
    const result = await run.analyzeImage('image-a', input, new AbortController().signal);
    expect(result).toMatchObject({ status: 'error', reasonCode: 'OCR_HTTP_ERROR', attemptCount: 1 });
    expect(states).toEqual(['captured', 'running', 'error']); expect(observed).toEqual([1]); expect(run.requestCount).toBe(1); validate();
  });
  it('does not let an observer abort before transport create an invalid wire state', async () => {
    const controller = new AbortController(); const states: { status: string; reasonCode: unknown }[] = [];
    const run = session(transport(async () => reply()), { onProgress: ({ analysis }: { analysis: { status: string; reasonCode: unknown } }) => { states.push(analysis); if (analysis.status === 'captured') controller.abort(); } });
    expect(await run.analyzeImage('image-a', input, controller.signal)).toMatchObject({ status: 'not_started', reasonCode: 'USER_CANCELLED', attemptCount: 0 });
    expect(states.map(s => [s.status, s.reasonCode])).toEqual([['captured', null], ['not_started', 'USER_CANCELLED']]);
  });
});

it('does not reuse cache for another actual PNG hash', async () => {
  const http = transport(async () => reply()); const run = session(http);
  await run.analyzeImage('image-a', input, new AbortController().signal);
  const bytes = await readFile(new URL('../fixtures/ocr-assets/english.png', import.meta.url));
  const scratchPath = join(dir, 'other.png'); await writeFile(scratchPath, bytes);
  const other = { ...input, scratchPath, sha256: createHash('sha256').update(bytes).digest('hex'), byteLength: bytes.length, width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
  expect(await run.analyzeImage('image-b', other, new AbortController().signal)).toMatchObject({ cacheOf: null, attemptCount: 1, status: 'completed' });
  expect(http).toHaveBeenCalledTimes(2);
});
it('cancels a body in progress and accepts only known stop reason markers', async () => {
  for (const [reason, expected] of [[new Error('RESOURCE_LIMIT'), 'RESOURCE_LIMIT'], ['TIME_LIMIT', 'TIME_LIMIT'], ['provider-private-data', 'USER_CANCELLED']] as const) {
    const controller = new AbortController(); let aborted = false;
    const http = transport(async () => new Response(new ReadableStream({ pull() { if (!aborted) { aborted = true; controller.abort(reason); } } })));
    expect(await session(http).analyzeImage('image-a', input, controller.signal)).toMatchObject({ status: 'cancelled', attemptCount: 1, reasonCode: expected, text: null });
    expect(http).toHaveBeenCalledTimes(1);
  }
});
