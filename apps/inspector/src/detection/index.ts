import { createHash } from 'node:crypto';
import type { CollectedPage, Technique } from '../core/types.js';
import type { CollectedImageOccurrence, DetectionCandidateV2, OcrImageOccurrence } from '../core/v2.js';
import { candidateIdentityKey, combineReadableImageText, imageOccurrenceKey, imageOwnerKey } from '../core/validation-v2.js';
import { IMAGE_SOURCE_KINDS } from '../core/v2.js';
import { analyzeStyles } from './styles.js';
import { analyzeText } from './text.js';

export { analyzeText, normalizeText } from './text.js';
export type { TextAnalysis, TextChange } from './text.js';

/** Pure analysis of captured data: no browser access, truncation, mutations or decision filtering. */
export function detectPage(page: CollectedPage): DetectionCandidateV2[] {
  const byIdentity = new Map<string, DetectionCandidateV2>();
  for (const frame of page.frames) {
    for (const element of frame.elements) {
      if (!element.rawText.trim()) continue;
      const text = analyzeText(element.rawText);
      const styles = analyzeStyles(element, frame);
      const techniques: Technique[] = [];
      if (text.changes.some(change => change.kind.startsWith('HOMOGLYPH'))) techniques.push('HOMOGLYPH');
      if (text.changes.some(change => change.kind.startsWith('JAMO'))) techniques.push('JAMO');
      techniques.push(...styles.techniques);
      if (!techniques.length) continue;
      const location = element.location;
      const identity = candidateIdentityKey({ url: page.url, framePath: frame.framePath, location, sourceType: 'dom_text' });
      const observationIds = [...new Set([...text.changes.map(change => `${change.kind}_CHANGED`), ...styles.observationIds, ...(styles.ambiguous ? ['STYLE_AMBIGUOUS_CONCEALMENT'] : [])])];
      const previous = byIdentity.get(identity);
      if (previous) {
        previous.techniques = [...new Set([...previous.techniques, ...techniques])];
        previous.observationIds = [...new Set([...previous.observationIds, ...observationIds])];
        continue;
      }
      byIdentity.set(identity, {
        candidateId: `candidate_${createHash('sha256').update(identity).digest('hex')}`,
        url: page.url, frameUrl: frame.frameUrl, framePath: [...frame.framePath], location,
        rawText: element.rawText, normalizedText: text.normalizedText, links: [...element.links], techniques,
        evidence: { snapshotId: frame.snapshotId, path: null, sha256: null },
        sourceType: 'dom_text', sourceIds: [], sourceTextRanges: [], observationIds,
      });
    }
  }
  return [...byIdentity.values()];
}

/** All source relationships stay local; only completed readable originals enter CLEF state.
 * Empty groups are retained for OCR review and must not be scheduled for CLEF by the caller.
 * owners supplies the T2 nearest-anchor links omitted deliberately from persisted OCR records.
 */
export function detectImageCandidates(images: readonly OcrImageOccurrence[], owners: readonly CollectedImageOccurrence[]): DetectionCandidateV2[] {
  const metadata = new Map(owners.map(owner => [owner.imageId, owner]));
  const groups = new Map<string, OcrImageOccurrence[]>();
  const seen = new Set<string>();
  for (const image of images) {
    const owner = metadata.get(image.imageId);
    if (!owner || imageOccurrenceKey(owner) !== imageOccurrenceKey(image) || owner.snapshotId !== image.snapshotId || owner.frameUrl !== image.frameUrl) {
      throw new Error('Missing or mismatched collected image owner');
    }
    const occurrence = imageOccurrenceKey(image);
    if (seen.has(occurrence)) continue;
    seen.add(occurrence);
    const key = imageOwnerKey(image);
    const group = groups.get(key) ?? [];
    group.push(image); groups.set(key, group);
  }
  return [...groups.values()].map(group => {
    const ordered = [...group].sort((a, b) => IMAGE_SOURCE_KINDS.indexOf(a.sourceKind) - IMAGE_SOURCE_KINDS.indexOf(b.sourceKind) || a.sourceIndex - b.sourceIndex);
    const image = ordered[0]; const owner = metadata.get(image.imageId)!;
    if (ordered.some(i => i.snapshotId !== image.snapshotId || i.frameUrl !== image.frameUrl || JSON.stringify(metadata.get(i.imageId)!.links) !== JSON.stringify(owner.links))) {
      throw new Error('Inconsistent collected image owner evidence');
    }
    const { rawText, sourceTextRanges } = combineReadableImageText(ordered);
    const identity = candidateIdentityKey({ ...image, sourceType: 'image_ocr' });
    return {
      candidateId: `candidate_${createHash('sha256').update(identity).digest('hex')}`,
      url: image.url, frameUrl: image.frameUrl, framePath: [...image.framePath], location: image.location,
      rawText, normalizedText: analyzeText(rawText).normalizedText, links: [...owner.links], techniques: [],
      evidence: { snapshotId: image.snapshotId, path: null, sha256: null },
      sourceType: 'image_ocr', sourceIds: ordered.map(i => i.imageId), sourceTextRanges, observationIds: [],
    };
  });
}
