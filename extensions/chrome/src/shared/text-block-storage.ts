import {
  buildActiveTextBlockState,
  createTextBlockRule,
  emptyTextBlockProfile,
  findMatchingTextBlockProfile as findMatchingTextBlockProfileForUrl,
  normalizeObjectTags,
  normalizeTextBlockStore,
  parseObjectTags,
  updateHiddenObjectTags
} from "../../packages/infocutter-text-blocks/src/index.js";
import type { ActiveTextBlockState, TextBlockProfile, TextBlockStore } from "../../packages/infocutter-text-blocks/src/index.js";
import { TEXT_BLOCK_STORAGE_KEY } from "./constants.js";
import { matchesUrl } from "./storage.js";

export { normalizeTextBlockStore };

export async function readTextBlockStore(): Promise<TextBlockStore> {
  const result = await chrome.storage.local.get(TEXT_BLOCK_STORAGE_KEY);
  return normalizeTextBlockStore(result[TEXT_BLOCK_STORAGE_KEY]);
}

export async function writeTextBlockStore(store: TextBlockStore): Promise<void> {
  await chrome.storage.local.set({
    [TEXT_BLOCK_STORAGE_KEY]: store
  });
}

export function findMatchingTextBlockProfile(store: TextBlockStore, url: string): TextBlockProfile | null {
  return findMatchingTextBlockProfileForUrl(store, url, matchesUrl);
}

async function mutateTextBlockProfile(
  profileId: string,
  transform: (profile: TextBlockProfile) => TextBlockProfile | null
): Promise<TextBlockProfile | null> {
  const store = await readTextBlockStore();
  const profile = store.profiles.find((item) => item.id === profileId);
  if (!profile) {
    return null;
  }

  const nextProfile = transform(profile);
  if (!nextProfile) {
    return null;
  }

  store.profiles = store.profiles.map((item) => item.id === profile.id ? nextProfile : item);
  await writeTextBlockStore(store);
  return nextProfile;
}

function mapProfileRule(
  profile: TextBlockProfile,
  predicate: (rule: TextBlockProfile["rules"][number]) => boolean,
  patch: (rule: TextBlockProfile["rules"][number]) => TextBlockProfile["rules"][number],
  timestamp: string = new Date().toISOString()
): TextBlockProfile {
  return {
    ...profile,
    rules: profile.rules.map((rule) => predicate(rule) ? patch(rule) : rule),
    updatedAt: timestamp
  };
}

export async function upsertTextBlockProfileRule(input: {
  keyword: string;
  matcher: string;
  minMatchCount: number;
  objectName?: string;
  objectTags?: string[];
  profileName: string;
}): Promise<TextBlockProfile> {
  const store = await readTextBlockStore();
  const matcher = input.matcher.trim();
  const profileName = input.profileName.trim() || matcher;
  const keyword = input.keyword.trim();

  if (!matcher || !keyword) {
    throw new Error("텍스트 규칙 matcher와 keyword는 비워둘 수 없습니다.");
  }

  const existingProfile = store.profiles.find((profile) => profile.matchers.includes(matcher)) ?? null;
  const nextRuleInput = {
    keyword,
    minMatchCount: input.minMatchCount
  };
  const nextRule = createTextBlockRule({
    ...nextRuleInput,
    ...(input.objectName !== undefined ? { objectName: input.objectName } : {}),
    ...(input.objectTags !== undefined ? { objectTags: input.objectTags } : {})
  });
  const timestamp = new Date().toISOString();

  const nextProfile: TextBlockProfile = existingProfile
    ? {
        ...existingProfile,
        enabled: true,
        name: profileName || existingProfile.name,
        rules: existingProfile.rules.some((rule) => rule.keyword === keyword)
          ? existingProfile.rules.map((rule) => (
              rule.keyword === keyword
                ? {
                    ...rule,
                    fingerprint: rule.fingerprint,
                    minMatchCount: nextRule.minMatchCount,
                    objectName: nextRule.objectName || rule.objectName,
                    objectTags: rule.objectTags,
                    updatedAt: timestamp
                  }
                : rule
            ))
          : [...existingProfile.rules, nextRule],
        updatedAt: timestamp
      }
    : {
        ...emptyTextBlockProfile(),
        enabled: true,
        matchers: [matcher],
        name: profileName,
        rules: [nextRule],
        updatedAt: timestamp
      };

  if (existingProfile) {
    store.profiles = store.profiles.map((profile) => profile.id === existingProfile.id ? nextProfile : profile);
  } else {
    store.profiles.push(nextProfile);
  }

  await writeTextBlockStore(store);
  return nextProfile;
}

export async function renameTextBlockProfile(profileId: string, name: string): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => ({
    ...profile,
    name: name.trim() || profile.name,
    updatedAt: new Date().toISOString()
  }));
}

export async function setTextBlockProfileMatchers(profileId: string, matchers: string[]): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => ({
    ...profile,
    matchers: matchers.map((matcher) => matcher.trim()).filter((matcher) => matcher.length > 0),
    updatedAt: new Date().toISOString()
  }));
}

export async function deleteTextBlockProfile(profileId: string): Promise<void> {
  const store = await readTextBlockStore();
  store.profiles = store.profiles.filter((profile) => profile.id !== profileId);
  await writeTextBlockStore(store);
}

