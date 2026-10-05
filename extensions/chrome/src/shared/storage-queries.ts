import type { ActiveSiteState, RuleProfile, RuleStore } from "./types.js";
import { readStore } from "./storage-migrate.js";
import {
  buildActiveSiteState,
  findMatchingRuleProfile,
  getEnabledRules,
  groupRulesByCard
} from "../../packages/infocutter-selector-rules/src/index.js";

export { getEnabledRules, groupRulesByCard };

export function findMatchingProfile(store: RuleStore, url: string): RuleProfile | null {
  return findMatchingRuleProfile(store, url);
}

export async function readActiveSiteState(url: string): Promise<ActiveSiteState> {
  const store = await readStore();
  return buildActiveSiteState(store, url);
}
