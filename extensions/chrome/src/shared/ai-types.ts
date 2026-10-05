import { AI_RULE_CATEGORIES } from "./constants.js";

export type AiRuleCategory = (typeof AI_RULE_CATEGORIES)[number];

export type AiRule = {
  id: string;
  selector: string;
  enabled: boolean;
  category: AiRuleCategory;
  reason: string;
  confidence: number;
  model: string;
  createdAt: string;
};

export type AiSiteRules = {
  id: string;
  matchers: string[];
  enabled: boolean;
  generatedAt: string;
  rules: AiRule[];
};

export type AiRuleStore = {
  version: number;
  settings: { globalEnabled: boolean; enabledCategories: AiRuleCategory[] };
  sites: AiSiteRules[];
};
