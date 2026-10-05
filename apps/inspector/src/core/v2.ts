/** New execution contracts. V1 types/serializers remain solely for archive reads and migration compatibility. */
import type { AiAnalysis, Bounds, CollectedElement, ElementStyle, EvidenceReference, OfficialResult, RunCounts, RunError, RunSnapshot, ScanScope, Technique } from './types.js';
import { CLEF_MODEL, ERROR_CODES } from './types.js';
export const OCR_MODEL = 'google/gemini-3.8-flash' as const;
export const V2_ERROR_CODES = [...ERROR_CODES, 'IMAGE_FETCH_ERROR', 'IMAGE_DECODE_ERROR', 'IMAGE_UNSUPPORTED', 'OCR_HTTP_ERROR', 'OCR_RESPONSE_INVALID', 'OCR_TIMEOUT', 'OCR_UNREADABLE'] as const;
export type RunErrorV2 = Omit<RunError, 'scope' | 'code'> & { scope: RunError['scope'] | 'image' | 'ocr'; code: typeof V2_ERROR_CODES[number] };
export interface RunCountsV2 extends RunCounts { extraConfirmedFindings: number }
export interface ImageCounts { discovered: number; captured: number; ocrCompleted: number; failed: number; pending: number; skipped: number }
export interface RequestCounts { ocr: number; clef: number }
export interface RunSnapshotV2 extends Omit<RunSnapshot, 'aiEnabled' | 'model' | 'counts' | 'errors'> {
  aiEnabled: true; model: typeof CLEF_MODEL; externalAnalysisConsent: true; ocrEnabled: boolean;
  ocrModel: typeof OCR_MODEL | null; counts: RunCountsV2; imageCounts: ImageCounts; requestCounts: RequestCounts; errors: RunErrorV2[];
}
export interface StartRunRequestV2 { entryUrl: string; ocrEnabled: boolean; externalAnalysisConsent: true }
export const DEFAULT_ANALYSIS_LIMITS = { maxOcrRequests: 100, maxClefRequests: 1000, maxImageBytes: 8 * 1024 * 1024, maxImagePixels: 16_000_000 } as const;
export interface AnalysisLimits { maxOcrRequests: number; maxClefRequests: number; maxImageBytes: number; maxImagePixels: number }
export interface PublicConfigV2 { aiConfigured: boolean; aiRequired: true; model: typeof CLEF_MODEL; ocrModel: typeof OCR_MODEL; outputRoot: string; limits: AnalysisLimits }
export interface ExtraFinding { id: string; url: string; is_violation: true; location: string; evidence_text: string; technique: 'ETC'; extra_finding: 'IMAGE_AD_OCR' }
export interface ExtraResult { meta: OfficialResult['meta']; findings: ExtraFinding[] }
export interface ExtraFindingsResponse { runId: string; findings: ExtraFinding[] }
export const IMAGE_SOURCE_KINDS = ['img', 'css_background', 'css_before', 'css_after'] as const;
export type ImageSourceKind = typeof IMAGE_SOURCE_KINDS[number];
export const OCR_IMAGE_STATUSES = ['discovered', 'captured', 'running', 'completed', 'error', 'not_started', 'cancelled', 'not_selected', 'unsupported'] as const;
export type OcrImageStatus = typeof OCR_IMAGE_STATUSES[number];
export type OcrExtractionStatus = 'readable' | 'partial' | 'no_text' | 'unreadable';
export interface OcrExtraction { status: OcrExtractionStatus; text: string }
export type ImageReasonCode = Extract<RunErrorV2['code'], 'IMAGE_FETCH_ERROR' | 'IMAGE_DECODE_ERROR' | 'IMAGE_UNSUPPORTED' | 'OCR_HTTP_ERROR' | 'OCR_RESPONSE_INVALID' | 'OCR_TIMEOUT' | 'OCR_UNREADABLE' | 'TIME_LIMIT' | 'RESOURCE_LIMIT'> | 'USER_CANCELLED' | 'OCR_NOT_SELECTED';
export interface ImageAssetReference { assetId: string; path: string | null; sha256: string | null; mime: string; byteLength: number }
export interface ImageInputReference extends ImageAssetReference { width: number; height: number; frameIndex: 0 }
export interface OcrUsage { promptTokens: number | null; completionTokens: number | null; totalTokens: number | null; costUsd: number | null }
export interface ImageOccurrenceIdentity { url: string; framePath: string[]; location: string; sourceKind: ImageSourceKind; sourceIndex: number }
export interface OcrImageOccurrence extends ImageOccurrenceIdentity {
  imageId: string; frameUrl: string; snapshotId: string; imageUrl: string | null; capturedAt: string | null;
  original: ImageAssetReference | null; input: ImageInputReference | null; styles: ElementStyle[];
  concealment: ('TRANSPARENT' | 'OFFSCREEN')[]; status: OcrImageStatus; extractionStatus: OcrExtractionStatus | null;
  text: string | null; confidence: null; model: typeof OCR_MODEL | null; promptVersion: string; cacheOf: string | null;
  attemptCount: number; usage: OcrUsage; reasonCode: ImageReasonCode | null;
}
export interface OcrFile { schemaVersion: 2; runId: string; enabled: boolean; model: typeof OCR_MODEL | null; images: OcrImageOccurrence[] }
export interface SourceTextRange { imageId: string; rawStart: number; rawEnd: number }
export interface CandidateSource { sourceType: 'dom_text' | 'image_ocr'; sourceIds: string[]; sourceTextRanges: SourceTextRange[] }
/** Observation only: advertisement classification is exclusively a downstream CLEF analysis. */
export interface DetectionCandidateV2 extends CandidateSource {
  candidateId: string; url: string; frameUrl: string; framePath: string[]; location: string; rawText: string;
  normalizedText: string; links: string[]; techniques: Technique[]; evidence: EvidenceReference; observationIds: string[];
}
/** Volatile browser data. selectedUrl may contain data/blob and must never be serialized into OCR records. */
export interface CollectedImageOccurrence extends ImageOccurrenceIdentity {
  imageId: string; frameUrl: string; snapshotId: string; selectedUrl: string; imageUrl: string | null;
  links: string[]; styles: ElementStyle[]; bounds: Bounds; documentBounds: Bounds;
  concealment: ('TRANSPARENT' | 'OFFSCREEN')[];
}
/** Private temporary file transfer; output owns registration, final relative paths and persisted byte hashes. */
export interface ImageScratchAsset { scratchPath: string; sha256: string; mime: string; byteLength: number }
export interface ImageScratchInput extends ImageScratchAsset { mime: 'image/png'; width: number; height: number; frameIndex: 0 }
export interface CapturedImageAssets { imageId: string; capturedAt: string; original: ImageScratchAsset; input: ImageScratchInput }
export interface CollectedElementV2 extends CollectedElement { sourceType: 'dom_text' }
export const REVIEW_REASONS_V2 = ['AI_ERROR', 'OCR_ERROR', 'NOT_ANALYZED', 'OCR_UNREADABLE', 'UNCERTAIN', 'OCR_NO_TEXT'] as const;
export type ReviewReasonV2 = typeof REVIEW_REASONS_V2[number];
export interface ReviewCandidateV2 extends CandidateSource {
  candidateId: string; url: string; location: string; evidenceText: string; techniques: Technique[];
  reason: ReviewReasonV2; ai: AiAnalysis | null; evidence: EvidenceReference;
}
export interface ReviewFileV2 { schemaVersion: 2; runId: string; candidates: ReviewCandidateV2[] }
export interface FindingDetailV2 extends CandidateSource {
  findingId: string; candidateId: string; decisionSource: 'clef'; ruleIds: string[]; ai: AiAnalysis; evidence: EvidenceReference;
  resultFile: 'result.json' | 'result_extra.json'; observationIds: string[];
}
export interface FindingDetailsFileV2 { schemaVersion: 2; runId: string; details: FindingDetailV2[] }
export interface ScanStatusFileV2 {
  schemaVersion: 2; run: RunSnapshotV2; scope: Omit<ScanScope, 'skipped'> & { skipped: { url: string; reasonCode: RunErrorV2['code'] }[] };
  files: { resultPath: string | null; reviewPath: string | null; findingDetailsPath: string | null; evidenceDir: string | null;
    resultSha256: string | null; extraResultPath: string | null; extraResultSha256: string | null; ocrPath: string | null };
  resultSaved: boolean; extraResultSaved: boolean;
  imageScope: { enabled: boolean; framePolicy: 'first'; unsupportedKinds: ('canvas' | 'video' | 'animation_remaining_frames')[]; pendingImageIds: string[] };
}
