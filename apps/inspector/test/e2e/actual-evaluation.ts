/** Deliberate standalone paid evaluation only. Never imported by an automatic suite or product entry. */
import { createHash } from 'node:crypto';
import { mkdir, readFile, realpath, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadRuntimeConfig } from '../../src/application/config.js';
import { OcrRunSession, OCR_ENDPOINT } from '../../src/ocr/index.js';
import { analyzeCandidate, CLEF_ENDPOINT } from '../../src/classification/index.js';
import type { DetectionCandidateV2, ImageScratchInput } from '../../src/core/index.js';
import { assetTruth } from '../fixtures/ocr-truth.js';
export const ACTUAL_LIMITS = { ocr: 8, clef: 16 } as const;
type Kind = keyof typeof ACTUAL_LIMITS;
export interface BudgetState { ocr: number; clef: number }
/** Reservation and persistence occur synchronously before invoking transport. Failed attempts consume budget. */
export function guardedTransport(delegate: typeof fetch, state: BudgetState, persist: (state: BudgetState) => void): typeof fetch {
  return (input, init) => {
    const endpoint = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    const kind: Kind = endpoint === OCR_ENDPOINT ? 'ocr' : endpoint === CLEF_ENDPOINT ? 'clef' : (() => { throw new Error('EVALUATION_ENDPOINT_REJECTED'); })();
    if (init?.method !== 'POST' || init.redirect !== 'error') throw new Error('EVALUATION_REQUEST_REJECTED');
    if (state[kind] >= ACTUAL_LIMITS[kind]) throw new Error('EVALUATION_BUDGET_EXHAUSTED');
    state[kind]++; persist({ ...state });
    return delegate(input, init);
  };
}
function hash(bytes: Uint8Array): string { return createHash('sha256').update(bytes).digest('hex'); }
/** Levenshtein distance over Unicode code points, with exact authored whitespace preserved. */
export function characterDifference(expected: string, actual: string): number {
  const left = [...expected], right = [...actual]; let row = right.map((_, i) => i + 1); row.unshift(0);
  for (let i = 0; i < left.length; i++) { const next = [i + 1]; for (let j = 0; j < right.length; j++) next.push(Math.min(next[j] + 1, row[j + 1] + 1, row[j] + (left[i] === right[j] ? 0 : 1))); row = next; }
  return row[right.length];
}
const samples = ['korean', 'english', 'logo', 'general', 'article', 'notice', 'no-text', 'unreadable'] as const;
export async function runActualEvaluation(configDirectory: string, reportDirectory: string): Promise<void> {
  // The standard Node loader reads .env privately. Neither the loaded config nor any caught error is serialized.
  const config = await loadRuntimeConfig({ mode: 'npm', cwd: configDirectory });
  await mkdir(reportDirectory, { recursive: true, mode: 0o700 });
  const reportPath = resolve(reportDirectory, 'actual-evaluation.json');
  const ledgerPath = resolve(reportDirectory, 'actual-budget.json');
  // One global stage, one invocation: wx rejects a reset/replay across process/application runs.
  const { writeFileSync } = await import('node:fs');
  const counts: BudgetState = { ocr: 0, clef: 0 };
  writeFileSync(ledgerPath, JSON.stringify({ limits: ACTUAL_LIMITS, started: counts }) + '\n', { flag: 'wx', mode: 0o600 });
  const requests: { kind: Kind; httpStatus: number | null; latencyMs: number; usage: Record<string, number | null> | null }[] = [];
  const transport = guardedTransport(async (input, init) => {
    const kind: Kind = input === OCR_ENDPOINT ? 'ocr' : 'clef'; const started = performance.now();
    const record: typeof requests[number] = { kind, httpStatus: null, latencyMs: 0, usage: null }; requests.push(record);
    try {
      const response = await fetch(input, init); record.httpStatus = response.status;
      // Inspect usage privately and retain only fixed numeric fields. Never store envelopes or error bodies.
      if (response.ok) {
        const data = await response.clone().json().catch(() => null) as { usage?: Record<string, unknown> } | null;
        const usage = data?.usage;
        if (usage) record.usage = Object.fromEntries(['prompt_tokens','completion_tokens','total_tokens','input_tokens','output_tokens','cost'].map(key => [key, typeof usage[key] === 'number' && Number.isFinite(usage[key]) && usage[key] >= 0 ? usage[key] : null]));
      }
      return response;
    } finally { record.latencyMs = Math.round(performance.now() - started); }
  }, counts, state => writeFileSync(ledgerPath, JSON.stringify({ limits: ACTUAL_LIMITS, started: state }) + '\n', { mode: 0o600 }));
  const observations: unknown[] = [];
  if (config.apiKey.trim()) {
    for (const id of samples) {
      if (counts.ocr >= ACTUAL_LIMITS.ocr) { observations.push({ id, status: 'NOT_RUN', reason: 'OCR_BUDGET_EXHAUSTED' }); continue; }
      const truth = assetTruth.find(item => item.id === id)!;
      const scratchPath = fileURLToPath(new URL('../fixtures/ocr-assets/' + truth.file, import.meta.url));
      const bytes = await readFile(scratchPath);
      const input: ImageScratchInput = { scratchPath, sha256: hash(bytes), mime: 'image/png', byteLength: bytes.length, width: truth.width, height: truth.height, frameIndex: 0 };
      const session = new OcrRunSession({ runId: 'actual-' + id, enabled: true, apiKey: config.apiKey, fetch: transport, maxRequests: ACTUAL_LIMITS.ocr - counts.ocr });
      const ocr = await session.analyzeImage(id, input, new AbortController().signal);
      let classification = null;
      if (ocr.extractionStatus === 'readable' && counts.clef < ACTUAL_LIMITS.clef) {
        const candidate: DetectionCandidateV2 = { candidateId: id, url: 'https://synthetic.example/' + id, frameUrl: 'https://synthetic.example/' + id, framePath: [], location: '#' + id, rawText: ocr.text!, normalizedText: ocr.text!, links: [], techniques: [], evidence: { snapshotId: 'synthetic', path: null, sha256: null }, sourceType: 'image_ocr', sourceIds: [id], sourceTextRanges: [{imageId:id,rawStart:0,rawEnd:ocr.text!.length}], observationIds: [] };
        const ai = await analyzeCandidate(candidate, config.apiKey, new AbortController().signal, { fetch: transport, maxRequests: ACTUAL_LIMITS.clef - counts.clef });
        classification = { status: ai.chunks.every(chunk => chunk.status === 'completed') ? 'PASS' : 'FAILED', expectedLabel: truth.label, choice: ai.choice, probabilities: ai.probabilities, confidence: ai.confidence, chunks: ai.chunks };
      }
      observations.push({ id, inputSha256: input.sha256, inputByteLength: bytes.length, expectedText: truth.text, expectedReading: truth.extractionStatus, status: ocr.status === 'completed' ? 'PASS' : 'FAILED', reading: ocr.extractionStatus, text: ocr.text, characterDifference: ocr.text === null ? null : characterDifference(truth.text, ocr.text), attemptCount: ocr.attemptCount, reasonCode: ocr.reasonCode, usage: ocr.usage, classification });
    }
    // Independent authored public text samples. They do not depend on OCR success.
    for (const sample of [{ id: 'text-promotion', text: '불법 온라인 카지노 가입 배팅 보너스', label: 'illegal_ad' }, { id: 'text-news', text: '뉴스: 불법 카지노 광고 단속, 경찰 수사 결과 보도', label: 'non_ad' }, { id: 'text-general', text: '동네 빵집 오늘의 식빵 20% 할인', label: 'general_ad' }, { id: 'text-menu', text: 'MEMBER', label: 'non_ad' }]) {
      if (counts.clef >= ACTUAL_LIMITS.clef) { observations.push({ id: sample.id, status: 'NOT_RUN', reason: 'CLEF_BUDGET_EXHAUSTED' }); continue; }
      const candidate: DetectionCandidateV2 = { candidateId: sample.id, url:'https://synthetic.example/',frameUrl:'https://synthetic.example/',framePath:[],location:'#'+sample.id,rawText:sample.text,normalizedText:sample.text,links:[],techniques:[],evidence:{snapshotId:'synthetic',path:null,sha256:null},sourceType:'dom_text',sourceIds:[],sourceTextRanges:[],observationIds:[] };
      const ai = await analyzeCandidate(candidate, config.apiKey, new AbortController().signal, { fetch: transport, maxRequests: ACTUAL_LIMITS.clef - counts.clef });
      observations.push({ id:sample.id,inputSha256:hash(Buffer.from(sample.text)),inputByteLength:Buffer.byteLength(sample.text),expectedLabel:sample.label,status:ai.chunks.every(chunk=>chunk.status==='completed')?'PASS':'FAILED',choice:ai.choice,probabilities:ai.probabilities,confidence:ai.confidence,chunks:ai.chunks });
    }
  }
  const report = { schemaVersion: 1, stage: 'SMALL_SYNTHETIC_ACTUAL_CONNECTION', status: config.apiKey.trim() ? observations.some(item => (item as {status:string}).status === 'FAILED') ? 'FAILED' : 'MEASURED' : 'NOT_RUN', reason: config.apiKey.trim() ? null : 'KEY_NOT_CONFIGURED', limits: ACTUAL_LIMITS, actualNetworkStarts: counts, requests, observations, actualSiteAccuracy: 'NOT_MEASURED', actualWindowsGuiExecution: 'NOT_RUN', repositoryLicense: 'UNRESOLVED' };
  await writeFile(reportPath, JSON.stringify(report,null,2)+'\n',{flag:'wx',mode:0o600});
}
// Exact source CLI guard: importing this utility cannot trigger configuration loading or transport.
if (process.argv[1] && await realpath(resolve(process.argv[1])).catch(() => '') === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 6 || process.argv[2] !== '--execute-authorized-once' || process.argv[3] !== '--config-directory') throw new Error('EXPLICIT_EVALUATION_INVOCATION_REQUIRED');
  try { await runActualEvaluation(resolve(process.argv[4]),resolve(process.argv[5])); console.log('Actual evaluation safe report written'); }
  catch { console.error('Actual evaluation FAILED; no provider details logged'); process.exitCode = 1; }
}
