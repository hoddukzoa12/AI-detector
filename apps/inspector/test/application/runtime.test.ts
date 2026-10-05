import { mockAnalysisOptions } from './mock-transport.js';
import { afterEach, describe, expect, it } from 'vitest';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InspectorApplication } from '../../src/application/index.js';
import { startFixtureSite, type FixtureSite } from '../fixtures/site.js';
const roots: string[] = []; let site: FixtureSite | undefined;
afterEach(async () => { await site?.stop(); site = undefined; await Promise.all(roots.splice(0).map(root => rm(root, { recursive: true, force: true }))); });
async function root() { const path = await mkdtemp(join(tmpdir(), 'runtime-')); roots.push(path); return path; }
describe('application runtime', () => {
  it('collects independent four-type fixture and saves shared findings with exact metadata', async () => {
    site = await startFixtureSite(); const fixture = site;
    const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), crawlOptions: { dynamicWaitMs: 0, resourceWaitMs: 0, scrollSteps: 0 } });
    const run = app.start({ entryUrl: fixture.urls.types, ocrEnabled: false, externalAnalysisConsent: true });
    expect(() => app.start({ entryUrl: fixture.urls.types, ocrEnabled: false, externalAnalysisConsent: true })).toThrow('ACTIVE_RUN');
    const finished = await app.wait(run.runId);
    expect(finished.state).toBe('completed');
    const findings = app.findings(run.runId).findings;
    for (const truth of site.expectedFindings.filter(t => t.url === site!.urls.types)) expect(findings).toContainEqual(expect.objectContaining({ url: truth.url, location: truth.location, technique: truth.technique, evidence_text: truth.rawEvidence }));
    expect(finished.counts.confirmedFindings).toBe(findings.length);
    const status = JSON.parse((await app.readFile(run.runId, 'scan-status.json')).toString());
    expect(status.run).toEqual(finished);
    expect(app.details(run.runId).details).toHaveLength(findings.length);
    const result = JSON.parse((await app.readFile(run.runId, 'result.json')).toString());
    expect(result.findings).toEqual(findings); expect(result.meta.finished_at).toBe(finished.finishedAt);
  }, 30000);
  it('rejects URL/key before creating', async () => {
    const app = new InspectorApplication({ outputRoot: await root() });
    expect(() => app.start({ entryUrl: 'javascript:1', ocrEnabled: false, externalAnalysisConsent: true })).toThrow('INVALID_URL');
    expect(() => app.start({ entryUrl: 'https://example.invalid', ocrEnabled: false, externalAnalysisConsent: true })).toThrow('INVALID_CONFIG');
    expect(app.activeRunId).toBe(null);
  });
});
it('real crawl and CLEF adapter with injected transport share four-type saved evidence', async () => {
  site = await startFixtureSite(); const fixture = site; let calls = 0;
  const app = new InspectorApplication({ ...mockAnalysisOptions, outputRoot: await root(), apiKey: 'integration-placeholder', crawlOptions: { dynamicWaitMs: 0, resourceWaitMs: 0, scrollSteps: 0 },
    aiOptions: { fetch: async (endpoint, init) => {
      calls++; expect(endpoint).toBe('https://openrouter.ai/api/alpha/decisions');
      const body = JSON.parse(init!.body as string); expect(Object.keys(body.state).sort()).toEqual(['links', 'normalizedText', 'rawText']);
      expect(JSON.stringify(body)).not.toContain('integration-placeholder');
      return new Response(JSON.stringify({ model: 'cloudflare/clef', usage: { input_tokens: 10, output_tokens: 1 }, answers: { ad_class: { type: 'choice', choice: 'illegal_ad', confidence: .9,
        probabilities: { illegal_ad: .9, general_ad: 1/30, non_ad: 1/30, uncertain: 1/30 } } } }));
    } } });
  const run = app.start({ entryUrl: fixture.urls.types, ocrEnabled: false, externalAnalysisConsent: true }); const terminal = await app.wait(run.runId);
  expect(terminal.state).toBe('completed'); expect(calls).toBeGreaterThan(0);
  for(const truth of fixture.expectedFindings.filter(t=>t.url===fixture.urls.types)) expect(app.findings(run.runId).findings).toContainEqual(expect.objectContaining({ url: truth.url, location: truth.location, technique: truth.technique, evidence_text: truth.rawEvidence }));
  expect(app.details(run.runId).details.every(detail => detail.decisionSource === 'clef' && detail.ruleIds.length === 0 && detail.evidence.sha256)).toBe(true);
  expect(JSON.parse((await app.readFile(run.runId,'scan-status.json')).toString()).run).toEqual(terminal);
}, 30000);
