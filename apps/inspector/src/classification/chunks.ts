import type { AiChunkReasonCode } from '../core/types.js';
import type { DetectionCandidateV2 } from '../core/v2.js';
import { countStateTokens, type CandidateState } from './tokenizer.js';
import { cancellationReason } from './abort.js';

export interface ChunkOptions {
  /** At most 1500, to stay below the service's approximately 2000-state-token truncation. */
  stateBudgetTokens?: number;
  /** Maximum HTTP-analyzed chunks; remaining raw text is retained as a resource-limited range. */
  maxChunks?: number;
  /** Must reconstruct normalized text from this exact raw slice (e.g. detection.normalizeText). */
  normalize?: (rawText: string) => string;
}
export interface PlannedChunk {
  chunkId: string; rawStart: number; rawEnd: number; state: CandidateState | null;
  stateTokens: number | null; reasonCode: AiChunkReasonCode | null;
}
export function positiveInteger(value: number, name: string, max: number): number {
  if (!Number.isSafeInteger(value) || value < 1 || value > max) throw new RangeError(`Invalid ${name}`);
  return value;
}
function boundary(text: string, offset: number): number {
  if (offset > 0 && offset < text.length && /[\uD800-\uDBFF]/.test(text[offset - 1]) && /[\uDC00-\uDFFF]/.test(text[offset])) return offset - 1;
  return offset;
}
/** UTF-16 half-open ranges cover all raw text; no candidate text or links are silently discarded. */
export function planCandidateChunks(candidate: DetectionCandidateV2, options: ChunkOptions = {}, deadline = Infinity, signal?: AbortSignal): PlannedChunk[] {
  const budget = positiveInteger(options.stateBudgetTokens ?? 1500, 'state token budget', 1500);
  const maxChunks = positiveInteger(options.maxChunks ?? 128, 'chunk limit', 1024);
  const { rawText, normalizedText } = candidate;
  const links = [...candidate.links]; const plan: PlannedChunk[] = [];
  const limited = (start: number, reasonCode: AiChunkReasonCode = 'RESOURCE_LIMIT') => {
    plan.push({ chunkId: `chunk-${plan.length}`, rawStart: start, rawEnd: rawText.length, state: null, stateTokens: null, reasonCode });
    return plan;
  };
  const stopReason = (): AiChunkReasonCode | null => signal?.aborted ? cancellationReason(signal) : Date.now() >= deadline ? 'TIME_LIMIT' : null;
  const early = stopReason(); if (early) return limited(0, early);
  // These are work bounds, never an estimate of tokens. Over-limit originals stay in the candidate.
  if (rawText.length > 1_000_000 || normalizedText.length > 1_000_000 || links.reduce((n, s) => n + s.length, 0) > 65_536 || links.length > 1024) return limited(0);
  if (countStateTokens({ rawText: '', normalizedText: '', links }) > budget) return limited(0);
  const stateFor = (start: number, end: number): CandidateState => {
    const raw = rawText.slice(start, end);
    return { rawText: raw, normalizedText: options.normalize ? options.normalize(raw) : rawText === normalizedText ? raw : normalizedText, links };
  };
  // Small entire candidates can use the supplied normalization without guessing an offset mapping.
  if (rawText.length <= 4096 && normalizedText.length <= 16384) {
    const state = stateFor(0, rawText.length);
    const stateTokens = state.normalizedText.length > 16384 ? Infinity : countStateTokens(state);
    if (stateTokens <= budget) return [{ chunkId: 'chunk-0', rawStart: 0, rawEnd: rawText.length, state, stateTokens, reasonCode: null }];
  }
  if (!options.normalize && rawText !== normalizedText) return limited(0);
  let start = 0;
  while (start < rawText.length) {
    const reason = stopReason(); if (reason) return limited(start, reason);
    if (plan.length >= maxChunks) return limited(start);
    let lo = start, hi = boundary(rawText, Math.min(rawText.length, start + 4096));
    let best: { end: number; state: CandidateState; tokens: number } | null = null;
    // Non-monotonic token counts need not yield a maximal chunk; every selected JSON is measured.
    while (lo < hi) {
      let end = boundary(rawText, Math.ceil((lo + hi) / 2));
      if (end <= lo) end = boundary(rawText, Math.min(rawText.length, lo + 2));
      if (end <= start || end > hi) break;
      const state = stateFor(start, end);
      const tokens = state.normalizedText.length > 16384 ? Infinity : countStateTokens(state);
      if (tokens <= budget) { best = { end, state, tokens }; lo = end; }
      else hi = boundary(rawText, end - 1);
    }
    if (!best) return limited(start);
    plan.push({ chunkId: `chunk-${plan.length}`, rawStart: start, rawEnd: best.end, state: best.state, stateTokens: best.tokens, reasonCode: null });
    start = best.end;
  }
  return plan;
}
