export type StorageArea = "local" | "sync" | "session";

export type SettingsStore<T> = {
  /** Read + normalize the persisted settings (returns defaults when unset/corrupt). */
  getSettings(): Promise<T>;
  /** Normalize then persist the settings, returning the normalized value. */
  setSettings(settings: T): Promise<T>;
  /** A fresh copy of the default (normalized-from-empty) settings. */
  defaultSettings(): T;
  /** Patch a subset of fields on top of the currently-persisted settings. */
  updateSettings(patch: Partial<T>): Promise<T>;
};

export type SettingsStoreConfig<T> = {
  /** chrome.storage key the settings blob is stored under. */
  storageKey: string;
  /** chrome.storage area (defaults to "local"). */
  area?: StorageArea;
  /** Pure function turning arbitrary/undefined input into a valid settings object. */
  normalize: (candidate: unknown) => T;
  /** Optional deep-clone for defaultSettings(); defaults to a shallow spread. */
  clone?: (settings: T) => T;
};

/**
 * Generic chrome.storage settings scaffold. Every extension shares the same
 * get / set / normalize / update plumbing and only supplies its own schema via
 * the `normalize` function.
 */
export function createSettingsStore<T>(config: SettingsStoreConfig<T>): SettingsStore<T> {
  const area: StorageArea = config.area ?? "local";
  const clone = config.clone ?? ((settings: T): T => ({ ...(settings as object) }) as T);

  async function getSettings(): Promise<T> {
    const data = await chrome.storage[area].get(config.storageKey);
    return config.normalize((data as Record<string, unknown>)[config.storageKey]);
  }

  async function setSettings(settings: T): Promise<T> {
    const normalized = config.normalize(settings);
    await chrome.storage[area].set({ [config.storageKey]: normalized });
    return normalized;
  }

  function defaultSettings(): T {
    return clone(config.normalize(undefined));
  }

  async function updateSettings(patch: Partial<T>): Promise<T> {
    const current = await getSettings();
    return setSettings({ ...(current as object), ...(patch as object) } as T);
  }

  return { getSettings, setSettings, defaultSettings, updateSettings };
}
