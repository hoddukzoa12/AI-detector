/* eslint-disable @typescript-eslint/no-unused-vars */

function createProfileCard(
  cardId = generateId(),
  cardName = "기본 카드",
  createdAt = new Date(0).toISOString()
): ProfileCardRecord {
  return InfocutterSelectorRules.createProfileCard(cardId, cardName, createdAt);
}

function isSameStoredRule(
  rule: Pick<StoredSiteRule, "cardId" | "createdAt" | "frameScope" | "mode" | "selector">,
  targetRule: Pick<StoredSiteRule, "cardId" | "createdAt" | "frameScope" | "mode" | "selector">
): boolean {
  return InfocutterSelectorRules.isSameStoredRule(rule, targetRule);
}

function groupRulesByCard(
  rules: StoredSiteRule[],
  profileCards: ProfileCardRecord[] = []
): SavedCardState[] {
  return InfocutterSelectorRules.groupRulesByCard(rules, profileCards);
}

function emptySiteRuleSet(): SiteRuleSet {
  return InfocutterSelectorRules.emptyRuleProfile(generateId);
}

function emptyStore(): RuleStore {
  return InfocutterSelectorRules.emptyRuleStore();
}

function normalizeSiteRuleSet(rawSiteRules: unknown): SiteRuleSet {
  return InfocutterSelectorRules.normalizeRuleProfile(rawSiteRules, generateId) ?? emptySiteRuleSet();
}

function normalizeStore(candidate: unknown): RuleStore {
  return InfocutterSelectorRules.normalizeRuleStore(candidate, generateId);
}

async function readStore(): Promise<RuleStore> {
  const result = await chrome.storage.local.get(STORAGE_KEY);
  const candidate: unknown = result[STORAGE_KEY];
  return normalizeStore(candidate);
}

async function writeStore(store: RuleStore): Promise<void> {
  await chrome.storage.local.set({
    [STORAGE_KEY]: store
  });
}

function findMatchingProfile(store: RuleStore, url: string): SiteRuleSet | null {
  return InfocutterSelectorRules.findMatchingRuleProfile(store, url);
}

async function ensureProfileForUrl(url: string): Promise<SiteRuleSet> {
  const store = await readStore();
  const existing = findMatchingProfile(store, url);
  if (existing) {
    return existing;
  }

  const profile: SiteRuleSet = {
    ...emptySiteRuleSet(),
    matchers: [hostnameMatcher(url)],
    name: hostnameFromUrl(url),
    updatedAt: new Date().toISOString()
  };

  store.profiles.push(profile);
  await writeStore(store);
  return profile;
}

async function addSiteRule(
  url: string,
  selector: string,
  frameScope: string | null,
  card: { cardId: string; cardName: string }
): Promise<SiteRuleSet> {
  const store = await readStore();
  const current = findMatchingProfile(store, url) ?? (await ensureProfileForUrl(url));
  const refreshedStore = await readStore();
  const applied = InfocutterSelectorRules.appendRuleToStore(refreshedStore, current.id, current, {
    cardId: card.cardId,
    cardName: card.cardName,
    createdAt: new Date().toISOString(),
    frameScope,
    mode: "hide",
    selector
  });
  await writeStore(applied.store);
  return applied.profile;
}

async function mutateSiteProfile(
  profileId: string,
  transform: (profile: SiteRuleSet) => SiteRuleSet
): Promise<SiteRuleSet | null> {
  const store = await readStore();
  const current = store.profiles.find((item) => item.id === profileId);
  if (!current) {
    return null;
  }

  const next = transform(current);
  store.profiles = store.profiles.map((item) => (item.id === profileId ? next : item));
  await writeStore(store);
  return next;
}

async function removeSiteRule(
  profileId: string,
  targetRule: Pick<StoredSiteRule, "cardId" | "createdAt" | "frameScope" | "mode" | "selector">
): Promise<SiteRuleSet | null> {
  return mutateSiteProfile(profileId, (current) => {
    const remainingRules = current.rules.filter((rule) => !isSameStoredRule(rule, targetRule));
    const remainingCardIds = new Set(remainingRules.map((rule) => rule.cardId));
    return {
      ...current,
      cards: current.cards.filter((card) => remainingCardIds.has(card.id)),
      rules: remainingRules,
      updatedAt: new Date().toISOString()
    };
  });
}

async function clearSiteRules(profileId: string): Promise<SiteRuleSet | null> {
  return mutateSiteProfile(profileId, (current) => ({
    ...current,
    cards: [],
    rules: [],
    updatedAt: new Date().toISOString()
  }));
}

async function setSiteEnabled(profileId: string, enabled: boolean): Promise<SiteRuleSet | null> {
  return mutateSiteProfile(profileId, (current) => ({
    ...current,
    enabled,
    updatedAt: new Date().toISOString()
  }));
}

async function setGlobalEnabled(globalEnabled: boolean): Promise<RuleStore> {
  const store = await readStore();
  const next: RuleStore = {
    ...store,
    settings: {
      globalEnabled
    }
  };

  await writeStore(next);
  return next;
}

async function readActiveSiteState(url: string): Promise<ActiveSiteState> {
  const store = await readStore();
  return InfocutterSelectorRules.buildActiveSiteState(store, url);
}
