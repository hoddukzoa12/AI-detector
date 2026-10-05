import { NETWORK_RULE_STORAGE_KEY, NETWORK_RULE_STORAGE_VERSION } from "./constants.js";
import { networkRuleToDnrRule, parseFilterRule } from "../../packages/infocutter-filter-importer/src/index.js";
import type { NetworkFilterImportRule, PortableDnrRule } from "../../packages/infocutter-filter-importer/src/index.js";

export const NETWORK_RULE_ID_BASE = 1_000_000;
export const NETWORK_RULE_ID_MAX = 1_199_999;

export type ImportedNetworkRule = {
  createdAt: string;
  enabled: boolean;
  id: number;
  raw: string;
  rule: PortableDnrRule;
  updatedAt: string;
};

export type NetworkRuleStore = {
  version: number;
  rules: ImportedNetworkRule[];
  updatedAt: string;
};

export type NetworkRuleImportResult = {
  importedCount: number;
  skippedCount: number;
  skippedReasons: string[];
  store: NetworkRuleStore;
};

function emptyNetworkRuleStore(): NetworkRuleStore {
  return {
    version: NETWORK_RULE_STORAGE_VERSION,
    rules: [],
    updatedAt: new Date(0).toISOString()
  };
}

function normalizeImportedNetworkRule(candidate: unknown): ImportedNetworkRule | null {
  if (!candidate || typeof candidate !== "object") {
    return null;
  }

  const partial = candidate as Partial<ImportedNetworkRule>;
  if (
    typeof partial.id !== "number" ||
    partial.id < NETWORK_RULE_ID_BASE ||
    partial.id > NETWORK_RULE_ID_MAX ||
    typeof partial.raw !== "string" ||
    !partial.rule ||
    typeof partial.rule !== "object"
  ) {
    return null;
  }

  return {
    createdAt: typeof partial.createdAt === "string" ? partial.createdAt : new Date(0).toISOString(),
    enabled: typeof partial.enabled === "boolean" ? partial.enabled : true,
    id: partial.id,
    raw: partial.raw,
    rule: partial.rule,
    updatedAt: typeof partial.updatedAt === "string" ? partial.updatedAt : new Date(0).toISOString()
  };
}

export function normalizeNetworkRuleStore(candidate: unknown): NetworkRuleStore {
  if (!candidate || typeof candidate !== "object") {
    return emptyNetworkRuleStore();
  }

  const partial = candidate as Partial<NetworkRuleStore>;
  return {
    version: NETWORK_RULE_STORAGE_VERSION,
    rules: Array.isArray(partial.rules)
      ? partial.rules
          .map((rule) => normalizeImportedNetworkRule(rule))
          .filter((rule): rule is ImportedNetworkRule => rule !== null)
      : [],
    updatedAt: typeof partial.updatedAt === "string" ? partial.updatedAt : new Date(0).toISOString()
  };
}

export async function readNetworkRuleStore(): Promise<NetworkRuleStore> {
  const result = await chrome.storage.local.get(NETWORK_RULE_STORAGE_KEY);
  return normalizeNetworkRuleStore(result[NETWORK_RULE_STORAGE_KEY]);
}

export async function writeNetworkRuleStore(store: NetworkRuleStore): Promise<void> {
  await chrome.storage.local.set({
    [NETWORK_RULE_STORAGE_KEY]: normalizeNetworkRuleStore(store)
  });
}

function nextNetworkRuleId(store: NetworkRuleStore): number {
  const maxId = store.rules.reduce((currentMax, rule) => Math.max(currentMax, rule.id), NETWORK_RULE_ID_BASE - 1);
  const nextId = maxId + 1;
  if (nextId > NETWORK_RULE_ID_MAX) {
    throw new Error("인포커터 네트워크 규칙 ID 범위를 초과했습니다.");
  }

  return nextId;
}

export function appendImportedNetworkRules(
  store: NetworkRuleStore,
  networkRules: NetworkFilterImportRule[],
  now = new Date().toISOString()
): NetworkRuleImportResult {
  let nextId = nextNetworkRuleId(store);
  const importedRules: ImportedNetworkRule[] = [];
  const skippedReasons: string[] = [];

  for (const networkRule of networkRules) {
    const converted = networkRuleToDnrRule(networkRule, nextId);
    if (!converted.rule) {
      skippedReasons.push(`${networkRule.raw}: ${converted.reason ?? "unsupported network rule"}`);
      continue;
    }

    importedRules.push({
      createdAt: now,
      enabled: true,
      id: converted.rule.id,
      raw: networkRule.raw,
      rule: converted.rule,
      updatedAt: now
    });
    nextId += 1;
  }

  return {
    importedCount: importedRules.length,
    skippedCount: skippedReasons.length,
    skippedReasons,
    store: {
      version: NETWORK_RULE_STORAGE_VERSION,
      rules: [...store.rules, ...importedRules],
      updatedAt: now
    }
  };
}

export function enabledPortableDnrRules(store: NetworkRuleStore): PortableDnrRule[] {
  return store.rules
    .filter((rule) => rule.enabled)
    .map((rule) => rule.rule);
}

export async function removeNetworkRule(id: number): Promise<void> {
  const store = await readNetworkRuleStore();
  await writeNetworkRuleStore({
    ...store,
    rules: store.rules.filter((rule) => rule.id !== id),
    updatedAt: new Date().toISOString()
  });
}

async function patchNetworkRule(id: number, patch: Partial<ImportedNetworkRule>): Promise<void> {
  const store = await readNetworkRuleStore();
  const now = new Date().toISOString();
  await writeNetworkRuleStore({
    ...store,
    rules: store.rules.map((rule) => (
      rule.id === id
        ? {
            ...rule,
            ...patch,
            updatedAt: now
          }
        : rule
    )),
    updatedAt: now
  });
}

export async function setNetworkRuleEnabled(id: number, enabled: boolean): Promise<void> {
  await patchNetworkRule(id, { enabled });
}

export async function updateNetworkRuleRaw(id: number, raw: string): Promise<void> {
  const parsedRule = parseFilterRule(raw);
  if (parsedRule?.kind !== "network") {
    throw new Error("네트워크 규칙 문법만 저장할 수 있습니다.");
  }

  const converted = networkRuleToDnrRule(parsedRule, id);
  if (!converted.rule) {
    throw new Error(converted.reason ?? "지원하지 않는 네트워크 규칙입니다.");
  }

  const nextRule = converted.rule;
  await patchNetworkRule(id, {
    raw: parsedRule.raw,
    rule: nextRule
  });
}