export async function removeTextBlockRule(profileId: string, ruleId: string): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => ({
    ...profile,
    rules: profile.rules.filter((rule) => rule.id !== ruleId),
    updatedAt: new Date().toISOString()
  }));
}

export async function removeTextBlockObject(profileId: string, objectId: string): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => ({
    ...profile,
    rules: profile.rules.filter((rule) => rule.objectId !== objectId),
    updatedAt: new Date().toISOString()
  }));
}

export async function addTextBlockObjectCondition(
  profileId: string,
  objectId: string,
  input: {
    keyword: string;
    minMatchCount: number;
  }
): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => {
    const objectRules = profile.rules.filter((rule) => rule.objectId === objectId);
    const firstRule = objectRules[0];
    if (!firstRule) {
      return null;
    }

    const keyword = input.keyword.trim();
    if (!keyword) {
      return null;
    }

    const nextRule = createTextBlockRule({
      fingerprint: firstRule.fingerprint,
      keyword,
      minMatchCount: input.minMatchCount,
      objectId,
      objectName: firstRule.objectName,
      objectTags: firstRule.objectTags
    });
    return {
      ...profile,
      rules: [...profile.rules, nextRule],
      updatedAt: new Date().toISOString()
    };
  });
}

export async function updateTextBlockRule(
  profileId: string,
  ruleId: string,
  input: {
    keyword: string;
    minMatchCount: number;
  }
): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => {
    const keyword = input.keyword.trim();
    if (!keyword) {
      return null;
    }

    return mapProfileRule(
      profile,
      (rule) => rule.id === ruleId,
      (rule) => ({
        ...rule,
        fingerprint: rule.fingerprint,
        keyword,
        minMatchCount: Math.max(2, Math.floor(input.minMatchCount)),
        objectName: rule.objectName,
        objectTags: rule.objectTags,
        updatedAt: new Date().toISOString()
      })
    );
  });
}

export async function setTextBlockRuleEnabled(profileId: string, ruleId: string, enabled: boolean): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => mapProfileRule(
    profile,
    (rule) => rule.id === ruleId,
    (rule) => ({
      ...rule,
      enabled,
      updatedAt: new Date().toISOString()
    })
  ));
}

export async function setTextBlockObjectEnabled(profileId: string, objectId: string, enabled: boolean): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => mapProfileRule(
    profile,
    (rule) => rule.objectId === objectId,
    (rule) => ({
      ...rule,
      enabled,
      updatedAt: new Date().toISOString()
    })
  ));
}

export async function renameTextBlockObject(
  profileId: string,
  objectId: string,
  objectName: string
): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => mapProfileRule(
    profile,
    (rule) => rule.objectId === objectId,
    (rule) => ({
      ...rule,
      objectName: objectName.trim() || rule.objectName,
      updatedAt: new Date().toISOString()
    })
  ));
}

export async function setTextBlockObjectTags(
  profileId: string,
  objectId: string,
  objectTags: string[] | string
): Promise<TextBlockProfile | null> {
  const nextTags = Array.isArray(objectTags) ? normalizeObjectTags(objectTags) : parseObjectTags(objectTags);
  return mutateTextBlockProfile(profileId, (profile) => mapProfileRule(
    profile,
    (rule) => rule.objectId === objectId,
    (rule) => ({
      ...rule,
      objectTags: nextTags,
      updatedAt: new Date().toISOString()
    })
  ));
}

export async function setTextBlockRuleFingerprint(
  profileId: string,
  ruleId: string,
  fingerprint: string | null
): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => mapProfileRule(
    profile,
    (rule) => rule.id === ruleId,
    (rule) => ({
      ...rule,
      fingerprint: typeof fingerprint === "string" && fingerprint.length > 0 ? fingerprint : null,
      updatedAt: new Date().toISOString()
    })
  ));
}

export async function setTextBlockProfileEnabled(profileId: string, enabled: boolean): Promise<TextBlockProfile | null> {
  return mutateTextBlockProfile(profileId, (profile) => ({
    ...profile,
    enabled,
    updatedAt: new Date().toISOString()
  }));
}

export async function setTextBlockGlobalEnabled(globalEnabled: boolean): Promise<TextBlockStore> {
  const store = await readTextBlockStore();
  const nextStore: TextBlockStore = {
    ...store,
    settings: {
      ...store.settings,
      globalEnabled
    }
  };
  await writeTextBlockStore(nextStore);
  return nextStore;
}

export async function setTextBlockHiddenObjectTag(tag: string, hidden: boolean): Promise<TextBlockStore> {
  const store = await readTextBlockStore();
  const nextStore: TextBlockStore = {
    ...store,
    settings: {
      ...store.settings,
      hiddenObjectTags: updateHiddenObjectTags(store.settings.hiddenObjectTags, tag, hidden)
    }
  };
  await writeTextBlockStore(nextStore);
  return nextStore;
}

export async function readActiveTextBlockState(url: string): Promise<ActiveTextBlockState> {
  const store = await readTextBlockStore();
  return buildActiveTextBlockState(store, url, matchesUrl);
}
