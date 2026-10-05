import {
  createWatchTarget,
  emptyWatchStore,
  normalizeWatchStore
} from "../../packages/infocutter-watch/src/index.js";
import type { WatchStore } from "../../packages/infocutter-watch/src/index.js";
import { WATCH_STORAGE_KEY } from "./constants.js";

export type WatchMutation =
  | { kind: "add"; name: string; aliases: string[] }
  | { kind: "remove"; id: string }
  | { kind: "toggle"; id: string; enabled: boolean }
  | { kind: "setAliases"; id: string; aliases: string[] }
  | { kind: "setGlobalEnabled"; enabled: boolean }
  | { kind: "setAutoMask"; enabled: boolean };

export function applyWatchMutation(store: WatchStore, mutation: WatchMutation): WatchStore {
  const now = new Date().toISOString();
  switch (mutation.kind) {
    case "add":
      return { ...store, targets: [...store.targets, createWatchTarget({ name: mutation.name, aliases: mutation.aliases })] };
    case "remove":
      return { ...store, targets: store.targets.filter((target) => target.id !== mutation.id) };
    case "toggle":
      return {
        ...store,
        targets: store.targets.map((target) =>
          target.id === mutation.id ? { ...target, enabled: mutation.enabled, updatedAt: now } : target)
      };
    case "setAliases":
      return {
        ...store,
        targets: store.targets.map((target) =>
          target.id === mutation.id
            ? { ...createWatchTarget({ name: target.name, aliases: mutation.aliases, id: target.id }), enabled: target.enabled, createdAt: target.createdAt }
            : target)
      };
    case "setGlobalEnabled":
      return { ...store, settings: { ...store.settings, globalEnabled: mutation.enabled } };
    case "setAutoMask":
      return { ...store, settings: { ...store.settings, autoMask: mutation.enabled } };
    default:
      return store;
  }
}

export async function readWatchStore(): Promise<WatchStore> {
  const result = await chrome.storage.local.get(WATCH_STORAGE_KEY);
  return normalizeWatchStore(result[WATCH_STORAGE_KEY]);
}

export async function writeWatchStore(store: WatchStore): Promise<void> {
  await chrome.storage.local.set({ [WATCH_STORAGE_KEY]: store });
}

export async function mutateWatchStore(mutation: WatchMutation): Promise<WatchStore> {
  const next = applyWatchMutation(await readWatchStore(), mutation);
  await writeWatchStore(next);
  return next;
}

export { emptyWatchStore };
