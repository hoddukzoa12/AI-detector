import type { OcrExtraction, OcrUsage } from '../core/v2.js';
import { OCR_MODEL } from '../core/v2.js';
import { validateOcrExtraction } from '../core/validation-v2.js';
export interface OcrResponse { extraction: OcrExtraction; usage: OcrUsage }
export function emptyOcrUsage(): OcrUsage { return { promptTokens: null, completionTokens: null, totalTokens: null, costUsd: null }; }
function invalid(): never { throw new Error('Invalid OCR response'); }
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) invalid();
  return value as Record<string, unknown>;
}
/** Only the Chat Completions envelope and exact OCR extraction schema are accepted. */
export function validateOcrResponse(value: unknown): OcrResponse {
  const envelope = object(value);
  if (envelope.model !== OCR_MODEL || envelope.error != null || !Array.isArray(envelope.choices) || envelope.choices.length !== 1) invalid();
  const choice = object(envelope.choices[0]);
  if (choice.finish_reason !== 'stop' || (choice.native_finish_reason != null && !['stop', 'STOP'].includes(choice.native_finish_reason as string))) invalid();
  const message = object(choice.message);
  if (message.role !== 'assistant' || typeof message.content !== 'string' || message.refusal != null || message.tool_calls != null || message.function_call != null) invalid();
  let extraction: unknown;
  try { extraction = JSON.parse(message.content) as unknown; validateOcrExtraction(extraction); } catch { invalid(); }
  const usage = emptyOcrUsage();
  if (envelope.usage != null) {
    const supplied = object(envelope.usage);
    for (const [providerKey, localKey] of [['prompt_tokens', 'promptTokens'], ['completion_tokens', 'completionTokens'], ['total_tokens', 'totalTokens'], ['cost', 'costUsd']] as const) {
      const n = supplied[providerKey];
      if (n === undefined || n === null) continue;
      if (typeof n !== 'number' || !Number.isFinite(n) || n < 0 || (localKey !== 'costUsd' && !Number.isSafeInteger(n))) invalid();
      usage[localKey] = n;
    }
  }
  return { extraction: { status: extraction.status, text: extraction.text }, usage };
}
