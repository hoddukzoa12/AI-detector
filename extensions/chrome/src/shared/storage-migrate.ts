import { STORAGE_KEY } from "./constants.js";
import type { RuleProfile, RuleStore } from "./types.js";
import {
  createProfileCard,
  emptyRuleProfile,
  generateSelectorRuleId,
  normalizeRuleStore
} from "../../packages/infocutter-selector-rules/src/index.js";

export { createProfileCard };

export function generateId(): string {
  return generateSelectorRuleId();
}

export function emptyProfile(): RuleProfile {
  return emptyRuleProfile();
}

export function normalizeStore(candidate: unknown): RuleStore {
  return normalizeRuleStore(candidate);
}

export async function readStore(): Promise<RuleStore> {
  const result = await chrome.storage.local.get(STORAGE_KEY);
  const candidate: unknown = result[STORAGE_KEY];
  return normalizeStore(candidate);
}

export async function writeStore(store: RuleStore): Promise<void> {
  await chrome.storage.local.set({
    [STORAGE_KEY]: store
  });
}
