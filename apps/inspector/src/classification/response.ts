import { AI_CHOICES, CLEF_MODEL, type AiChoice, type AiProbabilities } from '../core/types.js';
export interface DecisionResponse {
  choice: AiChoice; probabilities: AiProbabilities; confidence: number;
  usage: { input_tokens: number; output_tokens: number; cost?: number };
}
function invalid(): never { throw new Error('Invalid CLEF response'); }
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) invalid();
  return value as Record<string, unknown>;
}
function unit(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 1) invalid();
  return value;
}
function tokenCount(value: unknown): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) invalid();
  return value;
}
/** Validates the Decisions schema; confidence and usage never substitute for class probabilities. */
export function validateDecisionResponse(value: unknown): DecisionResponse {
  const response = object(value); if (response.model !== CLEF_MODEL) invalid();
  const answers = object(response.answers); const answer = object(answers.ad_class);
  if (answer.type !== 'choice' || !AI_CHOICES.includes(answer.choice as AiChoice)) invalid();
  const supplied = object(answer.probabilities);
  if (Object.keys(supplied).length !== AI_CHOICES.length || AI_CHOICES.some(k => !Object.hasOwn(supplied, k))) invalid();
  const probabilities = Object.fromEntries(AI_CHOICES.map(k => [k, unit(supplied[k])])) as AiProbabilities;
  if (Math.abs(Object.values(probabilities).reduce((n, p) => n + p, 0) - 1) > .001 + Number.EPSILON) invalid();
  const choice = answer.choice as AiChoice;
  if (probabilities[choice] !== Math.max(...Object.values(probabilities))) invalid();
  const confidence = unit(answer.confidence); const suppliedUsage = object(response.usage);
  const usage: DecisionResponse['usage'] = { input_tokens: tokenCount(suppliedUsage.input_tokens), output_tokens: tokenCount(suppliedUsage.output_tokens) };
  if (Object.hasOwn(suppliedUsage, 'cost')) {
    if (typeof suppliedUsage.cost !== 'number' || !Number.isFinite(suppliedUsage.cost) || suppliedUsage.cost < 0) invalid();
    usage.cost = suppliedUsage.cost;
  }
  return { choice, probabilities, confidence, usage };
}
