export const WATCH_STORAGE_VERSION = 1 as const;

export type WatchTarget = {
  id: string;
  name: string;
  aliases: string[];
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
};

export type WatchSettings = {
  globalEnabled: boolean;
  autoMask: boolean;
};

export type WatchStore = {
  version: typeof WATCH_STORAGE_VERSION;
  settings: WatchSettings;
  targets: WatchTarget[];
};

function generateWatchId(): string {
  return `iw-${Math.random().toString(36).slice(2, 10)}-${Date.now().toString(36)}`;
}

function cleanTerm(value: unknown): string {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function uniqueNonEmpty(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    if (value.length > 0 && !seen.has(value)) {
      seen.add(value);
      result.push(value);
    }
  }
  return result;
}

export function emptyWatchStore(): WatchStore {
  return {
    version: WATCH_STORAGE_VERSION,
    settings: { globalEnabled: true, autoMask: true },
    targets: []
  };
}

export function createWatchTarget(input: { name: string; aliases?: string[]; id?: string }): WatchTarget {
  const timestamp = new Date().toISOString();
  return {
    id: input.id && input.id.length > 0 ? input.id : generateWatchId(),
    name: cleanTerm(input.name),
    aliases: uniqueNonEmpty((input.aliases ?? []).map(cleanTerm)),
    enabled: true,
    createdAt: timestamp,
    updatedAt: timestamp
  };
}

function normalizeWatchTarget(candidate: unknown): WatchTarget | null {
  if (!candidate || typeof candidate !== "object") {
    return null;
  }
  const record = candidate as Record<string, unknown>;
  const name = cleanTerm(record.name);
  if (name.length === 0) {
    return null;
  }
  const timestamp = new Date().toISOString();
  return {
    id: typeof record.id === "string" && record.id.length > 0 ? record.id : generateWatchId(),
    name,
    aliases: uniqueNonEmpty(Array.isArray(record.aliases) ? record.aliases.map(cleanTerm) : []),
    enabled: record.enabled !== false,
    createdAt: typeof record.createdAt === "string" ? record.createdAt : timestamp,
    updatedAt: typeof record.updatedAt === "string" ? record.updatedAt : timestamp
  };
}

export function normalizeWatchStore(candidate: unknown): WatchStore {
  if (!candidate || typeof candidate !== "object") {
    return emptyWatchStore();
  }
  const record = candidate as Record<string, unknown>;
  if (record.version !== undefined && record.version !== WATCH_STORAGE_VERSION) {
    return emptyWatchStore();
  }
  const settings = (record.settings ?? {}) as Record<string, unknown>;
  const targets = Array.isArray(record.targets)
    ? record.targets.map(normalizeWatchTarget).filter((target): target is WatchTarget => target !== null)
    : [];
  return {
    version: WATCH_STORAGE_VERSION,
    settings: {
      globalEnabled: settings.globalEnabled !== false,
      autoMask: settings.autoMask !== false
    },
    targets
  };
}

export function watchTerms(store: WatchStore): string[] {
  const terms: string[] = [];
  for (const target of store.targets) {
    if (!target.enabled) {
      continue;
    }
    for (const term of [target.name, ...target.aliases]) {
      const normalized = term.toLowerCase();
      if (normalized.length >= 2) {
        terms.push(normalized);
      }
    }
  }
  return uniqueNonEmpty(terms);
}

export function matchTerms(text: string, terms: string[]): string | null {
  const haystack = text.replace(/\s+/g, " ").toLowerCase();
  for (const term of terms) {
    if (haystack.includes(term)) {
      return term;
    }
  }
  return null;
}
