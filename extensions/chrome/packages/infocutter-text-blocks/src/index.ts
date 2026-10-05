export const TEXT_BLOCK_STORAGE_VERSION = 1;
export const DEFAULT_HIDDEN_OBJECT_TAGS = ["ad"] as const;

export type TextBlockRule = {
  createdAt: string;
  enabled: boolean;
  fingerprint: string | null;
  id: string;
  keyword: string;
  minMatchCount: number;
  objectId: string;
  objectName: string;
  objectTags: string[];
  updatedAt: string;
};

export type TextBlockProfile = {
  enabled: boolean;
  id: string;
  matchers: string[];
  name: string;
  rules: TextBlockRule[];
  updatedAt: string;
};

export type TextBlockStore = {
  settings: {
    globalEnabled: boolean;
    hiddenObjectTags: string[];
  };
  profiles: TextBlockProfile[];
  version: typeof TEXT_BLOCK_STORAGE_VERSION;
};

export type ActiveTextBlockState = {
  activeProfileId: string | null;
  activeProfileName: string | null;
  globalEnabled: boolean;
  hiddenObjectTags: string[];
  matchers: string[];
  profileEnabled: boolean;
  ruleCount: number;
  rules: TextBlockRule[];
  updatedAt: string;
  url: string;
};

export type TextBlockDebugSample = {
  classSignature: string;
  parentTag: string;
  tagName: string;
  textSnippet: string;
};

export type TextBlockDebugGroup = {
  blockCount: number;
  childSignature: string;
  classSignature: string;
  fingerprint: string;
  matchesRuleFingerprint: boolean;
  parentTag: string;
  qualifies: boolean;
  samples: TextBlockDebugSample[];
  tagName: string;
};

export type TextBlockRuleDiagnostics = {
  eligibleBlockCount: number;
  eligibleGroupCount: number;
  fingerprint: string | null;
  groups: TextBlockDebugGroup[];
  keyword: string;
  minMatchCount: number;
  objectId: string;
  objectName: string;
  objectTags: string[];
  ruleId: string;
  tagMatched: boolean;
};

export type ActiveTextBlockDiagnostics = {
  activeProfileId: string | null;
  activeProfileName: string | null;
  globalEnabled: boolean;
  hiddenObjectTags: string[];
  profileEnabled: boolean;
  rules: TextBlockRuleDiagnostics[];
  supported: boolean;
  url: string;
};

export type TextBlockObjectGroup = {
  enabled: boolean;
  objectId: string;
  objectName: string;
  objectTags: string[];
  rules: TextBlockRule[];
};

export type CreateTextBlockRuleInput = {
  fingerprint?: string | null;
  keyword: string;
  minMatchCount: number;
  objectId?: string;
  objectName?: string;
  objectTags?: string[];
};

