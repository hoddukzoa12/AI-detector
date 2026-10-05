import { messageTypes } from "../shared/messages.js";
import type { ActiveTextBlockDiagnostics } from "../shared/types.js";
import { textBlockOpenTabButtonElement, textBlockPreviewStatusElement, textBlockPreviewTabElement, textBlockRefreshTabsButtonElement } from "./elements.js";

let selectedPreviewTabId: number | null = null;

export function getSelectedPreviewTabId(): number | null {
  return selectedPreviewTabId;
}

export function setSelectedPreviewTabId(tabId: number | null): void {
  selectedPreviewTabId = tabId;
}

export function clearSelectedPreviewTabIfMatches(tabId: number): void {
  if (selectedPreviewTabId === tabId) {
    selectedPreviewTabId = null;
  }
}

function isSupportedUrl(url?: string): boolean {
  return typeof url === "string" && /^https?:\/\//.test(url);
}

function previewTabLabel(tab: chrome.tabs.Tab & { id: number }): string {
  const rawTitle = tab.title?.trim();
  const title = rawTitle && rawTitle.length > 0 ? rawTitle : "제목 없음";

  try {
    const parsed = new URL(tab.url ?? "");
    const suffix = parsed.pathname && parsed.pathname !== "/" ? parsed.pathname : parsed.hostname;
    return `${title} · ${suffix}`;
  } catch {
    return title;
  }
}

async function listPreviewTargetTabs(): Promise<(chrome.tabs.Tab & { id: number })[]> {
  const tabs = await chrome.tabs.query({ currentWindow: true });
  return tabs
    .filter((tab): tab is chrome.tabs.Tab & { id: number } => typeof tab.id === "number" && isSupportedUrl(tab.url))
    .sort((left, right) => {
      const leftScore = left.active ? Number.MAX_SAFE_INTEGER : left.lastAccessed ?? 0;
      const rightScore = right.active ? Number.MAX_SAFE_INTEGER : right.lastAccessed ?? 0;
      return rightScore - leftScore;
    });
}

async function syncPreviewTargetTabSelect(): Promise<(chrome.tabs.Tab & { id: number }) | null> {
  const supportedTabs = await listPreviewTargetTabs();
  textBlockPreviewTabElement.replaceChildren();

  if (supportedTabs.length === 0) {
    selectedPreviewTabId = null;
    textBlockPreviewTabElement.disabled = true;
    textBlockRefreshTabsButtonElement.disabled = true;
    textBlockOpenTabButtonElement.disabled = true;
    const option = document.createElement("option");
    option.value = "";
    option.textContent = "선택 가능한 웹 탭이 없습니다";
    textBlockPreviewTabElement.append(option);
    textBlockPreviewStatusElement.textContent = "진단 가능한 일반 웹 탭이 없습니다.";
    return null;
  }

  textBlockPreviewTabElement.disabled = false;
  textBlockRefreshTabsButtonElement.disabled = false;

  const selectedTab = supportedTabs.find((tab) => tab.id === selectedPreviewTabId) ?? supportedTabs[0] ?? null;
  selectedPreviewTabId = selectedTab?.id ?? null;
  textBlockOpenTabButtonElement.disabled = selectedPreviewTabId === null;

  for (const tab of supportedTabs) {
    const option = document.createElement("option");
    option.value = String(tab.id);
    option.textContent = previewTabLabel(tab);
    option.selected = tab.id === selectedPreviewTabId;
    textBlockPreviewTabElement.append(option);
  }

  if (!selectedTab) {
    textBlockPreviewStatusElement.textContent = "진단 대상 탭을 찾지 못했습니다.";
    return null;
  }

  let host = selectedTab.url ?? "";
  try {
    host = new URL(selectedTab.url ?? "").hostname;
  } catch {
    /* keep raw url when parsing fails */
  }
  textBlockPreviewStatusElement.textContent = `진단 대상 탭 · ${previewTabLabel(selectedTab)} · ${host}`;
  return selectedTab;
}

async function ensureTabReady(tabId: number): Promise<boolean> {
  const response: unknown = await chrome.runtime.sendMessage({
    type: messageTypes.ensureTabReady,
    tabId
  });
  if (!response || typeof response !== "object" || !("ok" in response)) {
    return false;
  }

  return response.ok === true;
}

async function sendMessageToActiveTab<T>(tabId: number, type: string): Promise<T | null> {
  try {
    const response: unknown = await chrome.tabs.sendMessage(tabId, { type });
    if (!response || typeof response !== "object" || !("ok" in response) || response.ok !== true) {
      return null;
    }
    return "data" in response ? response.data as T : null;
  } catch {
    return null;
  }
}

export async function readActiveTextBlockDiagnostics(): Promise<ActiveTextBlockDiagnostics | null> {
  const activeTab = await syncPreviewTargetTabSelect();
  if (!activeTab || !isSupportedUrl(activeTab.url)) {
    return null;
  }

  const ready = await ensureTabReady(activeTab.id);
  if (!ready) {
    return null;
  }

  return sendMessageToActiveTab<ActiveTextBlockDiagnostics>(activeTab.id, messageTypes.getTextBlockDiagnostics);
}
