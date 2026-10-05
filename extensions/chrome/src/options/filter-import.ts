import { TEXT_BLOCK_STORAGE_KEY } from "../shared/constants.js";
import { appendImportedNetworkRules, readNetworkRuleStore, writeNetworkRuleStore } from "../shared/network-rules.js";
import { readStore, writeStore } from "../shared/storage.js";
import { readTextBlockStore } from "../shared/text-block-storage.js";
import { domainsToMatchers, parseFilterList } from "../../packages/infocutter-filter-importer/src/index.js";
import type { NetworkFilterImportRule } from "../../packages/infocutter-filter-importer/src/index.js";
import type { RuleProfile, RuleStore, StoredRule } from "../shared/types.js";
import { filterImportInputElement, filterImportStatusElement } from "./elements.js";
import { applyNetworkRulesNow } from "./network-rules.js";

export function filterImportSummaryLabel(): string {
  const parsed = parseFilterList(filterImportInputElement.value);
  return [
    `selector ${parsed.summary.cosmeticCount}개`,
    `text ${parsed.summary.textCount}개`,
    `exception ${parsed.summary.cosmeticExceptionCount}개`,
    `network ${parsed.summary.networkCount}개`,
    `unsupported ${parsed.summary.unsupportedCount}개`
  ].join(" · ");
}

function isNetworkFilterImportRule(rule: ReturnType<typeof parseFilterList>["rules"][number]): rule is NetworkFilterImportRule {
  return rule.kind === "network";
}

function sameMatchers(left: string[], right: string[]): boolean {
  if (left.length !== right.length) {
    return false;
  }

  return left.every((matcher, index) => matcher === right[index]);
}

function ensureImportedSelectorProfile(
  store: RuleStore,
  name: string,
  matchers: string[],
  timestamp: string
): RuleProfile {
  const existing = store.profiles.find((profile) => (
    profile.sourceTemplateSlug === null &&
    profile.name === name &&
    sameMatchers(profile.matchers, matchers)
  ));

  if (existing) {
    return existing;
  }

  const profile: RuleProfile = {
    cards: [],
    enabled: true,
    id: `import-profile:${timestamp}:${store.profiles.length}`,
    matchers,
    name,
    rules: [],
    sourceTemplateSlug: null,
    updatedAt: timestamp
  };
  store.profiles.push(profile);
  return profile;
}

function appendImportedSelectorRule(
  profile: RuleProfile,
  cardId: string,
  cardName: string,
  selector: string,
  mode: StoredRule["mode"],
  timestamp: string
): void {
  if (!profile.cards.some((card) => card.id === cardId)) {
    profile.cards.push({
      createdAt: timestamp,
      enabled: true,
      id: cardId,
      name: cardName,
      updatedAt: timestamp
    });
  }

  if (profile.rules.some((rule) => rule.cardId === cardId && rule.selector === selector && rule.mode === mode && rule.frameScope === null)) {
    return;
  }

  profile.rules.push({
    cardId,
    cardName,
    createdAt: timestamp,
    frameScope: null,
    mode,
    selector
  });
  profile.updatedAt = timestamp;
}

export async function importSupportedFilterRules(): Promise<void> {
  const parsed = parseFilterList(filterImportInputElement.value);
  const store = await readStore();
  const textStore = await readTextBlockStore();
  const networkStore = await readNetworkRuleStore();
  const timestamp = new Date().toISOString();
  let exceptionCount = 0;
  let selectorCount = 0;
  let textCount = 0;

  for (const rule of parsed.rules) {
    if (rule.kind === "cosmetic") {
      const matchers = domainsToMatchers(rule.domains);
      const name = rule.domains.length > 0 ? `Imported filters ${rule.domains.join(", ")}` : "Imported global filters";
      const cardId = `import:${timestamp}:${selectorCount}`;
      const profile = ensureImportedSelectorProfile(store, name, matchers, timestamp);
      appendImportedSelectorRule(profile, cardId, rule.selector, rule.selector, "hide", timestamp);
      selectorCount += 1;
      continue;
    }

    if (rule.kind === "cosmetic-exception") {
      const matchers = domainsToMatchers(rule.domains);
      const name = rule.domains.length > 0 ? `Imported filters ${rule.domains.join(", ")}` : "Imported global filters";
      const cardId = `import-exception:${timestamp}:${exceptionCount}`;
      const profile = ensureImportedSelectorProfile(store, name, matchers, timestamp);
      appendImportedSelectorRule(profile, cardId, `예외 · ${rule.selector}`, rule.selector, "unhide", timestamp);
      exceptionCount += 1;
      continue;
    }

    if (rule.kind === "text") {
      const matchers = domainsToMatchers(rule.domains);
      textStore.profiles.push({
        enabled: true,
        id: `import-text-profile:${timestamp}:${textCount}`,
        matchers,
        name: rule.domains.length > 0 ? `Imported text ${rule.domains.join(", ")}` : "Imported global text",
        rules: [
          {
            createdAt: timestamp,
            enabled: true,
            fingerprint: null,
            id: `import-text-rule:${timestamp}:${textCount}`,
            keyword: rule.text,
            minMatchCount: 2,
            objectId: `import-text-object:${timestamp}:${textCount}`,
            objectName: rule.text,
            objectTags: ["ad"],
            updatedAt: timestamp
          }
        ],
        updatedAt: timestamp
      });
      textCount += 1;
    }
  }

  const networkImport = appendImportedNetworkRules(
    networkStore,
    parsed.rules.filter(isNetworkFilterImportRule),
    timestamp
  );

  await writeStore(store);
  await chrome.storage.local.set({
    [TEXT_BLOCK_STORAGE_KEY]: textStore
  });
  await writeNetworkRuleStore(networkImport.store);

  let dnrApplyLabel = "";
  if (networkImport.importedCount > 0) {
    const applyData = await applyNetworkRulesNow();
    dnrApplyLabel = ` · network ${networkImport.importedCount}개 저장/DNR ${applyData.addedRuleCount}개 적용`;
  }

  const skippedLabel = networkImport.skippedCount > 0
    ? ` · network 미지원 ${networkImport.skippedCount}개`
    : "";
  filterImportStatusElement.textContent = `저장 완료 · selector ${selectorCount}개 · exception ${exceptionCount}개 · text ${textCount}개${dnrApplyLabel}${skippedLabel} · 전체 파싱 ${filterImportSummaryLabel()}`;
}
