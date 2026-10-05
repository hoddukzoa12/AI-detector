/* eslint-disable @typescript-eslint/no-unused-vars */

function clearAiHiddenMarkers(): void {
  document.querySelectorAll(`[${AI_HIDDEN_ATTR}]`).forEach((element) => {
    element.removeAttribute(AI_HIDDEN_ATTR);
  });
}

function ensureAiStyleElement(): HTMLStyleElement {
  const existing = document.getElementById(AI_STYLE_ELEMENT_ID);
  if (existing instanceof HTMLStyleElement) {
    return existing;
  }
  const style = document.createElement("style");
  style.id = AI_STYLE_ELEMENT_ID;
  document.documentElement.append(style);
  return style;
}

function normalizeAiStoreForContent(candidate: unknown): AiRuleStoreRecord {
  const empty: AiRuleStoreRecord = { version: 1, settings: { globalEnabled: true, enabledCategories: null }, sites: [] };
  if (!candidate || typeof candidate !== "object") {
    return empty;
  }
  const settingsValue: unknown = Reflect.get(candidate, "settings");
  const globalEnabled = InfocutterSelectorRules.readBooleanSetting(settingsValue, "globalEnabled", true);
  const enabledCategoriesValue: unknown =
    settingsValue && typeof settingsValue === "object" ? (settingsValue as Record<string, unknown>).enabledCategories : null;
  const enabledCategories: string[] | null = Array.isArray(enabledCategoriesValue)
    ? enabledCategoriesValue.filter((entry): entry is string => typeof entry === "string")
    : null;
  const sitesValue: unknown = Reflect.get(candidate, "sites");
  const sites: AiSiteRulesRecord[] = Array.isArray(sitesValue)
    ? sitesValue
        .filter((site): site is Record<string, unknown> => !!site && typeof site === "object")
        .map((site) => {
          const matchersValue: unknown = Reflect.get(site, "matchers");
          const rulesValue: unknown = Reflect.get(site, "rules");
          const enabled: unknown = Reflect.get(site, "enabled");
          const id: unknown = Reflect.get(site, "id");
          return {
            id: typeof id === "string" ? id : "",
            matchers: Array.isArray(matchersValue) ? matchersValue.filter((matcher): matcher is string => typeof matcher === "string") : [],
            enabled: typeof enabled === "boolean" ? enabled : true,
            rules: Array.isArray(rulesValue)
              ? rulesValue
                  .filter((rule): rule is Record<string, unknown> => !!rule && typeof rule === "object")
                  .map((rule) => {
                    const selector: unknown = Reflect.get(rule, "selector");
                    const ruleEnabled: unknown = Reflect.get(rule, "enabled");
                    const ruleId: unknown = Reflect.get(rule, "id");
                    const category: unknown = Reflect.get(rule, "category");
                    return {
                      id: typeof ruleId === "string" ? ruleId : "",
                      selector: typeof selector === "string" ? selector : "",
                      enabled: typeof ruleEnabled === "boolean" ? ruleEnabled : true,
                      category: typeof category === "string" ? category : ""
                    };
                  })
                  .filter((rule) => rule.selector.length > 0)
              : []
          };
        })
    : [];
  return { version: 1, settings: { globalEnabled, enabledCategories }, sites };
}

async function renderAiRules(): Promise<void> {
  const result = await chrome.storage.local.get(AI_RULE_STORAGE_KEY);
  const store = normalizeAiStoreForContent(result[AI_RULE_STORAGE_KEY]);
  const style = ensureAiStyleElement();
  clearAiHiddenMarkers();

  if (!store.settings.globalEnabled) {
    style.textContent = "";
    return;
  }

  const url = ownerPageUrl();
  const site = store.sites.find((candidate) => candidate.enabled && candidate.matchers.some((matcher) => matchesUrl(matcher, url)));
  if (!site) {
    style.textContent = "";
    return;
  }

  const categoryFilter = store.settings.enabledCategories;
  const enabledRules = site.rules.filter((rule) =>
    rule.enabled && (categoryFilter === null || categoryFilter.includes(rule.category))
  );
  if (enabledRules.length === 0) {
    style.textContent = "";
    return;
  }

  style.textContent = `[${AI_HIDDEN_ATTR}] { display: none !important; }`;
  for (const rule of enabledRules) {
    try {
      document.querySelectorAll(rule.selector).forEach((element) => {
        element.setAttribute(AI_HIDDEN_ATTR, "true");
      });
    } catch {
      /* skip invalid selector */
    }
  }
}
