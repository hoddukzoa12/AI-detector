import { AI_RULE_CATEGORIES, AI_RULE_STORAGE_KEY, AI_RULE_STORAGE_VERSION } from "./constants.js";
import { clampConfidence } from "./ai-llm-client.js";
import { matchesUrl } from "./storage-matchers.js";
import { readBooleanSetting } from "../../packages/infocutter-selector-rules/src/index.js";
import type { AiRule, AiRuleCategory, AiRuleStore, AiSiteRules } from "./ai-types.js";

function generateAiId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `ai-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function normalizeEnabledCategories(value: unknown): AiRuleCategory[] {
  if (!Array.isArray(value)) {
    return [...AI_RULE_CATEGORIES];
  }
  return value.filter((entry): entry is AiRuleCategory => AI_RULE_CATEGORIES.includes(entry as AiRuleCategory));
}

function emptyAiRuleStore(): AiRuleStore {
  return {
    version: AI_RULE_STORAGE_VERSION,
    settings: { globalEnabled: true, enabledCategories: [...AI_RULE_CATEGORIES] },
    sites: []
  };
}

function normalizeCategory(value: unknown): AiRuleCategory {
  return AI_RULE_CATEGORIES.includes(value as AiRuleCategory) ? (value as AiRuleCategory) : "other";
}

function normalizeAiRule(raw: unknown): AiRule | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const selector: unknown = Reflect.get(raw, "selector");
  if (typeof selector !== "string" || selector.length === 0) {
    return null;
  }
  const id: unknown = Reflect.get(raw, "id");
  const enabled: unknown = Reflect.get(raw, "enabled");
  const reason: unknown = Reflect.get(raw, "reason");
  const confidence: unknown = Reflect.get(raw, "confidence");
  const model: unknown = Reflect.get(raw, "model");
  const createdAt: unknown = Reflect.get(raw, "createdAt");
  return {
    id: typeof id === "string" && id.length > 0 ? id : generateAiId(),
    selector,
    enabled: typeof enabled === "boolean" ? enabled : true,
    category: normalizeCategory(Reflect.get(raw, "category")),
    reason: typeof reason === "string" ? reason : "",
    confidence: clampConfidence(confidence),
    model: typeof model === "string" ? model : "",
    createdAt: typeof createdAt === "string" ? createdAt : new Date(0).toISOString()
  };
}

function normalizeAiSite(raw: unknown): AiSiteRules | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const matchersValue: unknown = Reflect.get(raw, "matchers");
  const matchers = Array.isArray(matchersValue)
    ? matchersValue.filter((matcher): matcher is string => typeof matcher === "string" && matcher.length > 0)
    : [];
  const rulesValue: unknown = Reflect.get(raw, "rules");
  const rules = Array.isArray(rulesValue)
    ? rulesValue.map(normalizeAiRule).filter((rule): rule is AiRule => rule !== null)
    : [];
  const id: unknown = Reflect.get(raw, "id");
  const enabled: unknown = Reflect.get(raw, "enabled");
  const generatedAt: unknown = Reflect.get(raw, "generatedAt");
  return {
    id: typeof id === "string" && id.length > 0 ? id : generateAiId(),
    matchers,
    enabled: typeof enabled === "boolean" ? enabled : true,
    generatedAt: typeof generatedAt === "string" ? generatedAt : new Date(0).toISOString(),
    rules
  };
}

export function normalizeAiRuleStore(candidate: unknown): AiRuleStore {
  if (!candidate || typeof candidate !== "object") {
    return emptyAiRuleStore();
  }
  const settingsValue: unknown = Reflect.get(candidate, "settings");
  const globalEnabled = readBooleanSetting(settingsValue, "globalEnabled", true);
  const enabledCategoriesValue: unknown = settingsValue && typeof settingsValue === "object" ? Reflect.get(settingsValue, "enabledCategories") : undefined;
  const enabledCategories = normalizeEnabledCategories(enabledCategoriesValue);
  const sitesValue: unknown = Reflect.get(candidate, "sites");
  const sites = Array.isArray(sitesValue)
    ? sitesValue.map(normalizeAiSite).filter((site): site is AiSiteRules => site !== null)
    : [];
  return {
    version: AI_RULE_STORAGE_VERSION,
    settings: { globalEnabled, enabledCategories },
    sites
  };
}

export async function readAiRuleStore(): Promise<AiRuleStore> {
  const result = await chrome.storage.local.get(AI_RULE_STORAGE_KEY);
  return normalizeAiRuleStore(result[AI_RULE_STORAGE_KEY]);
}

export async function writeAiRuleStore(store: AiRuleStore): Promise<void> {
  await chrome.storage.local.set({ [AI_RULE_STORAGE_KEY]: store });
}

export function findMatchingAiSite(store: AiRuleStore, url: string): AiSiteRules | null {
  return store.sites.find((site) => site.matchers.some((matcher) => matchesUrl(matcher, url))) ?? null;
}

export async function setAiGlobalEnabled(enabled: boolean): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = { ...store, settings: { ...store.settings, globalEnabled: enabled } };
  await writeAiRuleStore(next);
  return next;
}

export async function setAiEnabledCategories(categories: AiRuleCategory[]): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = { ...store, settings: { ...store.settings, enabledCategories: normalizeEnabledCategories(categories) } };
  await writeAiRuleStore(next);
  return next;
}

async function mutateAiRuleStore(transform: (store: AiRuleStore) => AiRuleStore): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next = transform(store);
  await writeAiRuleStore(next);
  return next;
}

export async function setAiSiteEnabled(siteId: string, enabled: boolean): Promise<AiRuleStore> {
  return mutateAiRuleStore((store) => ({
    ...store,
    sites: store.sites.map((site) => (site.id === siteId ? { ...site, enabled } : site))
  }));
}

export async function setAiRuleEnabled(siteId: string, ruleId: string, enabled: boolean): Promise<AiRuleStore> {
  return mutateAiRuleStore((store) => ({
    ...store,
    sites: store.sites.map((site) => (
      site.id === siteId
        ? { ...site, rules: site.rules.map((rule) => (rule.id === ruleId ? { ...rule, enabled } : rule)) }
        : site
    ))
  }));
}

export async function replaceAiSiteRules(
  matchers: string[],
  rules: { selector: string; category: AiRuleCategory; reason: string; confidence: number }[],
  model: string
): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const timestamp = new Date().toISOString();
  const site: AiSiteRules = {
    id: generateAiId(),
    matchers,
    enabled: true,
    generatedAt: timestamp,
    rules: rules.map((rule) => ({
      id: generateAiId(),
      selector: rule.selector,
      enabled: true,
      category: normalizeCategory(rule.category),
      reason: rule.reason,
      confidence: rule.confidence,
      model,
      createdAt: timestamp
    }))
  };
  const sameMatchers = (left: string[], right: string[]): boolean =>
    left.length === right.length && left.every((matcher, index) => matcher === right[index]);
  const existingIndex = store.sites.findIndex((candidate) => sameMatchers(candidate.matchers, matchers));
  const sites = existingIndex >= 0
    ? store.sites.map((candidate, index) => (index === existingIndex ? site : candidate))
    : [...store.sites, site];
  const next: AiRuleStore = { ...store, sites };
  await writeAiRuleStore(next);
  return next;
}

export async function clearAiRules(): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = { ...store, sites: [] };
  await writeAiRuleStore(next);
  return next;
}
