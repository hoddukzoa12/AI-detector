import type { RuleProfile, RuleStore, StoredRule } from "./types.js";
import { hostnameFromUrl, hostnameMatcher } from "./storage-matchers.js";
import { emptyProfile, generateId, readStore, writeStore } from "./storage-migrate.js";
import { findMatchingProfile } from "./storage-queries.js";
import { appendRuleToStore, isSameStoredRule } from "../../packages/infocutter-selector-rules/src/index.js";

export async function ensureProfileForUrl(url: string): Promise<RuleProfile> {
  const store = await readStore();
  const existing = findMatchingProfile(store, url);
  if (existing) {
    return existing;
  }

  const matcher = hostnameMatcher(url);
  const profile: RuleProfile = {
    ...emptyProfile(),
    matchers: [matcher],
    name: hostnameFromUrl(url),
    updatedAt: new Date().toISOString()
  };

  store.profiles.push(profile);
  await writeStore(store);
  return profile;
}

export async function createProfile(name: string, matcher: string): Promise<RuleProfile> {
  const store = await readStore();
  const profile: RuleProfile = {
    ...emptyProfile(),
    matchers: matcher ? [matcher] : [],
    name: name.trim() || "새 프로필",
    updatedAt: new Date().toISOString()
  };

  store.profiles.push(profile);
  await writeStore(store);
  return profile;
}

export async function updateProfile(
  profileId: string,
  updater: (profile: RuleProfile) => RuleProfile
): Promise<RuleProfile | null> {
  const store = await readStore();
  const profile = store.profiles.find((item) => item.id === profileId);
  if (!profile) {
    return null;
  }

  const nextProfile = updater(profile);
  store.profiles = store.profiles.map((item) => (item.id === profileId ? nextProfile : item));
  await writeStore(store);
  return nextProfile;
}

export async function renameProfile(profileId: string, name: string): Promise<RuleProfile | null> {
  return updateProfile(profileId, (profile) => ({
    ...profile,
    name: name.trim() || profile.name,
    updatedAt: new Date().toISOString()
  }));
}

export async function upsertProfileFromTemplate(template: {
  slug: string;
  name: string;
  description?: string;
  matchers: string[];
  cards: {
    id: string;
    name: string;
    enabled?: boolean;
    rules: {
      frameScope: string | null;
      mode?: StoredRule["mode"];
      selector: string;
    }[];
  }[];
}): Promise<RuleProfile> {
  const store = await readStore();
  const existingProfile = store.profiles.find((profile) => profile.sourceTemplateSlug === template.slug) ?? null;
  const timestamp = new Date().toISOString();

  const cards = template.cards.map((card) => ({
    createdAt: timestamp,
    enabled: typeof card.enabled === "boolean" ? card.enabled : true,
    id: `tpl:${template.slug}:${card.id}`,
    name: card.name,
    updatedAt: timestamp
  }));

  const rules: StoredRule[] = template.cards.flatMap((card) => {
    const cardId = `tpl:${template.slug}:${card.id}`;
    return card.rules.map((rule) => ({
      cardId,
      cardName: card.name,
      createdAt: timestamp,
      frameScope: rule.frameScope,
      mode: rule.mode === "unhide" ? "unhide" : "hide",
      selector: rule.selector
    }));
  });

  const nextProfile: RuleProfile = {
    cards,
    enabled: true,
    id: existingProfile?.id ?? generateId(),
    matchers: template.matchers,
    name: template.name,
    rules,
    sourceTemplateSlug: template.slug,
    updatedAt: timestamp
  };

  if (existingProfile) {
    store.profiles = store.profiles.map((profile) => (
      profile.id === existingProfile.id ? nextProfile : profile
    ));
  } else {
    store.profiles.push(nextProfile);
  }

  await writeStore(store);
  return nextProfile;
}

export async function setProfileMatchers(profileId: string, matchers: string[]): Promise<RuleProfile | null> {
  const sanitizedMatchers = matchers
    .map((matcher) => matcher.trim())
    .filter((matcher) => matcher.length > 0);

  return updateProfile(profileId, (profile) => ({
    ...profile,
    matchers: sanitizedMatchers,
    updatedAt: new Date().toISOString()
  }));
}

export async function deleteProfile(profileId: string): Promise<void> {
  const store = await readStore();
  store.profiles = store.profiles.filter((profile) => profile.id !== profileId);
  await writeStore(store);
}

