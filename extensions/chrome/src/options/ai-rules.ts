import { AI_RULE_CATEGORIES, AI_RULE_STORAGE_KEY } from "../shared/constants.js";
import type { AiRuleCategory, AiRule, AiSiteRules } from "../shared/ai-types.js";
import { readAiRuleStore, setAiSiteEnabled, setAiRuleEnabled, clearAiRules } from "../shared/ai-rule-storage.js";
import { profileNameFromMatcher } from "../shared/storage-matchers.js";
import { AI_CATEGORY_LABELS } from "./ai-category-labels.js";
import { summarizeAiRules } from "./ai-rules-summary.js";
import {
  aiRuleFilterElement, aiRuleClearButtonElement, aiRuleListElement,
  aiRuleEmptyElement, aiRuleSummaryElement
} from "./elements.js";

function siteLabel(matchers: string[]): string {
  const first = matchers[0];
  return first ? profileNameFromMatcher(first) : "알 수 없는 사이트";
}

function buildRuleRow(siteId: string, rule: AiRule): HTMLElement {
  const row = document.createElement("div");
  row.className = "options__ai-rule";

  const toggleLabel = document.createElement("label");
  toggleLabel.className = "options__ai-rule-toggle";
  const toggle = document.createElement("input");
  toggle.type = "checkbox";
  toggle.checked = rule.enabled;
  toggle.addEventListener("change", () => {
    void setAiRuleEnabled(siteId, rule.id, toggle.checked);
  });
  toggleLabel.append(toggle);

  const badge = document.createElement("span");
  badge.className = "options__ai-badge";
  badge.textContent = AI_CATEGORY_LABELS[rule.category];

  const selector = document.createElement("code");
  selector.className = "options__ai-selector";
  selector.textContent = rule.selector;

  const meta = document.createElement("span");
  meta.className = "options__ai-rule-meta";
  meta.textContent = `${Math.round(rule.confidence * 100)}% · ${rule.reason}`;

  row.append(toggleLabel, badge, selector, meta);
  return row;
}

function buildSiteCard(site: AiSiteRules, filter: AiRuleCategory | "all"): HTMLElement | null {
  const rules = filter === "all" ? site.rules : site.rules.filter((rule) => rule.category === filter);
  if (rules.length === 0) {
    return null;
  }
  const card = document.createElement("section");
  card.className = "options__ai-site-card";

  const header = document.createElement("div");
  header.className = "options__ai-site-header";

  const siteToggleLabel = document.createElement("label");
  siteToggleLabel.className = "options__ai-rule-toggle";
  const siteToggle = document.createElement("input");
  siteToggle.type = "checkbox";
  siteToggle.checked = site.enabled;
  siteToggle.addEventListener("change", () => {
    void setAiSiteEnabled(site.id, siteToggle.checked);
  });
  siteToggleLabel.append(siteToggle);

  const title = document.createElement("h3");
  title.className = "options__ai-site-title";
  title.textContent = siteLabel(site.matchers);

  const count = document.createElement("span");
  count.className = "options__ai-rule-meta";
  count.textContent = `규칙 ${rules.length}개`;

  header.append(siteToggleLabel, title, count);
  card.append(header);
  for (const rule of rules) {
    card.append(buildRuleRow(site.id, rule));
  }
  return card;
}

export async function renderAiRuleList(): Promise<void> {
  const store = await readAiRuleStore();
  const filterValue = aiRuleFilterElement.value;
  const filter: AiRuleCategory | "all" =
    AI_RULE_CATEGORIES.includes(filterValue as AiRuleCategory) ? (filterValue as AiRuleCategory) : "all";

  const summary = summarizeAiRules(store);
  const breakdown = AI_RULE_CATEGORIES
    .filter((category) => summary.byCategory[category] > 0)
    .map((category) => `${AI_CATEGORY_LABELS[category]} ${summary.byCategory[category]}`)
    .join(" · ");
  aiRuleSummaryElement.textContent = breakdown.length > 0
    ? `사이트 ${summary.totalSites}곳 · 규칙 ${summary.totalRules}개 (${breakdown})`
    : `사이트 ${summary.totalSites}곳 · 규칙 ${summary.totalRules}개`;

  aiRuleListElement.replaceChildren();
  let shown = 0;
  for (const site of store.sites) {
    const card = buildSiteCard(site, filter);
    if (card) {
      aiRuleListElement.append(card);
      shown += 1;
    }
  }
  aiRuleEmptyElement.hidden = shown > 0;
}

function buildFilterOptions(): void {
  const allOption = document.createElement("option");
  allOption.value = "all";
  allOption.textContent = "전체 카테고리";
  aiRuleFilterElement.append(allOption);
  for (const category of AI_RULE_CATEGORIES) {
    const option = document.createElement("option");
    option.value = category;
    option.textContent = AI_CATEGORY_LABELS[category];
    aiRuleFilterElement.append(option);
  }
}

export function wireAiRules(): void {
  buildFilterOptions();
  aiRuleFilterElement.addEventListener("change", () => {
    void renderAiRuleList();
  });
  aiRuleClearButtonElement.addEventListener("click", () => {
    void clearAiRules();
  });
  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName === "local" && AI_RULE_STORAGE_KEY in changes) {
      void renderAiRuleList();
    }
  });
  void renderAiRuleList();
}
