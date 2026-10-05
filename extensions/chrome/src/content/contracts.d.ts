/* eslint-disable @typescript-eslint/consistent-type-definitions */

declare const InfocutterSelectorRules: typeof import("../../packages/infocutter-selector-rules/src/index.js");
declare const InfocutterTextBlocks: typeof import("../../packages/infocutter-text-blocks/src/index.js");
declare const InfocutterWatch: typeof import("../../packages/infocutter-watch/src/index.js");

type StoredSiteRule = import("../../packages/infocutter-selector-rules/src/index.js").StoredRule;
type ProfileCardRecord = import("../../packages/infocutter-selector-rules/src/index.js").ProfileCard;
type SiteRuleSet = import("../../packages/infocutter-selector-rules/src/index.js").RuleProfile;
type RuleStore = import("../../packages/infocutter-selector-rules/src/index.js").RuleStore;
type SavedCardState = import("../../packages/infocutter-selector-rules/src/index.js").SavedCard;
type ActiveSiteState = import("../../packages/infocutter-selector-rules/src/index.js").ActiveSiteState;

interface TextBlockRule {
  createdAt: string;
  enabled: boolean;
  fingerprint: string | null;
  id: string;
  keyword: string;
  minMatchCount: number;
  objectId: string;
  objectName: string;
  objectTags: string[];
  updatedAt: string;
}

interface TextBlockProfile {
  enabled: boolean;
  id: string;
  matchers: string[];
  name: string;
  rules: TextBlockRule[];
  updatedAt: string;
}

interface TextBlockStore {
  version: 1;
  settings: {
    globalEnabled: boolean;
    hiddenObjectTags: string[];
  };
  profiles: TextBlockProfile[];
}

interface ActiveTextBlockState {
  activeProfileId: string | null;
  activeProfileName: string | null;
  globalEnabled: boolean;
  hiddenObjectTags: string[];
  matchers: string[];
  profileEnabled: boolean;
  ruleCount: number;
  rules: TextBlockRule[];
  updatedAt: string;
  url: string;
}

interface TextBlockDebugSample {
  classSignature: string;
  parentTag: string;
  tagName: string;
  textSnippet: string;
}

interface TextBlockDebugGroup {
  blockCount: number;
  childSignature: string;
  classSignature: string;
  fingerprint: string;
  matchesRuleFingerprint: boolean;
  parentTag: string;
  qualifies: boolean;
  samples: TextBlockDebugSample[];
  tagName: string;
}

interface TextBlockRuleDiagnostics {
  eligibleBlockCount: number;
  eligibleGroupCount: number;
  fingerprint: string | null;
  groups: TextBlockDebugGroup[];
  keyword: string;
  minMatchCount: number;
  objectId: string;
  objectName: string;
  objectTags: string[];
  ruleId: string;
  tagMatched: boolean;
}

interface ActiveTextBlockDiagnostics {
  activeProfileId: string | null;
  activeProfileName: string | null;
  globalEnabled: boolean;
  hiddenObjectTags: string[];
  profileEnabled: boolean;
  rules: TextBlockRuleDiagnostics[];
  supported: boolean;
  url: string;
}

interface PickerSessionEntry {
  cardId: string;
  cardName: string;
  createdAt: string;
  frameScope: string | null;
  selector: string;
}

interface SessionPaletteEntry {
  fill: string;
  stroke: string;
}

type OverlayTone = "hover" | "preview";

interface SelectorAssessmentResult {
  applyAllowed: boolean;
  label: string;
  matches: number | null;
  tone: string;
}

interface HoverSummaryResult {
  assessment: SelectorAssessmentResult | null;
  label: string;
  selector: string | null;
}

interface HoverCandidatePreview {
  applyAllowed: boolean;
  assessment: SelectorAssessmentResult | null;
  label: string;
  matches: number;
  selector: string | null;
}

interface AiRuleRecord {
  id: string;
  selector: string;
  enabled: boolean;
  category: string;
}

interface AiSiteRulesRecord {
  id: string;
  matchers: string[];
  enabled: boolean;
  rules: AiRuleRecord[];
}

interface AiRuleStoreRecord {
  version: number;
  settings: { globalEnabled: boolean; enabledCategories: string[] | null };
  sites: AiSiteRulesRecord[];
}

interface AiBlockRecord {
  selector: string;
  text: string;
  imageAlt: string;
  imageSrc: string;
}
