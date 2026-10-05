import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { chromium } from 'playwright';
import { crawl } from '../../src/crawler/index.js';
import { detectPage } from '../../src/detection/index.js';
import { startFixtureSite, type FixtureSite } from '../fixtures/site.js';

let site: FixtureSite;
beforeAll(async () => { site = await startFixtureSite(); });
afterAll(async () => { await site.stop(); });

describe('crawler to detector iframe locations', () => {
  it('preserves complete external, nested, relative, shared-source and srcdoc fixture paths', async () => {
    const result = await crawl(site.urls.frames, {
      executablePath: process.env.INSPECTOR_CHROMIUM_PATH ?? chromium.executablePath(), dynamicWaitMs: 100, resourceWaitMs: 150,
      scrollSteps: 1, scrollWaitMs: 10, navigationTimeoutMs: 1000,
    });
    expect(result.state).toBe('partial');
    expect(result.errors).toContainEqual(expect.objectContaining({ code: 'FRAME_UNAVAILABLE', url: site.urls.failure }));
    expect(result.pages).toHaveLength(1);
    const page = result.pages[0];
    const truths = site.expectedFindings.filter(truth => truth.url === site.urls.frames);
    expect(truths).toHaveLength(6);
    const captured = page.frames.flatMap(frame => frame.elements);
    for (const truth of truths) {
      expect(captured).toContainEqual(expect.objectContaining({ location: truth.location, rawText: truth.rawEvidence }));
    }

    const candidates = detectPage(page);
    const actual = candidates.flatMap(candidate => candidate.techniques.map(technique => ({
      url: candidate.url, location: candidate.location, rawEvidence: candidate.rawText, technique,
    }))).sort((left, right) => left.location.localeCompare(right.location));
    const expected = truths.map(truth => ({
      url: truth.url, location: truth.location, rawEvidence: truth.rawEvidence, technique: truth.technique,
    })).sort((left, right) => left.location.localeCompare(right.location));
    expect(actual).toEqual(expected);
    expect(candidates.every(candidate => candidate.sourceType === 'dom_text')).toBe(true);
    expect(new Set(candidates.map(candidate => candidate.candidateId)).size).toBe(6);
    expect(detectPage(page)).toEqual(candidates);
    // Repeated captures merge by owner identity while the two same-src iframe owners stay distinct.
    const repeated = structuredClone(page);
    for (const frame of repeated.frames) frame.elements.push(...structuredClone(frame.elements));
    expect(detectPage(repeated)).toEqual(candidates);
  });
});
