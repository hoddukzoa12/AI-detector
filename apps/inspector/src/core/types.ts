/** Shared wire contracts. Raw strings always retain the captured, unnormalized text. */
export const TECHNIQUES = ['HOMOGLYPH', 'JAMO', 'TRANSPARENT', 'OFFSCREEN'] as const;
export type Technique = typeof TECHNIQUES[number];
export const RUN_STATES = ['running', 'stopping', 'completed', 'partial', 'cancelled', 'failed'] as const;
export type RunState = typeof RUN_STATES[number];
export type TerminalRunState = Exclude<RunState, 'running' | 'stopping'>;
export const CLEF_MODEL = 'cloudflare/clef' as const;
export const ERROR_CODES = ['OUT_OF_SCOPE', 'LOGIN_REQUIRED', 'NAVIGATION_ERROR', 'FRAME_UNAVAILABLE',
  'RESOURCE_LIMIT', 'TIME_LIMIT', 'AI_HTTP_ERROR', 'AI_RESPONSE_INVALID', 'AI_TIMEOUT',
  'STORAGE_ERROR', 'RUNTIME_ERROR'] as const;
export type RunErrorCode = typeof ERROR_CODES[number];
export type ErrorScope = 'page' | 'frame' | 'ai' | 'storage' | 'runtime' | 'limit';
export interface RunError { scope: ErrorScope; code: RunErrorCode; url: string | null; candidateId: string | null; message: string }
export interface RunCounts {
  discoveredPages: number; scannedPages: number; failedPages: number; skippedPages: number;
  pendingPages: number; confirmedFindings: number; reviewCandidates: number;
}
export interface RunSnapshot {
  runId: string; entryUrl: string; startedAt: string; state: RunState; finishedAt: string | null;
  elapsedSec: number; aiEnabled: boolean; model: typeof CLEF_MODEL | null; counts: RunCounts;
  activeUrls: string[]; errors: RunError[];
}
export interface OfficialFinding {
  id: string; url: string; is_violation: true; location: string; evidence_text: string; technique: Technique;
}
export interface OfficialResult {
  meta: { topic: 'TOPIC'; entry_url: string; started_at: string; finished_at: string;
    elapsed_sec: number; tool_version?: string };
  findings: OfficialFinding[];
}
export interface EvidenceReference { snapshotId: string; path: string | null; sha256: string | null }
export interface Bounds { x: number; y: number; width: number; height: number }
/** Element first, followed by ancestors; coordinates are relative to the frame viewport. */
export interface ElementStyle { elementLocation: string; css: Record<string, string>; bounds: Bounds }
export interface EvidenceSnapshot {
  snapshotId: string; topPageUrl: string; frameUrl: string; framePath: string[]; capturedAt: string;
  html: string; elements: { location: string; rawText: string; styles: ElementStyle[] }[];
}
export const AI_CHOICES = ['illegal_ad', 'general_ad', 'non_ad', 'uncertain'] as const;
export type AiChoice = typeof AI_CHOICES[number];
export type AiProbabilities = Record<AiChoice, number>;
export type AiChunkStatus = 'pending' | 'running' | 'completed' | 'error' | 'not_started' | 'cancelled';
export type AiChunkReasonCode = 'AI_HTTP_ERROR' | 'AI_RESPONSE_INVALID' | 'AI_TIMEOUT' |
  'USER_CANCELLED' | 'TIME_LIMIT' | 'RESOURCE_LIMIT';
export interface AiChunk {
  chunkId: string; rawStart: number; rawEnd: number; status: AiChunkStatus;
  choice: AiChoice | null; probabilities: AiProbabilities | null; confidence: number | null;
  reasonCode: AiChunkReasonCode | null;
}
export interface AiAnalysis {
  model: typeof CLEF_MODEL; summaryChunkId: string | null; choice: AiChoice | null;
  probabilities: AiProbabilities | null; confidence: number | null; chunks: AiChunk[];
}
export type ReviewReason = 'UNCERTAIN' | 'AI_ERROR' | 'LOCAL_UNCERTAIN' | 'NOT_ANALYZED';
export interface ReviewCandidate {
  candidateId: string; url: string; location: string; evidenceText: string; techniques: Technique[];
  reason: ReviewReason; ai: AiAnalysis | null; evidence: EvidenceReference;
}
export interface ReviewFile { schemaVersion: 1; runId: string; candidates: ReviewCandidate[] }
export interface FindingDetail {
  findingId: string; candidateId: string; decisionSource: 'local' | 'clef'; ruleIds: string[];
  ai: AiAnalysis | null; evidence: EvidenceReference;
}
export interface FindingDetailsFile { schemaVersion: 1; runId: string; details: FindingDetail[] }
export interface ScanScope {
  hostname: string; framePolicy: 'embedded'; skipped: { url: string; reasonCode: RunErrorCode }[];
  unvisitedUrls: string[];
}
export interface ScanStatusFile {
  schemaVersion: 1; run: RunSnapshot; scope: ScanScope;
  files: { resultPath: string | null; reviewPath: string | null; findingDetailsPath: string | null;
    evidenceDir: string | null; resultSha256: string | null };
  resultSaved: boolean;
}
/** Captured owner text and its context, including hidden text. No visibility filter or text truncation.
 * `rawText` contains only the owner's direct TEXT_NODE values, concatenated in DOM order;
 * descendant text belongs to separate owners, even when their wording is identical.
 */
export interface CollectedElement {
  /** Full top-page location: complete iframe chain followed by the unique owner selector. */
  location: string; rawText: string; links: string[]; styles: ElementStyle[];
  tagName: string; attributes: Record<string, string>; contextText: string;
  accessibility: { role: string | null; ariaHidden: string | null; ariaLabel: string | null };
  bounds: Bounds; documentBounds: Bounds;
}
export interface CollectedFrame {
  frameUrl: string; framePath: string[]; html: string; elements: CollectedElement[];
  viewport: { width: number; height: number; scrollX: number; scrollY: number };
  documentSize: { width: number; height: number }; snapshotId: string; capturedAt: string;
}
export interface CollectedPage { url: string; frames: CollectedFrame[]; discoveredUrls: string[]; capturedAt: string }
/** A DOM-confirmed concealment candidate. `url` is the top-level visited page URL. */
export interface DetectionCandidate {
  candidateId: string; url: string; frameUrl: string; framePath: string[]; location: string;
  rawText: string; normalizedText: string; links: string[]; techniques: Technique[];
  evidence: EvidenceReference; localDecision: 'confirmed' | 'review' | 'excluded'; ruleIds: string[];
}
export const API_ERROR_CODES = ['INVALID_URL', 'INVALID_CONFIG', 'INVALID_REQUEST',
  'UNAUTHORIZED', 'FORBIDDEN', 'NOT_FOUND', 'ACTIVE_RUN'] as const;
export type ApiErrorCode = typeof API_ERROR_CODES[number];
export interface ApiErrorResponse { error: { code: ApiErrorCode; message: string } }
export interface PublicConfig { aiConfigured: boolean; model: typeof CLEF_MODEL; outputRoot: string }
export interface StartRunRequest { entryUrl: string; aiEnabled: boolean }
export interface FindingsResponse { runId: string; findings: OfficialFinding[] }
