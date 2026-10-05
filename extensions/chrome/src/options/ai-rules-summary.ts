import { AI_RULE_CATEGORIES } from "../shared/constants.js";
import type { AiRuleCategory, AiRuleStore } from "../shared/ai-types.js";

export type AiRuleSummary = {
  totalSites: number;
  totalRules: number;
  byCategory: Record<AiRuleCategory, number>;
};

export function summarizeAiRules(store: AiRuleStore): AiRuleSummary {
  const byCategory = {} as Record<AiRuleCategory, number>;
  for (const category of AI_RULE_CATEGORIES) {
    byCategory[category] = 0;
  }
  let totalRules = 0;
  for (const site of store.sites) {
    for (const rule of site.rules) {
      totalRules += 1;
      byCategory[rule.category] += 1;
    }
  }
  return { totalSites: store.sites.length, totalRules, byCategory };
}
