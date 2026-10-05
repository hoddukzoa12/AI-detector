import { afterEach, expect, it } from 'vitest';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
const roots: string[] = [];
afterEach(async () => { await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true }))); });
it('requires consent and a key before allocating an execution and publishes fixed models and limits', async () => {
  const outputRoot = await mkdtemp(join(tmpdir(), 'v2-integration-')); roots.push(outputRoot);
  const app = new InspectorApplication({ outputRoot });
  expect(() => app.start({ entryUrl: 'https://example.test', ocrEnabled: false, externalAnalysisConsent: true })).toThrow('INVALID_CONFIG');
  expect(() => app.start({ entryUrl: 'https://example.test', aiEnabled: false } as never)).toThrow('INVALID_REQUEST');
  expect(app.activeRunId).toBeNull();
  expect(app.config).toEqual({ aiConfigured: false, aiRequired: true, model: 'cloudflare/clef', ocrModel: 'google/gemini-3.8-flash', outputRoot,
    limits: { maxOcrRequests: 100, maxClefRequests: 1000, maxImageBytes: 8388608, maxImagePixels: 16000000 } });
});