function fallbackId(): string {
  return `itb-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

export function generateTextBlockId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  return fallbackId();
}

export function normalizeObjectTags(tags: unknown): string[] {
  if (!Array.isArray(tags)) {
    return [];
  }

  return Array.from(new Set(tags
    .filter((tag): tag is string => typeof tag === "string")
    .map((tag) => tag.trim().toLowerCase())
    .filter((tag) => /^[a-z0-9_-]{1,32}$/.test(tag))));
}

export function parseObjectTags(tags: string): string[] {
  return normalizeObjectTags(tags.split(/[,\s]+/));
}

export function defaultHiddenObjectTags(): string[] {
  return [...DEFAULT_HIDDEN_OBJECT_TAGS];
}

export function emptyTextBlockStore(): TextBlockStore {
  return {
    version: TEXT_BLOCK_STORAGE_VERSION,
    settings: {
      globalEnabled: false,
      hiddenObjectTags: defaultHiddenObjectTags()
    },
    profiles: []
  };
}

export function emptyTextBlockProfile(generateId = generateTextBlockId): TextBlockProfile {
  return {
    enabled: true,
    id: generateId(),
    matchers: [],
    name: "새 텍스트 프로필",
    rules: [],
    updatedAt: new Date(0).toISOString()
  };
}

export function normalizeTextBlockRule(rule: unknown, generateId = generateTextBlockId): TextBlockRule | null {
  if (!rule || typeof rule !== "object") {
    return null;
  }

  const createdAtValue: unknown = Reflect.get(rule, "createdAt");
  const enabledValue: unknown = Reflect.get(rule, "enabled");
  const fingerprintValue: unknown = Reflect.get(rule, "fingerprint");
  const idValue: unknown = Reflect.get(rule, "id");
  const keywordValue: unknown = Reflect.get(rule, "keyword");
  const minMatchCountValue: unknown = Reflect.get(rule, "minMatchCount");
  const objectIdValue: unknown = Reflect.get(rule, "objectId");
  const objectNameValue: unknown = Reflect.get(rule, "objectName");
  const objectTagsValue: unknown = Reflect.get(rule, "objectTags");
  const updatedAtValue: unknown = Reflect.get(rule, "updatedAt");

  if (typeof keywordValue !== "string" || keywordValue.trim().length === 0) {
    return null;
  }

  const createdAt = typeof createdAtValue === "string" ? createdAtValue : new Date(0).toISOString();
  const id = typeof idValue === "string" && idValue.length > 0 ? idValue : generateId();
  const keyword = keywordValue.trim();

  return {
    createdAt,
    enabled: typeof enabledValue === "boolean" ? enabledValue : true,
    fingerprint: typeof fingerprintValue === "string" && fingerprintValue.length > 0 ? fingerprintValue : null,
    id,
    keyword,
    minMatchCount: typeof minMatchCountValue === "number" && minMatchCountValue >= 2 ? Math.floor(minMatchCountValue) : 2,
    objectId: typeof objectIdValue === "string" && objectIdValue.length > 0 ? objectIdValue : id,
    objectName: typeof objectNameValue === "string" && objectNameValue.length > 0 ? objectNameValue : keyword,
    objectTags: normalizeObjectTags(objectTagsValue),
    updatedAt: typeof updatedAtValue === "string" ? updatedAtValue : createdAt
  };
}

export function normalizeTextBlockProfile(profile: unknown, generateId = generateTextBlockId): TextBlockProfile | null {
  if (!profile || typeof profile !== "object") {
    return null;
  }

  const enabledValue: unknown = Reflect.get(profile, "enabled");
  const idValue: unknown = Reflect.get(profile, "id");
  const matchersValue: unknown = Reflect.get(profile, "matchers");
  const nameValue: unknown = Reflect.get(profile, "name");
  const rulesValue: unknown = Reflect.get(profile, "rules");
  const updatedAtValue: unknown = Reflect.get(profile, "updatedAt");

  return {
    enabled: typeof enabledValue === "boolean" ? enabledValue : true,
    id: typeof idValue === "string" && idValue.length > 0 ? idValue : generateId(),
    matchers: Array.isArray(matchersValue)
      ? matchersValue.filter((matcher): matcher is string => typeof matcher === "string" && matcher.length > 0)
      : [],
    name: typeof nameValue === "string" && nameValue.length > 0 ? nameValue : "이름 없는 텍스트 프로필",
    rules: Array.isArray(rulesValue)
      ? rulesValue.map((rule) => normalizeTextBlockRule(rule, generateId)).filter((rule): rule is TextBlockRule => rule !== null)
      : [],
    updatedAt: typeof updatedAtValue === "string" ? updatedAtValue : new Date(0).toISOString()
  };
}

export function normalizeTextBlockStore(candidate: unknown, generateId = generateTextBlockId): TextBlockStore {
  if (!candidate || typeof candidate !== "object") {
    return emptyTextBlockStore();
  }

  const versionValue: unknown = Reflect.get(candidate, "version");
  const profilesValue: unknown = Reflect.get(candidate, "profiles");
  const settingsValue: unknown = Reflect.get(candidate, "settings");

  if (versionValue !== TEXT_BLOCK_STORAGE_VERSION) {
    return emptyTextBlockStore();
  }

  return {
    version: TEXT_BLOCK_STORAGE_VERSION,
    settings: {
      globalEnabled:
        settingsValue &&
        typeof settingsValue === "object" &&
        "globalEnabled" in settingsValue &&
        typeof settingsValue.globalEnabled === "boolean"
          ? settingsValue.globalEnabled
          : false,
      hiddenObjectTags:
        settingsValue &&
        typeof settingsValue === "object" &&
        "hiddenObjectTags" in settingsValue
          ? normalizeObjectTags(settingsValue.hiddenObjectTags)
          : defaultHiddenObjectTags()
    },
    profiles: Array.isArray(profilesValue)
      ? profilesValue.map((profile) => normalizeTextBlockProfile(profile, generateId)).filter((profile): profile is TextBlockProfile => profile !== null)
      : []
  };
}

export function createTextBlockRule(input: CreateTextBlockRuleInput, generateId = generateTextBlockId): TextBlockRule {
  const timestamp = new Date().toISOString();
  const keyword = input.keyword.trim();
  const objectId = input.objectId ?? generateId();
  const normalizedObjectName = input.objectName?.trim();

  return {
    createdAt: timestamp,
    enabled: true,
    fingerprint: input.fingerprint ?? null,
    id: generateId(),
    keyword,
    minMatchCount: Math.max(2, Math.floor(input.minMatchCount)),
    objectId,
    objectName: normalizedObjectName && normalizedObjectName.length > 0 ? normalizedObjectName : keyword,
    objectTags: normalizeObjectTags(input.objectTags ?? []),
    updatedAt: timestamp
  };
}

export function groupTextBlockRulesByObject(rules: TextBlockRule[]): TextBlockObjectGroup[] {
  const groups = new Map<string, TextBlockObjectGroup>();

  for (const rule of rules) {
    const current = groups.get(rule.objectId);
    if (current) {
      current.enabled = current.enabled || rule.enabled;
      current.objectName = rule.objectName;
      current.objectTags = rule.objectTags;
      current.rules.push(rule);
      continue;
    }

    groups.set(rule.objectId, {
      enabled: rule.enabled,
      objectId: rule.objectId,
      objectName: rule.objectName,
      objectTags: rule.objectTags,
      rules: [rule]
    });
  }

  return Array.from(groups.values()).sort((left, right) => left.objectName.localeCompare(right.objectName));
}

export function textBlockRuleMatchesHiddenTags(rule: TextBlockRule, hiddenObjectTags: string[]): boolean {
  if (rule.objectTags.length === 0) {
    return true;
  }

  return rule.objectTags.some((tag) => hiddenObjectTags.includes(tag));
}

export function findMatchingTextBlockProfile(
  store: TextBlockStore,
  url: string,
  matchesUrl: (matcher: string, url: string) => boolean
): TextBlockProfile | null {
  return store.profiles.find((profile) => profile.matchers.some((matcher) => matchesUrl(matcher, url))) ?? null;
}

export function buildActiveTextBlockState(
  store: TextBlockStore,
  url: string,
  matchesUrl: (matcher: string, url: string) => boolean
): ActiveTextBlockState {
  const profile = findMatchingTextBlockProfile(store, url, matchesUrl);
  return {
    activeProfileId: profile?.id ?? null,
    activeProfileName: profile?.name ?? null,
    globalEnabled: store.settings.globalEnabled,
    hiddenObjectTags: [...store.settings.hiddenObjectTags],
    matchers: profile?.matchers ?? [],
    profileEnabled: profile?.enabled ?? false,
    ruleCount: profile?.rules.length ?? 0,
    rules: profile?.rules ? [...profile.rules] : [],
    updatedAt: profile?.updatedAt ?? new Date(0).toISOString(),
    url
  };
}

export function updateHiddenObjectTags(hiddenObjectTags: string[], tag: string, hidden: boolean): string[] {
  const normalizedTag = normalizeObjectTags([tag])[0];
  if (!normalizedTag) {
    return normalizeObjectTags(hiddenObjectTags);
  }

  const hiddenTags = new Set(normalizeObjectTags(hiddenObjectTags));
  if (hidden) {
    hiddenTags.add(normalizedTag);
  } else {
    hiddenTags.delete(normalizedTag);
  }

  return Array.from(hiddenTags).sort();
}
