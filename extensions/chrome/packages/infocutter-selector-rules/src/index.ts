export const SELECTOR_RULE_STORE_VERSION = 4;
export const STABLE_SELECTOR_ATTRIBUTES = ["data-testid", "data-test", "data-qa", "aria-label", "title", "alt"] as const;
export const MAX_SELECTOR_DEPTH = 4;
const URL_MATCHER_PATTERN = /^(?<scheme>\*|https?|http):\/\/(?<host>[^/*:]+)(?<port>:\d+)?(?<path>\/.*)$/;

export type RuleMode = "hide" | "unhide";

export type StoredRule = {
  cardId: string;
  cardName: string;
  createdAt: string;
  frameScope: string | null;
  mode: RuleMode;
  selector: string;
};

export type ProfileCard = {
  createdAt: string;
  enabled: boolean;
  id: string;
  name: string;
  updatedAt: string;
};

export type SavedCard = {
  cardId: string;
  cardName: string;
  createdAt: string;
  enabled: boolean;
  frameScopes: (string | null)[];
  mode: RuleMode;
  ruleCount: number;
  rules: StoredRule[];
};

export type RuleProfile = {
  cards: ProfileCard[];
  enabled: boolean;
  id: string;
  matchers: string[];
  name: string;
  rules: StoredRule[];
  sourceTemplateSlug: string | null;
  updatedAt: string;
};

export type RuleStore = {
  version: typeof SELECTOR_RULE_STORE_VERSION;
  settings: {
    globalEnabled: boolean;
  };
  profiles: RuleProfile[];
};

export type ActiveSiteState = {
  activeProfileId: string | null;
  activeProfileName: string | null;
  cardCount: number;
  cards: SavedCard[];
  enabledExceptionCount: number;
  enabledSelectorCount: number;
  exceptionCount: number;
  globalEnabled: boolean;
  hostname: string;
  matchers: string[];
  profileEnabled: boolean;
  rules: StoredRule[];
  selectorCount: number;
  updatedAt: string;
  url: string;
};

function fallbackId(): string {
  return `ic-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

export function generateSelectorRuleId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  return fallbackId();
}

export function createProfileCard(
  cardId = generateSelectorRuleId(),
  cardName = "기본 카드",
  createdAt = new Date(0).toISOString()
): ProfileCard {
  return {
    createdAt,
    enabled: true,
    id: cardId,
    name: cardName,
    updatedAt: createdAt
  };
}

export function emptyRuleProfile(generateId = generateSelectorRuleId): RuleProfile {
  return {
    cards: [],
    enabled: true,
    id: generateId(),
    matchers: [],
    name: "새 프로필",
    rules: [],
    sourceTemplateSlug: null,
    updatedAt: new Date(0).toISOString()
  };
}

export function emptyRuleStore(): RuleStore {
  return {
    version: SELECTOR_RULE_STORE_VERSION,
    settings: {
      globalEnabled: true
    },
    profiles: []
  };
}

export function profileNameFromMatcher(matcher: string): string {
  return matcher.replace(/^\*?:?\/\//, "").replace(/\/\*$/, "");
}

export function hostnameMatcher(url: string): string {
  const parsed = new URL(url);
  return `${parsed.origin}/*`;
}

export function hostnameFromUrl(url: string): string {
  return new URL(url).hostname.toLowerCase();
}

export function matcherToRegExp(matcher: string): RegExp {
  const urlMatcher = URL_MATCHER_PATTERN.exec(matcher);
  if (urlMatcher?.groups) {
    const scheme = urlMatcher.groups.scheme;
    const host = urlMatcher.groups.host;
    const path = urlMatcher.groups.path;
    if (!scheme || !host || !path) {
      const escaped = matcher.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
      return new RegExp(`^${escaped}$`);
    }

    const schemePattern = scheme === "*" ? "https?" : scheme.replace(/[.+?^${}()|[\]\\]/g, "\\$&");
    const hostPattern = host.replace(/[.+?^${}()|[\]\\]/g, "\\$&");
    const portPattern = urlMatcher.groups.port
      ? urlMatcher.groups.port.replace(/[.+?^${}()|[\]\\]/g, "\\$&")
      : "(?::\\d+)?";
    const pathPattern = path.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
    return new RegExp(`^${schemePattern}:\\/\\/${hostPattern}${portPattern}${pathPattern}$`);
  }

  const escaped = matcher.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp(`^${escaped}$`);
}

export function matchesUrl(matcher: string, url: string): boolean {
  return matcherToRegExp(matcher).test(url);
}

export function normalizeStoredRule(rule: unknown, generateId = generateSelectorRuleId): StoredRule | null {
  if (typeof rule === "string") {
    return {
      cardId: generateId(),
      cardName: "기본 카드",
      createdAt: new Date(0).toISOString(),
      frameScope: null,
      mode: "hide",
      selector: rule
    };
  }

  if (!rule || typeof rule !== "object") {
    return null;
  }

  const candidate = rule as Partial<StoredRule>;
  if (typeof candidate.selector !== "string") {
    return null;
  }

  return {
    cardId: typeof candidate.cardId === "string" ? candidate.cardId : generateId(),
    cardName: typeof candidate.cardName === "string" && candidate.cardName.length > 0 ? candidate.cardName : "기본 카드",
    createdAt: typeof candidate.createdAt === "string" ? candidate.createdAt : new Date(0).toISOString(),
    frameScope: typeof candidate.frameScope === "string" ? candidate.frameScope : null,
    mode: candidate.mode === "unhide" ? "unhide" : "hide",
    selector: candidate.selector
  };
}

export function normalizeProfileCard(rawCard: unknown, generateId = generateSelectorRuleId): ProfileCard | null {
  if (!rawCard || typeof rawCard !== "object") {
    return null;
  }

  const createdAtValue: unknown = Reflect.get(rawCard, "createdAt");
  const enabledValue: unknown = Reflect.get(rawCard, "enabled");
  const idValue: unknown = Reflect.get(rawCard, "id");
  const nameValue: unknown = Reflect.get(rawCard, "name");
  const updatedAtValue: unknown = Reflect.get(rawCard, "updatedAt");
  const createdAt = typeof createdAtValue === "string" ? createdAtValue : new Date(0).toISOString();

  return {
    createdAt,
    enabled: typeof enabledValue === "boolean" ? enabledValue : true,
    id: typeof idValue === "string" && idValue.length > 0 ? idValue : generateId(),
    name: typeof nameValue === "string" && nameValue.length > 0 ? nameValue : "기본 카드",
    updatedAt: typeof updatedAtValue === "string" ? updatedAtValue : createdAt
  };
}

export function deriveCardsFromRules(rules: StoredRule[]): ProfileCard[] {
  const cards = new Map<string, ProfileCard>();

  for (const rule of rules) {
    if (cards.has(rule.cardId)) {
      continue;
    }

    cards.set(rule.cardId, createProfileCard(rule.cardId, rule.cardName, rule.createdAt));
  }

  return Array.from(cards.values()).sort((left, right) => left.createdAt.localeCompare(right.createdAt));
}

export function reconcileProfileCards(
  rules: StoredRule[],
  cards: ProfileCard[]
): { cards: ProfileCard[]; rules: StoredRule[] } {
  const cardMap = new Map(cards.map((card) => [card.id, card]));
  const nextRules = rules.map((rule) => {
    const card = cardMap.get(rule.cardId);
    if (card) {
      return {
        ...rule,
        cardName: card.name
      };
    }

    const fallbackCard = createProfileCard(rule.cardId, rule.cardName, rule.createdAt);
    cardMap.set(fallbackCard.id, fallbackCard);
    return {
      ...rule,
      cardName: fallbackCard.name
    };
  });

  return {
    cards: Array.from(cardMap.values()).sort((left, right) => left.createdAt.localeCompare(right.createdAt)),
    rules: nextRules
  };
}

export function normalizeRuleProfile(rawProfile: unknown, generateId = generateSelectorRuleId): RuleProfile | null {
  if (!rawProfile || typeof rawProfile !== "object") {
    return null;
  }

  const cardsValue: unknown = Reflect.get(rawProfile, "cards");
  const enabledValue: unknown = Reflect.get(rawProfile, "enabled");
  const idValue: unknown = Reflect.get(rawProfile, "id");
  const matchersValue: unknown = Reflect.get(rawProfile, "matchers");
  const nameValue: unknown = Reflect.get(rawProfile, "name");
  const rulesValue: unknown = Reflect.get(rawProfile, "rules");
  const sourceTemplateSlugValue: unknown = Reflect.get(rawProfile, "sourceTemplateSlug");
  const updatedAtValue: unknown = Reflect.get(rawProfile, "updatedAt");

  const rules = Array.isArray(rulesValue)
    ? rulesValue.map((rule) => normalizeStoredRule(rule, generateId)).filter((rule): rule is StoredRule => rule !== null)
    : [];
  const rawCards = Array.isArray(cardsValue)
    ? cardsValue.map((card) => normalizeProfileCard(card, generateId)).filter((card): card is ProfileCard => card !== null)
    : deriveCardsFromRules(rules);
  const reconciled = reconcileProfileCards(rules, rawCards);

  const matchers = Array.isArray(matchersValue)
    ? matchersValue.filter((matcher): matcher is string => typeof matcher === "string" && matcher.length > 0)
    : [];

  return {
    cards: reconciled.cards,
    enabled: typeof enabledValue === "boolean" ? enabledValue : true,
    id: typeof idValue === "string" && idValue.length > 0 ? idValue : generateId(),
    matchers,
    name: typeof nameValue === "string" && nameValue.length > 0
      ? nameValue
      : matchers[0]
        ? profileNameFromMatcher(matchers[0])
        : "이름 없는 프로필",
    rules: reconciled.rules,
    sourceTemplateSlug: typeof sourceTemplateSlugValue === "string" && sourceTemplateSlugValue.length > 0
      ? sourceTemplateSlugValue
      : null,
    updatedAt: typeof updatedAtValue === "string" ? updatedAtValue : new Date(0).toISOString()
  };
}

export function normalizeLegacySiteRules(hostname: string, rawSiteRules: unknown, generateId = generateSelectorRuleId): RuleProfile {
  const enabledValue: unknown = rawSiteRules && typeof rawSiteRules === "object" ? Reflect.get(rawSiteRules, "enabled") : undefined;
  const rulesValue: unknown = rawSiteRules && typeof rawSiteRules === "object" ? Reflect.get(rawSiteRules, "rules") : undefined;
  const selectorsValue: unknown = rawSiteRules && typeof rawSiteRules === "object" ? Reflect.get(rawSiteRules, "selectors") : undefined;
  const updatedAtValue: unknown = rawSiteRules && typeof rawSiteRules === "object" ? Reflect.get(rawSiteRules, "updatedAt") : undefined;

  const rawRules: unknown[] = Array.isArray(rulesValue)
    ? rulesValue
    : Array.isArray(selectorsValue)
      ? selectorsValue
      : [];

  const rules = rawRules.map((rule) => normalizeStoredRule(rule, generateId)).filter((rule): rule is StoredRule => rule !== null);
  const matcher = `https://${hostname}/*`;

  return {
    cards: deriveCardsFromRules(rules),
    enabled: typeof enabledValue === "boolean" ? enabledValue : true,
    id: generateId(),
    matchers: [matcher],
    name: hostname,
    rules,
    sourceTemplateSlug: null,
    updatedAt: typeof updatedAtValue === "string" ? updatedAtValue : new Date(0).toISOString()
  };
}

export function normalizeRuleStore(candidate: unknown, generateId = generateSelectorRuleId): RuleStore {
  if (!candidate || typeof candidate !== "object") {
    return emptyRuleStore();
  }

  const versionValue: unknown = Reflect.get(candidate, "version");
  const settingsValue: unknown = Reflect.get(candidate, "settings");
  const profilesValue: unknown = Reflect.get(candidate, "profiles");
  const sitesValue: unknown = Reflect.get(candidate, "sites");

  const globalEnabled =
    settingsValue &&
    typeof settingsValue === "object" &&
    "globalEnabled" in settingsValue &&
    typeof settingsValue.globalEnabled === "boolean"
      ? settingsValue.globalEnabled
      : true;

  if (versionValue === SELECTOR_RULE_STORE_VERSION || versionValue === 3) {
    const profiles = Array.isArray(profilesValue)
      ? profilesValue.map((profile) => normalizeRuleProfile(profile, generateId)).filter((profile): profile is RuleProfile => profile !== null)
      : [];

    return {
      version: SELECTOR_RULE_STORE_VERSION,
      settings: {
        globalEnabled
      },
      profiles
    };
  }

  if (versionValue === 2 || versionValue === 1) {
    const rawSites = sitesValue && typeof sitesValue === "object"
      ? (sitesValue as Record<string, unknown>)
      : {};
    const profiles = Object.entries(rawSites).map(([hostname, rawSiteRules]) => normalizeLegacySiteRules(hostname, rawSiteRules, generateId));

    return {
      version: SELECTOR_RULE_STORE_VERSION,
      settings: {
        globalEnabled
      },
      profiles
    };
  }

  return emptyRuleStore();
}

export function groupRulesByCard(rules: StoredRule[], profileCards: ProfileCard[] = []): SavedCard[] {
  const cards = new Map<string, SavedCard>();

  for (const profileCard of profileCards) {
    cards.set(profileCard.id, {
      cardId: profileCard.id,
      cardName: profileCard.name,
      createdAt: profileCard.createdAt,
      enabled: profileCard.enabled,
      frameScopes: [],
      mode: "hide",
      ruleCount: 0,
      rules: []
    });
  }

  for (const rule of rules) {
    const current = cards.get(rule.cardId);
    if (current) {
      current.rules.push(rule);
      current.ruleCount += 1;
      current.cardName = rule.cardName;
      current.mode = rule.mode;
      if (!current.frameScopes.includes(rule.frameScope)) {
        current.frameScopes.push(rule.frameScope);
      }
      continue;
    }

    cards.set(rule.cardId, {
      cardId: rule.cardId,
      cardName: rule.cardName,
      createdAt: rule.createdAt,
      enabled: true,
      frameScopes: [rule.frameScope],
      mode: rule.mode,
      ruleCount: 1,
      rules: [rule]
    });
  }

  return Array.from(cards.values()).sort((left, right) => left.createdAt.localeCompare(right.createdAt));
}

export function getEnabledRules(profile: RuleProfile | null, mode?: RuleMode): StoredRule[] {
  if (!profile) {
    return [];
  }

  const enabledCardIds = new Set(
    profile.cards
      .filter((card) => card.enabled)
      .map((card) => card.id)
  );

  return profile.rules.filter((rule) => (
    enabledCardIds.has(rule.cardId) &&
    (mode === undefined || rule.mode === mode)
  ));
}

export function preferredExactSegmentSelector(
  element: Element,
  specificityScore: (selector: string) => number
): string {
  const candidates = simpleSelectorCandidates(element, { allowNth: false })
    .filter((candidate) => !isBareTagSelector(candidate))
    .sort((left, right) => specificityScore(right) - specificityScore(left));

  for (const candidate of candidates) {
    if (isUniqueAmongSiblings(element, candidate)) {
      return candidate;
    }
  }

  return nthOfTypeSelector(element);
}

export function buildForcedUniqueSelector(
  element: Element,
  specificityScore: (selector: string) => number,
  root: Document = document
): string {
  const segments: string[] = [];
  let current: Element | null = element;

  while (current && current !== document.documentElement) {
    segments.unshift(preferredExactSegmentSelector(current, specificityScore));
    const selector = segments.join(" > ");
    if (isUniqueSelector(selector, root)) {
      return selector;
    }
    current = current.parentElement;
  }

  return segments.join(" > ");
}

export function findMatchingRuleProfile(store: RuleStore, url: string): RuleProfile | null {
  return store.profiles.find((profile) => profile.matchers.some((matcher) => matchesUrl(matcher, url))) ?? null;
}

export function appendRuleToStore(
  refreshedStore: RuleStore,
  currentProfileId: string,
  fallbackProfile: RuleProfile,
  ruleInput: {
    cardId: string;
    cardName: string;
    createdAt: string;
    frameScope: string | null;
    mode: RuleMode;
    selector: string;
  }
): { profile: RuleProfile; store: RuleStore } {
  const profile = refreshedStore.profiles.find((item) => item.id === currentProfileId) ?? fallbackProfile;
  const rule = buildStoredRule({
    ...ruleInput,
    cardName: profile.cards.find((card) => card.id === ruleInput.cardId)?.name ?? ruleInput.cardName
  });
  const nextProfile = upsertRuleIntoProfile(profile, rule);
  return {
    profile: nextProfile,
    store: {
      ...refreshedStore,
      profiles: refreshedStore.profiles.map((item) => (item.id === profile.id ? nextProfile : item))
    }
  };
}

export function upsertRuleIntoProfile(profile: RuleProfile, rule: StoredRule): RuleProfile {
  const existingCard = profile.cards.find((card) => card.id === rule.cardId);
  return {
    ...profile,
    cards: existingCard
      ? profile.cards
      : [...profile.cards, createProfileCard(rule.cardId, rule.cardName, rule.createdAt)],
    enabled: true,
    rules: profileContainsRule(profile.rules, rule)
      ? profile.rules
      : [...profile.rules, rule],
    updatedAt: new Date().toISOString()
  };
}

export function buildStoredRule(input: {
  cardId: string;
  cardName: string;
  createdAt: string;
  frameScope: string | null;
  mode: RuleMode;
  selector: string;
}): StoredRule {
  return {
    cardId: input.cardId,
    cardName: input.cardName,
    createdAt: input.createdAt,
    frameScope: input.frameScope,
    mode: input.mode,
    selector: input.selector
  };
}

export function profileContainsRule(
  rules: StoredRule[],
  candidate: Pick<StoredRule, "cardId" | "frameScope" | "mode" | "selector">
): boolean {
  return rules.some((rule) => (
    rule.selector === candidate.selector &&
    rule.frameScope === candidate.frameScope &&
    rule.mode === candidate.mode &&
    rule.cardId === candidate.cardId
  ));
}

export function isSameStoredRule(
  rule: Pick<StoredRule, "cardId" | "createdAt" | "frameScope" | "mode" | "selector">,
  targetRule: Pick<StoredRule, "cardId" | "createdAt" | "frameScope" | "mode" | "selector">
): boolean {
  return (
    rule.cardId === targetRule.cardId &&
    rule.createdAt === targetRule.createdAt &&
    rule.frameScope === targetRule.frameScope &&
    rule.mode === targetRule.mode &&
    rule.selector === targetRule.selector
  );
}

export function buildActiveSiteState(store: RuleStore, url: string): ActiveSiteState {
  const profile = findMatchingRuleProfile(store, url);
  const rules = profile?.rules ? [...profile.rules] : [];
  const cards = groupRulesByCard(rules, profile?.cards ?? []);
  const enabledRules = getEnabledRules(profile, "hide");
  const enabledExceptions = getEnabledRules(profile, "unhide");

  return {
    activeProfileId: profile?.id ?? null,
    activeProfileName: profile?.name ?? null,
    cardCount: cards.length,
    cards,
    enabledExceptionCount: enabledExceptions.length,
    enabledSelectorCount: enabledRules.length,
    exceptionCount: rules.filter((rule) => rule.mode === "unhide").length,
    globalEnabled: store.settings.globalEnabled,
    hostname: hostnameFromUrl(url),
    matchers: profile?.matchers ?? [],
    profileEnabled: profile?.enabled ?? true,
    rules,
    selectorCount: rules.length,
    updatedAt: profile?.updatedAt ?? new Date(0).toISOString(),
    url
  };
}

export const infocutterMessageTypes = {
  ensureTabReady: "infocutter/ensure-tab-ready",
  getPickerFocus: "infocutter/get-picker-focus",
  ping: "infocutter/ping",
  getPageState: "infocutter/get-page-state",
  getTextBlockState: "infocutter/get-text-block-state",
  getTextBlockDiagnostics: "infocutter/get-text-block-diagnostics",
  applyNetworkRules: "infocutter/apply-network-rules",
  runDiagnostics: "infocutter/run-diagnostics",
  stopPicker: "infocutter/stop-picker",
  startPickerFlow: "infocutter/start-picker-flow",
  startPicker: "infocutter/start-picker",
  updatePickerFocus: "infocutter/update-picker-focus",
  hideLastContextTarget: "infocutter/hide-last-context-target",
  clearSiteRules: "infocutter/clear-site-rules",
  removeSiteRule: "infocutter/remove-site-rule",
  toggleSiteEnabled: "infocutter/toggle-site-enabled",
  toggleGlobalEnabled: "infocutter/toggle-global-enabled",
  togglePeek: "infocutter/toggle-peek",
  toggleTextBlockProfileEnabled: "infocutter/toggle-text-block-profile-enabled",
  toggleTextBlockGlobalEnabled: "infocutter/toggle-text-block-global-enabled",
  captureEvidence: "infocutter/capture-evidence",
  toggleWatchGlobalEnabled: "infocutter/toggle-watch-global-enabled",
  collectAiBlocks: "infocutter/collect-ai-blocks",
  analyzePageAi: "infocutter/analyze-page-ai"
} as const;

export type InfocutterMessageType = (typeof infocutterMessageTypes)[keyof typeof infocutterMessageTypes];

export function readBooleanSetting(settingsValue: unknown, key: string, fallback: boolean): boolean {
  if (
    settingsValue &&
    typeof settingsValue === "object" &&
    key in settingsValue &&
    typeof (settingsValue as Record<string, unknown>)[key] === "boolean"
  ) {
    return (settingsValue as Record<string, unknown>)[key] as boolean;
  }

  return fallback;
}

export function frameScopeLabel(frameScope: string | null): string {
  if (!frameScope) {
    return "메인 문서 규칙";
  }

  try {
    const url = new URL(frameScope);
    return `iframe 규칙: ${url.hostname}${url.pathname}`;
  } catch {
    return `iframe 규칙: ${frameScope}`;
  }
}

export function selectorCss(selectors: string[]): string {
  return selectors.map((selector) => `${selector} { display: none !important; }`).join("\n");
}

export function escapeSelector(value: string): string {
  return CSS.escape(value);
}

export function isUniqueSelector(selector: string, root: Document = document): boolean {
  return root.querySelectorAll(selector).length === 1;
}

export function maybeStableClassName(className: string): boolean {
  if (!/^[a-z][a-z0-9_-]{1,40}$/i.test(className)) {
    return false;
  }

  const digitCount = className.replace(/\D/g, "").length;
  return digitCount <= 3;
}

export function stableClasses(element: Element): string[] {
  return Array.from(element.classList).filter(maybeStableClassName).slice(0, 3);
}

export function attributeSelectors(element: Element): string[] {
  const selectors: string[] = [];

  for (const attribute of STABLE_SELECTOR_ATTRIBUTES) {
    const value = element.getAttribute(attribute);
    if (value && value.length <= 80) {
      selectors.push(`${element.localName}[${attribute}="${escapeSelector(value)}"]`);
      selectors.push(`[${attribute}="${escapeSelector(value)}"]`);
    }
  }

  return selectors;
}

export function classSelectors(element: Element): string[] {
  const classes = stableClasses(element);
  const selectors: string[] = [];

  for (let size = 1; size <= classes.length; size += 1) {
    const joined = classes.slice(0, size).map((className) => `.${escapeSelector(className)}`).join("");
    selectors.push(`${element.localName}${joined}`);
    selectors.push(joined);
  }

  return selectors;
}

export function nthOfTypeSelector(element: Element): string {
  const parent = element.parentElement;
  if (!parent) {
    return element.localName;
  }

  const siblings = Array.from(parent.children).filter((child) => child.localName === element.localName);
  const index = siblings.indexOf(element) + 1;
  return `${element.localName}:nth-of-type(${index})`;
}

export function isBareTagSelector(selector: string): boolean {
  return /^[a-z][a-z0-9-]*$/i.test(selector);
}

export function simpleSelectorCandidates(element: Element, options?: { allowNth?: boolean }): string[] {
  const selectors: string[] = [];
  const id = element.getAttribute("id");

  if (id) {
    selectors.push(`#${escapeSelector(id)}`);
    selectors.push(`${element.localName}#${escapeSelector(id)}`);
  }

  selectors.push(...attributeSelectors(element));
  selectors.push(...classSelectors(element));
  selectors.push(element.localName);

  if (options?.allowNth) {
    selectors.push(nthOfTypeSelector(element));
  }

  return Array.from(new Set(selectors));
}

export function isUniqueAmongSiblings(element: Element, segment: string): boolean {
  const parent = element.parentElement;
  if (!parent) {
    return true;
  }

  try {
    return parent.querySelectorAll(`:scope > ${segment}`).length === 1;
  } catch {
    return false;
  }
}
