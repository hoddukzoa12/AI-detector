import { describe, expect, it } from 'vitest';
import type { CollectedImageOccurrence, OcrImageOccurrence } from '../../src/core/index.js';
import { detectImageCandidates, normalizeText } from '../../src/detection/index.js';

function image(imageId: string, patch: Partial<OcrImageOccurrence> = {}): OcrImageOccurrence {
  return { imageId, url: 'https://public.test/page?q=1', frameUrl: 'https://frame.test/', framePath: ['iframe#one'],
    location: 'iframe#one >>> #owner', snapshotId: 'snapshot', sourceKind: 'img', sourceIndex: 0,
    imageUrl: 'https://asset.test/image.png', capturedAt: null, original: null, input: null, styles: [], concealment: [],
    status: 'completed', extractionStatus: 'readable', text: '원문😀', confidence: null, model: 'google/gemini-3.8-flash',
    promptVersion: 'test-v1', cacheOf: null, attemptCount: 1,
    usage: { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null }, reasonCode: null, ...patch };
}
function owner(i: OcrImageOccurrence): CollectedImageOccurrence {
  return { ...i, links: ['https://public.test/owned'], selectedUrl: i.imageUrl!, bounds: { x: 0, y: 0, width: 10, height: 10 }, documentBounds: { x: 0, y: 0, width: 10, height: 10 } };
}
describe('owner grouped readable OCR candidates', () => {
  it('orders all readable sources, joins exact originals and retains UTF16 ranges and all source relationships', () => {
    const images = [image('after', { sourceKind: 'css_after', text: '안내' }), image('bg1', { sourceKind: 'css_background', sourceIndex: 1, text: 'cаsinо' }),
      image('img'), image('before', { sourceKind: 'css_before', text: 'ㅋㅏㅈㅣㄴㅗ' }), image('bg0', { sourceKind: 'css_background', text: 'ordinary' }),
      image('partial', { sourceKind: 'css_background', sourceIndex: 2, extractionStatus: 'partial', text: 'DO_NOT_INCLUDE' }),
      image('no-text', { sourceKind: 'css_after', sourceIndex: 1, extractionStatus: 'no_text', text: '' }),
      image('failed', { sourceKind: 'css_after', sourceIndex: 2, status: 'error', extractionStatus: null, text: null, reasonCode: 'OCR_HTTP_ERROR' })];
    const owners = images.map(owner); const before = structuredClone({ images, owners });
    const [c] = detectImageCandidates(images, owners);
    expect(c.rawText).toBe('원문😀\nordinary\ncаsinо\nㅋㅏㅈㅣㄴㅗ\n안내');
    expect(c.normalizedText).toBe(normalizeText(c.rawText));
    expect(c.sourceTextRanges.map(r => [r.imageId, r.rawStart, r.rawEnd])).toEqual([
      ['img', 0, 4], ['bg0', 5, 13], ['bg1', 14, 20], ['before', 21, 27], ['after', 28, 30],
    ]);
    expect(new Set(c.sourceIds)).toEqual(new Set(images.map(i => i.imageId)));
    expect(c).toMatchObject({ sourceType: 'image_ocr', techniques: [], observationIds: [], links: ['https://public.test/owned'], location: images[0].location });
    expect(c).not.toHaveProperty('localDecision'); expect(c).not.toHaveProperty('ruleIds');
    expect({ images, owners }).toEqual(before);
    expect(detectImageCandidates([...images, images[0]], [...owners, owners[0]])).toEqual([c]);
  });
  it('keeps empty OCR review owners and distinct query/frame/location identities', () => {
    const images = [image('unreadable', { extractionStatus: 'unreadable', text: '' }), image('other-frame', { framePath: ['iframe#two'], location: 'iframe#two >>> #owner' }),
      image('other-location', { location: 'iframe#one >>> #second' }), image('other-query', { url: 'https://public.test/page?q=2' })];
    const cs = detectImageCandidates(images, images.map(owner));
    expect(cs).toHaveLength(4); expect(new Set(cs.map(c => c.candidateId)).size).toBe(4);
    expect(cs[0]).toMatchObject({ rawText: '', normalizedText: '', sourceIds: ['unreadable'], sourceTextRanges: [] });
    expect(detectImageCandidates(images, images.map(owner))).toEqual(cs);
  });
  it('rejects missing or mismatched collected owners rather than inventing links or evidence', () => {
    const i = image('one'); expect(() => detectImageCandidates([i], [])).toThrow(/owner/iu);
    expect(() => detectImageCandidates([i], [{ ...owner(i), location: '#unrelated' }])).toThrow(/owner/iu);
  });
});