export async function moveProfile(profileId: string, direction: "up" | "down"): Promise<void> {
  const store = await readStore();
  const index = store.profiles.findIndex((profile) => profile.id === profileId);
  if (index < 0) {
    return;
  }

  const targetIndex = direction === "up" ? index - 1 : index + 1;
  if (targetIndex < 0 || targetIndex >= store.profiles.length) {
    return;
  }

  const nextProfiles = [...store.profiles];
  const [profile] = nextProfiles.splice(index, 1);
  if (!profile) {
    return;
  }
  nextProfiles.splice(targetIndex, 0, profile);
  store.profiles = nextProfiles;
  await writeStore(store);
}

export async function addRuleToUrl(url: string, selector: string, frameScope: string | null): Promise<RuleProfile> {
  return addCardToUrl(url, {
    cardId: generateId(),
    cardName: "기본 카드",
    createdAt: new Date().toISOString(),
    frameScope,
    mode: "hide",
    selector
  });
}

export async function addCardToUrl(url: string, rule: StoredRule): Promise<RuleProfile> {
  const store = await readStore();
  const current = findMatchingProfile(store, url) ?? (await ensureProfileForUrl(url));
  const refreshedStore = await readStore();
  const applied = appendRuleToStore(refreshedStore, current.id, current, {
    cardId: rule.cardId,
    cardName: rule.cardName,
    createdAt: rule.createdAt,
    frameScope: rule.frameScope,
    mode: rule.mode,
    selector: rule.selector
  });
  await writeStore(applied.store);
  return applied.profile;
}

export async function removeRuleFromProfile(
  profileId: string,
  targetRule: Pick<StoredRule, "cardId" | "createdAt" | "frameScope" | "mode" | "selector">
): Promise<RuleProfile | null> {
  return updateProfile(profileId, (profile) => {
    const remainingRules = profile.rules.filter((rule) => !isSameStoredRule(rule, targetRule));
    const remainingCardIds = new Set(remainingRules.map((rule) => rule.cardId));

    return {
      ...profile,
      cards: profile.cards.filter((card) => remainingCardIds.has(card.id)),
      rules: remainingRules,
      updatedAt: new Date().toISOString()
    };
  });
}

export async function renameCardInProfile(profileId: string, cardId: string, cardName: string): Promise<RuleProfile | null> {
  const nextName = cardName.trim();
  if (!nextName) {
    return null;
  }

  return updateProfile(profileId, (profile) => ({
    ...profile,
    cards: profile.cards.map((card) => (
      card.id === cardId
        ? {
            ...card,
            name: nextName,
            updatedAt: new Date().toISOString()
          }
        : card
    )),
    rules: profile.rules.map((rule) => (
      rule.cardId === cardId
        ? {
            ...rule,
            cardName: nextName
          }
        : rule
    )),
    updatedAt: new Date().toISOString()
  }));
}

export async function removeCardFromProfile(profileId: string, cardId: string): Promise<RuleProfile | null> {
  return updateProfile(profileId, (profile) => ({
    ...profile,
    cards: profile.cards.filter((card) => card.id !== cardId),
    rules: profile.rules.filter((rule) => rule.cardId !== cardId),
    updatedAt: new Date().toISOString()
  }));
}

export async function clearProfileRules(profileId: string): Promise<RuleProfile | null> {
  return updateProfile(profileId, (profile) => ({
    ...profile,
    cards: [],
    rules: [],
    updatedAt: new Date().toISOString()
  }));
}

export async function setProfileEnabled(profileId: string, enabled: boolean): Promise<RuleProfile | null> {
  return updateProfile(profileId, (profile) => ({
    ...profile,
    enabled,
    updatedAt: new Date().toISOString()
  }));
}

export async function setCardEnabled(profileId: string, cardId: string, enabled: boolean): Promise<RuleProfile | null> {
  return updateProfile(profileId, (profile) => ({
    ...profile,
    cards: profile.cards.map((card) => (
      card.id === cardId
        ? {
            ...card,
            enabled,
            updatedAt: new Date().toISOString()
          }
        : card
    )),
    updatedAt: new Date().toISOString()
  }));
}

export async function setGlobalEnabled(globalEnabled: boolean): Promise<RuleStore> {
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
