import { CLEF_MODEL, type AiAnalysis, type AiChunk, type ReviewReason } from './types.js';

export const DEFAULT_AI_THRESHOLD = .8;
function compare(a: AiChunk, b: AiChunk): number { return a.rawStart - b.rawStart || a.chunkId.localeCompare(b.chunkId); }
function uncertain(c: AiChunk, threshold: number): boolean {
  return c.status === 'completed' && (c.choice === 'uncertain' || c.choice === null ||
    (c.probabilities?.[c.choice] ?? 0) < threshold);
}
export function isPositiveAiChunk(c: AiChunk, threshold = DEFAULT_AI_THRESHOLD): boolean {
  return c.status === 'completed' && c.choice === 'illegal_ad' && (c.probabilities?.illegal_ad ?? 0) >= threshold;
}
/** Copies one real chunk; no probability average or candidate-wide confidence is invented. */
export function summarizeAiChunks(chunks: readonly AiChunk[]): AiChunk | null {
  const completed = chunks.filter(c => c.status === 'completed').sort(compare);
  const positive = completed.filter(c => isPositiveAiChunk(c)).sort((a, b) =>
    (b.probabilities?.illegal_ad ?? 0) - (a.probabilities?.illegal_ad ?? 0) || compare(a, b));
  return positive[0] ?? completed.find(c => uncertain(c, DEFAULT_AI_THRESHOLD)) ?? completed[0] ?? null;
}
export function createAiAnalysis(chunks: readonly AiChunk[]): AiAnalysis {
  const selected = summarizeAiChunks(chunks);
  return { model: CLEF_MODEL, summaryChunkId: selected?.chunkId ?? null, choice: selected?.choice ?? null,
    probabilities: selected?.probabilities ? { ...selected.probabilities } : null, confidence: selected?.confidence ?? null,
    chunks: structuredClone([...chunks]) };
}
export interface AiDecision { confirmed: boolean; review: boolean; excluded: boolean; reason: ReviewReason | null }
/** A positive chunk may confirm while failed/unfinished/uncertain coverage remains in review. */
export function classifyAiAnalysis(ai: AiAnalysis, threshold = DEFAULT_AI_THRESHOLD): AiDecision {
  if (!Number.isFinite(threshold) || threshold < 0 || threshold > 1) throw new RangeError('Threshold must be within [0,1]');
  const confirmed = ai.chunks.some(c => isPositiveAiChunk(c, threshold));
  const error = ai.chunks.some(c => c.status === 'error');
  const unfinished = !ai.chunks.length || ai.chunks.some(c => c.status !== 'completed' && c.status !== 'error');
  const unclear = ai.chunks.some(c => uncertain(c, threshold));
  const reason: ReviewReason | null = error ? 'AI_ERROR' : unfinished ? 'NOT_ANALYZED' : unclear ? 'UNCERTAIN' : null;
  const excluded = ai.chunks.length > 0 && ai.chunks.every(c => c.status === 'completed' &&
    (c.choice === 'non_ad' || c.choice === 'general_ad') && (c.probabilities?.[c.choice] ?? 0) >= threshold);
  return { confirmed, review: reason !== null, excluded, reason };
}
