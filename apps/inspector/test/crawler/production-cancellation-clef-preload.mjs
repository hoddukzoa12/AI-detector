/** Test-only fixed OpenRouter transport. Production core, collector and storage stay real. */
import { appendFileSync, readFileSync } from 'node:fs';

const oracle = JSON.parse(readFileSync(process.env.INSPECTOR_TEST_CLEF_ORACLE, 'utf8'));
if (!Array.isArray(oracle.positiveTexts) || !Array.isArray(oracle.immediateTexts) || typeof oracle.auditPath !== 'string') throw new Error('Invalid cancellation fixture oracle');
const actualFetch = globalThis.fetch;
const endpoint = 'https://openrouter.ai/api/alpha/decisions';
const audit = record => appendFileSync(oracle.auditPath, JSON.stringify(record) + '\n', { mode: 0o600 });
globalThis.fetch = async function productionCancellationClefMock(input, init) {
  const url = input instanceof globalThis.Request ? input.url : String(input);
  const parsed = new URL(url);
  if (parsed.hostname !== 'openrouter.ai') {
    if (!['GET', 'HEAD'].includes(init?.method ?? (input instanceof globalThis.Request ? input.method : 'GET'))) throw new Error('Cancellation fixture only delegates reading requests');
    return actualFetch(input, init);
  }
  // Fail closed for OCR or any unexpected provider URL; no paid request can escape this preload.
  if (url !== endpoint || init?.method !== 'POST' || typeof init.body !== 'string') throw new Error('Unexpected provider request in cancellation fixture');
  const request = JSON.parse(init.body);
  if (request.model !== 'cloudflare/clef' || request.questions?.ad_class?.type !== 'choice' || typeof request.state?.rawText !== 'string') throw new Error('Invalid CLEF fixture request');
  const raw = request.state.rawText;
  // Labels come from authored fixture text, including slices of its long positive candidate.
  // This mock is not a product classifier and makes no claim about real CLEF accuracy.
  const positive = raw.length > 0 && oracle.positiveTexts.some(text => text.includes(raw));
  const delayed = positive && !oracle.immediateTexts.some(text => text.includes(raw));
  const choice = positive ? 'illegal_ad' : 'non_ad';
  audit({ event: 'started', delayed, choice });
  // Deliberately ignore AbortSignal here so the real adapter must discard a late positive.
  if (delayed) await new Promise(resolve => setTimeout(resolve, 2000));
  audit({ event: 'settled', delayed, choice, settledAt: Date.now() });
  return globalThis.Response.json({ model: 'cloudflare/clef', answers: { ad_class: { type: 'choice', choice,
    probabilities: positive ? { illegal_ad: .97, general_ad: .01, non_ad: .01, uncertain: .01 } : { illegal_ad: .01, general_ad: .01, non_ad: .97, uncertain: .01 }, confidence: .99 } },
    usage: { input_tokens: 1, output_tokens: 1, cost: 0 } });
};
