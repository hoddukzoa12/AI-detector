import { messageTypes } from "../shared/messages.js";
import { NETWORK_RULE_STORAGE_KEY } from "../shared/constants.js";
import { enabledPortableDnrRules, NETWORK_RULE_ID_BASE, NETWORK_RULE_ID_MAX, readNetworkRuleStore } from "../shared/network-rules.js";
import { findMatchingProfile, getEnabledRules, readStore } from "../shared/storage.js";
import { commandIds, toggleCommandMessage } from "../shared/commands.js";
import type { PortableDnrRule } from "../../packages/infocutter-filter-importer/src/index.js";
import { readWatchStore, mutateWatchStore } from "../shared/watch-storage.js";
import { appendEvidence, hasEvidenceFor, nextSequence } from "../shared/evidence-db.js";
import type { EvidenceRecord } from "../shared/evidence-db.js";
import { analyzePageForAi, decideAiAnalysis } from "../shared/ai-orchestrator.js";
import { readAiConfig, isHostAnalyzed } from "../shared/ai-config.js";
import { readAiRuleStore } from "../shared/ai-rule-storage.js";
import { hostnameFromUrl } from "../shared/storage-matchers.js";
import type { AiBlock } from "../shared/ai-llm-client.js";
import { buildEvidenceInPage } from "../evidence/page-evidence-builder.js";
import type { PageEvidencePayload } from "../evidence/page-evidence-builder.js";

const contextMenuIds = {
  root: "infocutter-root",
  hideTarget: "infocutter-hide-target",
  startPicker: "infocutter-start-picker"
} as const;
const contentScriptFiles = [
  "src/content/text-blocks-package.js",
  "src/content/watch-package.js",
  "src/content/constants.js",
  "src/content/peek.js",
  "src/content/toast.js",
  "src/content/state.js",
  "src/content/frame-context.js",
  "src/content/site-storage.js",
  "src/content/dom-block.js",
  "src/content/text-block-runtime.js",
  "src/content/watch-runtime.js",
  "src/content/selector-engine.js",
  "src/content/ai-runtime.js",
  "src/content/ai-collector.js",
  "src/content/render-coordinator.js",
  "src/content/picker-overlay.js",
  "src/content/picker-analysis.js",
  "src/content/picker-hover.js",
  "src/content/picker-session.js",
  "src/content/picker-iframe.js",
  "src/content/picker-refine-panel.js",
  "src/content/picker-session-panel.js",
  "src/content/picker-ui.js",
  "src/content/index.js"
] as const;

const pickerFocusByTab = new Map<number, { focused: boolean; frameScope: string | null; label: string }>();

type NetworkRuleApplyResult = {
  addedRuleCount: number;
  removedRuleCount: number;
};
let networkRuleApplyQueue = Promise.resolve<NetworkRuleApplyResult>({
  addedRuleCount: 0,
  removedRuleCount: 0
});

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function isSupportedUrl(url?: string): boolean {
  return typeof url === "string" && /^https?:\/\//.test(url);
}

function isMissingTabError(error: unknown): boolean {
  return error instanceof Error && error.message.includes("No tab with id");
}

async function doesTabExist(tabId: number): Promise<boolean> {
  try {
    await chrome.tabs.get(tabId);
    return true;
  } catch {
    return false;
  }
}

async function runBadgeOperation(operation: () => Promise<void>): Promise<void> {
  try {
    await operation();
  } catch (error) {
    if (isMissingTabError(error)) {
      return;
    }

    throw error;
  }
}

async function updateBadgeForTab(tabId: number, url?: string): Promise<void> {
  const exists = await doesTabExist(tabId);
  if (!exists) {
    pickerFocusByTab.delete(tabId);
    return;
  }

  if (!url || !/^https?:\/\//.test(url)) {
    await runBadgeOperation(() => chrome.action.setBadgeText({ tabId, text: "" }));
    return;
  }

  const store = await readStore();
  const profile = findMatchingProfile(store, url);
  const enabledRules = getEnabledRules(profile);

  if (!store.settings.globalEnabled || !profile || !profile.enabled || enabledRules.length === 0) {
    await runBadgeOperation(() => chrome.action.setBadgeText({ tabId, text: "" }));
    return;
  }

  await runBadgeOperation(() => chrome.action.setBadgeBackgroundColor({
    tabId,
    color: "#8f2d1d"
  }));
  await runBadgeOperation(() => chrome.action.setBadgeText({
    tabId,
    text: String(Math.min(enabledRules.length, 99))
  }));
}

function isInfocutterDynamicRule(rule: chrome.declarativeNetRequest.Rule): boolean {
  return rule.id >= NETWORK_RULE_ID_BASE && rule.id <= NETWORK_RULE_ID_MAX;
}

function toChromeDnrRule(rule: PortableDnrRule): chrome.declarativeNetRequest.Rule {
  return rule as chrome.declarativeNetRequest.Rule;
}

async function applyNetworkRulesFromStore(): Promise<NetworkRuleApplyResult> {
  const store = await readNetworkRuleStore();
  const existingDynamicRules = await chrome.declarativeNetRequest.getDynamicRules();
  const removeRuleIds = existingDynamicRules
    .filter((rule) => isInfocutterDynamicRule(rule))
    .map((rule) => rule.id);
  const addRules = enabledPortableDnrRules(store).map((rule) => toChromeDnrRule(rule));

  await chrome.declarativeNetRequest.updateDynamicRules({
    addRules,
    removeRuleIds
  });

  return {
    addedRuleCount: addRules.length,
    removedRuleCount: removeRuleIds.length
  };
}

function enqueueNetworkRulesApply(): Promise<NetworkRuleApplyResult> {
  const nextApply = networkRuleApplyQueue
    .catch(() => ({
      addedRuleCount: 0,
      removedRuleCount: 0
    }))
    .then(() => applyNetworkRulesFromStore());
  networkRuleApplyQueue = nextApply;
  return nextApply;
}

function createContextMenus(): void {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: contextMenuIds.root,
      title: "인포커터",
      contexts: ["all"]
    });

    chrome.contextMenus.create({
      id: contextMenuIds.hideTarget,
      parentId: contextMenuIds.root,
      title: "이 요소 숨기기",
      contexts: ["all"]
    });

    chrome.contextMenus.create({
      id: contextMenuIds.startPicker,
      parentId: contextMenuIds.root,
      title: "선택 모드 시작",
      contexts: ["all"]
    });
  });
}

async function sendTabMessage(tabId: number, type: string, frameId?: number): Promise<void> {
  if (typeof frameId === "number") {
    await chrome.tabs.sendMessage(tabId, { type }, { frameId });
    return;
  }

  await chrome.tabs.sendMessage(tabId, { type });
}

async function ensureContentScript(tabId: number): Promise<void> {
  await chrome.scripting.executeScript({
    target: { tabId, allFrames: true },
    files: [...contentScriptFiles]
  });
}

async function pingTab(tabId: number): Promise<boolean> {
  try {
    const response: unknown = await chrome.tabs.sendMessage(tabId, { type: messageTypes.ping });
    if (!response || typeof response !== "object") {
      return false;
    }

    return "ok" in response && response.ok === true;
  } catch {
    return false;
  }
}

async function ensureTabReady(tabId: number): Promise<boolean> {
  const wasReady = await pingTab(tabId);
  if (wasReady) {
    return true;
  }

  /** manifest-declared 콘텐츠 스크립트가 attach 될 틈을 준 뒤 두 번째 복사본을
   *  주입한다. 빠른 리로드 시 최상위 선언 중복을 피하기 위해서다. */
  for (const delayMs of [80, 180, 320, 520]) {
    await sleep(delayMs);
    const ready = await pingTab(tabId);
    if (ready) {
      return true;
    }
  }

  await ensureContentScript(tabId);

  for (const delayMs of [120, 220, 360]) {
    await sleep(delayMs);
    const ready = await pingTab(tabId);
    if (ready) {
      return true;
    }
  }

  return false;
}

async function sendMessageToTopFrame(tabId: number, type: string): Promise<void> {
  await sendTabMessage(tabId, type, 0);
}

async function sendToggleToTopFrame(tabId: number, messageType: string, enabled: boolean): Promise<void> {
  await chrome.tabs.sendMessage(tabId, { type: messageType, enabled, toast: true }, { frameId: 0 });
}

async function sendMessageToAllFrames(tabId: number, type: string): Promise<void> {
  const frames = await chrome.webNavigation.getAllFrames({ tabId });
  const resolvedFrames = frames ?? [];
  const frameIds = resolvedFrames
    .map((frame) => frame.frameId)
    .filter((frameId): frameId is number => typeof frameId === "number");

  if (frameIds.length === 0) {
    await chrome.tabs.sendMessage(tabId, { type });
    return;
  }

  await Promise.all(
    frameIds.map(async (frameId) => {
      try {
        await chrome.tabs.sendMessage(tabId, { type }, { frameId });
      } catch {
        /** 프레임별 정리 실패는 무시한다. */
      }
    })
  );
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.action.setBadgeTextColor({ color: "#f7f4eb" }).catch(() => {
    /** 구형 Chrome 은 배지 텍스트 색 변경을 지원하지 않을 수 있다. */
  });
  createContextMenus();
  void enqueueNetworkRulesApply().catch((error: unknown) => {
    console.warn("인포커터 네트워크 규칙 적용에 실패했습니다", error);
  });
});

chrome.runtime.onStartup.addListener(() => {
  createContextMenus();
  void enqueueNetworkRulesApply().catch((error: unknown) => {
    console.warn("인포커터 네트워크 규칙 적용에 실패했습니다", error);
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (!tab?.id || !isSupportedUrl(tab.url)) {
    return;
  }

  const tabId = tab.id;
  const frameId = typeof info.frameId === "number" ? info.frameId : undefined;

  if (info.menuItemId === contextMenuIds.hideTarget) {
    void ensureTabReady(tabId)
      .then(async (ready) => {
        if (!ready) {
          return;
        }
        await sendTabMessage(tabId, messageTypes.hideLastContextTarget, frameId);
      })
      .catch((error: unknown) => {
      console.warn("인포커터 우클릭 숨기기에 실패했습니다", error);
    });
    return;
  }

  if (info.menuItemId === contextMenuIds.startPicker) {
    void ensureTabReady(tabId)
      .then(async (ready) => {
        if (!ready) {
          return;
        }
        await sendMessageToAllFrames(tabId, messageTypes.stopPicker);
        await sendMessageToTopFrame(tabId, messageTypes.startPicker);
      })
      .catch((error: unknown) => {
      console.warn("인포커터 선택 모드 시작에 실패했습니다", error);
    });
  }
});

const OFFSCREEN_DOCUMENT_PATH = "offscreen.html";
const OFFSCREEN_BUILD_TYPE = "infocutter/offscreen-build";
const CAPTURE_TILE_DELAY_MS = 350;
const CAPTURE_QUOTA_RETRY_MS = 1100;

type CapturePayload = {
  matchedTerm: string;
  url: string;
  pageTitle: string;
  matchedText: string;
  htmlExcerpt: string;
};

type PageMetrics = {
  dpr: number;
  innerHeight: number;
  scrollY: number;
  totalHeight: number;
  totalWidth: number;
};

type OffscreenBuildResult = {
  ok: boolean;
  error?: string;
  pngBase64?: string;
  htmlBase64?: string;
  pdfBase64?: string;
  pngSha256?: string;
  htmlSha256?: string;
};

let captureQueue: Promise<unknown> = Promise.resolve();

function sanitizeName(name: string): string {
  const cleaned = name.replace(/[^\p{L}\p{N}_-]+/gu, "_").replace(/^_+|_+$/g, "");
  return cleaned.length > 0 ? cleaned : "unknown";
}

async function ensureOffscreenDocument(): Promise<void> {
  const existing = await chrome.runtime.getContexts({
    contextTypes: [chrome.runtime.ContextType.OFFSCREEN_DOCUMENT]
  });
  if (existing.length > 0) {
    return;
  }

  await chrome.offscreen.createDocument({
    justification: "스크린샷 타일을 합치고 증거 PDF를 생성합니다.",
    reasons: [chrome.offscreen.Reason.DOM_PARSER, chrome.offscreen.Reason.BLOBS],
    url: OFFSCREEN_DOCUMENT_PATH
  });
}

function readPageMetrics(): PageMetrics {
  return {
    dpr: window.devicePixelRatio,
    innerHeight: window.innerHeight,
    scrollY: window.scrollY,
    totalHeight: document.documentElement.scrollHeight,
    totalWidth: document.documentElement.clientWidth
  };
}

function scrollWindowTo(y: number): number {
  window.scrollTo(0, y);
  return window.scrollY;
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

async function captureVisibleTabPng(windowId: number): Promise<string> {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      return await chrome.tabs.captureVisibleTab(windowId, { format: "png" });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.includes("MAX_CAPTURE_VISIBLE_TAB_CALLS_PER_SECOND")) {
        await delay(CAPTURE_QUOTA_RETRY_MS);
        continue;
      }

      throw error instanceof Error ? error : new Error(message);
    }
  }

  throw new Error("화면 캡처 호출 한도를 초과했습니다.");
}

async function captureFullPageTiles(
  tabId: number,
  windowId: number
): Promise<{ dpr: number; tiles: { dataUrl: string; y: number }[]; totalWidth: number; totalHeight: number }> {
  const [metricsResult] = await chrome.scripting.executeScript<[], PageMetrics>({
    func: readPageMetrics,
    target: { tabId }
  });
  const metrics: PageMetrics | undefined = metricsResult?.result;
  if (!metrics) {
    throw new Error("페이지 크기를 측정하지 못했습니다.");
  }

  const tiles: { dataUrl: string; y: number }[] = [];
  const step = Math.max(metrics.innerHeight, 1);
  try {
    for (let y = 0; y < metrics.totalHeight; y += step) {
      const [scrollResult] = await chrome.scripting.executeScript({ args: [y], func: scrollWindowTo, target: { tabId } });
      const actualY: number = typeof scrollResult?.result === "number" ? scrollResult.result : y;
      await delay(CAPTURE_TILE_DELAY_MS);
      const dataUrl = await captureVisibleTabPng(windowId);
      tiles.push({ dataUrl, y: actualY });
    }
  } finally {
    await chrome.scripting.executeScript({ args: [metrics.scrollY], func: scrollWindowTo, target: { tabId } });
  }

  return { dpr: metrics.dpr, tiles, totalHeight: metrics.totalHeight, totalWidth: metrics.totalWidth };
}

async function buildEvidenceInOffscreen(
  payload: CapturePayload,
  capturedAt: string,
  tiles: { dataUrl: string; y: number }[],
  totalWidth: number,
  totalHeight: number,
  dpr: number
): Promise<OffscreenBuildResult> {
  await ensureOffscreenDocument();
  const rawResult: unknown = await chrome.runtime.sendMessage({
    payload: {
      dpr,
      meta: {
        capturedAt,
        htmlExcerpt: payload.htmlExcerpt,
        matchedTerm: payload.matchedTerm,
        pageTitle: payload.pageTitle,
        url: payload.url
      },
      tiles,
      totalHeight,
      totalWidth
    },
    target: "offscreen",
    type: OFFSCREEN_BUILD_TYPE
  });
  const result = rawResult as OffscreenBuildResult | undefined;

  if (!result?.ok) {
    throw new Error(result?.error ?? "오프스크린 PDF 생성에 실패했습니다.");
  }

  return result;
}

/**
 * chrome.offscreen 지원 여부. iOS Safari Web Extension 은 offscreen 이 없어
 * 기존 offscreen 파이프라인이 사망 → content-script 경로로 분기한다.
 */
function hasOffscreenSupport(): boolean {
  return (
    typeof chrome !== "undefined" &&
    typeof chrome.offscreen !== "undefined" &&
    typeof chrome.offscreen.createDocument === "function"
  );
}

/**
 * offscreen 미지원 플랫폼(Safari) 용 빌드: 페이지 컨텍스트에서 (1) vendor/jspdf.js 주입,
 * (2) buildEvidenceInPage func 주입. 캡처 타일은 service-worker 의 captureVisibleTab
 * 결과를 그대로 args 로 넘긴다. 결과 타입은 offscreen 경로(OffscreenBuildResult)와 호환.
 */
async function buildEvidenceInContentScript(
  payload: CapturePayload,
  capturedAt: string,
  tiles: { dataUrl: string; y: number }[],
  totalWidth: number,
  totalHeight: number,
  dpr: number,
  tabId: number
): Promise<OffscreenBuildResult> {
  await chrome.scripting.executeScript({
    target: { tabId },
    files: ["vendor/jspdf.js"]
  });
  const pagePayload: PageEvidencePayload = {
    dpr,
    meta: {
      capturedAt,
      htmlExcerpt: payload.htmlExcerpt,
      matchedTerm: payload.matchedTerm,
      pageTitle: payload.pageTitle,
      url: payload.url
    },
    tiles,
    totalHeight,
    totalWidth
  };
  const injectResults = await chrome.scripting.executeScript({
    args: [pagePayload],
    func: buildEvidenceInPage,
    target: { tabId }
  });
  const built = (injectResults[0]?.result ?? undefined);
  if (!built?.ok) {
    throw new Error(built?.error ?? "페이지 컨텍스트 PDF 생성에 실패했습니다.");
  }
  return built;
}

async function saveEvidenceFile(folder: string, base: string, extension: string, mime: string, base64: string): Promise<number> {
  return chrome.downloads.download({
    conflictAction: "uniquify",
    filename: `infocutter-evidence/${folder}/${base}.${extension}`,
    url: `data:${mime};base64,${base64}`
  });
}

async function resolveTargetId(matchedTerm: string): Promise<string> {
  const store = await readWatchStore();
  const lowered = matchedTerm.toLowerCase();
  const match = store.targets.find((target) =>
    [target.name, ...target.aliases].some((value) => value.toLowerCase() === lowered));
  return match ? match.id : "";
}

async function handleCaptureEvidence(payload: CapturePayload, tabId: number, windowId: number): Promise<{ ok: boolean; deduped?: boolean; error?: string }> {
  const capturedAt = new Date().toISOString();
  const { dpr, tiles, totalWidth, totalHeight } = await captureFullPageTiles(tabId, windowId);
  const built = hasOffscreenSupport()
    ? await buildEvidenceInOffscreen(payload, capturedAt, tiles, totalWidth, totalHeight, dpr)
    : await buildEvidenceInContentScript(payload, capturedAt, tiles, totalWidth, totalHeight, dpr, tabId);
  const htmlSha256 = built.htmlSha256 ?? "";
  const pngSha256 = built.pngSha256 ?? "";

  if (await hasEvidenceFor(payload.url, htmlSha256)) {
    return { deduped: true, ok: true };
  }

  const folder = sanitizeName(payload.matchedTerm);
  const base = capturedAt.replace(/[:.]/g, "-");
  const targetId = await resolveTargetId(payload.matchedTerm);
  const manifest = {
    capturedAt,
    htmlSha256,
    matchedTerm: payload.matchedTerm,
    pageTitle: payload.pageTitle,
    pngSha256,
    url: payload.url
  };
  const manifestJson = JSON.stringify(manifest, null, 2);
  const manifestBytes = new TextEncoder().encode(manifestJson);
  const manifestBase64 = btoa(String.fromCharCode(...manifestBytes));

  const downloadId = await saveEvidenceFile(folder, base, "pdf", "application/pdf", built.pdfBase64 ?? "");
  await saveEvidenceFile(folder, base, "png", "image/png", built.pngBase64 ?? "");
  await saveEvidenceFile(folder, base, "html", "text/html", built.htmlBase64 ?? "");
  await saveEvidenceFile(folder, base, "manifest.json", "application/json", manifestBase64);

  const record: EvidenceRecord = {
    capturedAt,
    downloadId,
    htmlExcerpt: payload.htmlExcerpt,
    htmlSha256,
    id: `iev-${base}`,
    matchedTerm: payload.matchedTerm,
    matchedText: payload.matchedText,
    pageTitle: payload.pageTitle,
    pdfFilename: `infocutter-evidence/${folder}/${base}.pdf`,
    pngSha256,
    sequence: await nextSequence(),
    targetId,
    url: payload.url
  };
  await appendEvidence(record);

  return { ok: true };
}

function enqueueCapture(payload: CapturePayload, tabId: number, windowId: number): Promise<{ ok: boolean; deduped?: boolean; error?: string }> {
  const next = captureQueue
    .catch(() => undefined)
    .then(() => handleCaptureEvidence(payload, tabId, windowId));
  captureQueue = next;
  return next;
}

async function collectAiBlocksFromTab(tabId: number): Promise<AiBlock[]> {
  const response: unknown = await chrome.tabs.sendMessage(tabId, { type: messageTypes.collectAiBlocks });
  if (response && typeof response === "object") {
    const data: unknown = Reflect.get(response, "data");
    if (Array.isArray(data)) {
      return data as AiBlock[];
    }
  }
  return [];
}

chrome.runtime.onMessage.addListener((message: unknown, _sender, sendResponse) => {
  if (message && typeof message === "object" && (message as { target?: unknown }).target === "offscreen") {
    return false;
  }

  void (async () => {
    if (!message || typeof message !== "object") {
      sendResponse({ ok: false });
      return;
    }

    const type = "type" in message ? message.type : null;
    const tabId = "tabId" in message && typeof message.tabId === "number" ? message.tabId : null;
    const url = "url" in message && typeof message.url === "string" ? message.url : undefined;

    if (type === messageTypes.applyNetworkRules) {
      sendResponse({
        ok: true,
        data: await enqueueNetworkRulesApply()
      });
      return;
    }

    if (type === messageTypes.updatePickerFocus) {
      const senderTabId = _sender.tab?.id;
      if (typeof senderTabId !== "number") {
        sendResponse({ ok: false });
        return;
      }

      const focused = "focused" in message && typeof message.focused === "boolean" ? message.focused : false;
      const frameScope = "frameScope" in message && typeof message.frameScope === "string" ? message.frameScope : null;
      const label = "label" in message && typeof message.label === "string" ? message.label : "선택 모드 상태 미상";

      pickerFocusByTab.set(senderTabId, {
        focused,
        frameScope,
        label
      });
      sendResponse({ ok: true });
      return;
    }

    if (type === messageTypes.toggleWatchGlobalEnabled) {
      const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
      if (enabled === null) {
        sendResponse({ ok: false });
        return;
      }
      await mutateWatchStore({ enabled, kind: "setGlobalEnabled" });
      sendResponse({ ok: true });
      return;
    }

    if (type === messageTypes.captureEvidence) {
      const tab = _sender.tab;
      const payload = "payload" in message ? (message.payload as CapturePayload) : null;
      if (!tab || typeof tab.id !== "number" || typeof tab.windowId !== "number" || !payload) {
        sendResponse({ ok: false });
        return;
      }
      try {
        sendResponse(await enqueueCapture(payload, tab.id, tab.windowId));
      } catch (error) {
        sendResponse({ error: error instanceof Error ? error.message : "캡처 실패", ok: false });
      }
      return;
    }

    if (type === messageTypes.analyzePageAi) {
      const aiUrl = "url" in message && typeof message.url === "string" ? message.url : null;
      if (tabId === null || aiUrl === null) {
        sendResponse({ ok: false });
        return;
      }
      const outcome = await analyzePageForAi(aiUrl, () => collectAiBlocksFromTab(tabId));
      sendResponse({ ok: true, data: outcome });
      return;
    }

    if (tabId === null) {
      sendResponse({ ok: false });
      return;
    }

    if (type === messageTypes.ensureTabReady) {
      sendResponse({ ok: await ensureTabReady(tabId) });
      return;
    }

    if (type === messageTypes.getPickerFocus) {
      sendResponse({
        ok: true,
        data: pickerFocusByTab.get(tabId) ?? {
          focused: false,
          frameScope: null,
          label: "선택 모드 비활성"
        }
      });
      return;
    }

    if (type === messageTypes.runDiagnostics) {
      if (!isSupportedUrl(url)) {
        sendResponse({
          ok: true,
          data: "진단 결과: 이 페이지는 확장 대상이 아닙니다."
        });
        return;
      }

      const wasReady = await pingTab(tabId);
      if (wasReady) {
        sendResponse({
          ok: true,
          data: "진단 결과: 콘텐츠 스크립트가 이미 연결되어 있습니다."
        });
        return;
      }

      const ready = await ensureTabReady(tabId);
      sendResponse({
        ok: true,
        data: ready
          ? "진단 결과: 콘텐츠 스크립트를 다시 연결했습니다."
          : "진단 결과: 콘텐츠 스크립트 연결에 실패했습니다."
      });
      return;
    }

    if (type === messageTypes.startPickerFlow) {
      if (!isSupportedUrl(url)) {
        sendResponse({
          ok: false,
          data: "이 페이지는 선택 모드를 지원하지 않습니다."
        });
        return;
      }

      const ready = await ensureTabReady(tabId);
      if (!ready) {
        sendResponse({
          ok: false,
          data: "콘텐츠 스크립트를 연결하지 못했습니다."
        });
        return;
      }

      await sendMessageToAllFrames(tabId, messageTypes.stopPicker);
      pickerFocusByTab.set(tabId, {
        focused: true,
        frameScope: null,
        label: "메인 문서 선택 중"
      });
      await sendMessageToTopFrame(tabId, messageTypes.startPicker);
      sendResponse({ ok: true });
      return;
    }

    sendResponse({ ok: false });
  })().catch((error: unknown) => {
    console.warn("인포커터 백그라운드 메시지 처리에 실패했습니다", error);
    sendResponse({ ok: false });
  });

  return true;
});

chrome.webNavigation.onCompleted.addListener((details) => {
  if (details.frameId !== 0) {
    return;
  }
  const url = details.url;
  if (!/^https?:\/\//.test(url)) {
    return;
  }
  void (async () => {
    const config = await readAiConfig();
    const store = await readAiRuleStore();
    if (!decideAiAnalysis(config, store).proceed) {
      return;
    }
    if (isHostAnalyzed(config, hostnameFromUrl(url))) {
      return;
    }
    await analyzePageForAi(url, () => collectAiBlocksFromTab(details.tabId));
  })().catch((error: unknown) => {
    console.warn("인포커터 AI 자동 분석에 실패했습니다", error);
  });
});

chrome.tabs.onActivated.addListener(({ tabId }) => {
  void chrome.tabs.get(tabId)
    .then(async (tab) => {
      await updateBadgeForTab(tabId, tab.url);
    })
    .catch((error: unknown) => {
      if (isMissingTabError(error)) {
        pickerFocusByTab.delete(tabId);
        return;
      }

      console.warn("인포커터 활성 탭 배지 갱신에 실패했습니다", error);
    });
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === "complete" || changeInfo.url) {
    void updateBadgeForTab(tabId, tab.url).catch((error: unknown) => {
      if (isMissingTabError(error)) {
        pickerFocusByTab.delete(tabId);
        return;
      }

      console.warn("인포커터 탭 업데이트 배지 갱신에 실패했습니다", error);
    });
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  pickerFocusByTab.delete(tabId);
});

chrome.storage.onChanged.addListener((_changes, areaName) => {
  if (areaName !== "local") {
    return;
  }

  if (NETWORK_RULE_STORAGE_KEY in _changes) {
    void enqueueNetworkRulesApply().catch((error: unknown) => {
      console.warn("인포커터 네트워크 규칙 재적용에 실패했습니다", error);
    });
  }

  void chrome.tabs.query({})
    .then(async (tabs) => {
      await Promise.all(
        tabs
          .filter((tab): tab is chrome.tabs.Tab & { id: number } => tab.id !== undefined)
          .map(async (tab) => updateBadgeForTab(tab.id, tab.url))
      );
    })
    .catch((error: unknown) => {
      console.warn("인포커터 저장소 변경 후 배지 재계산에 실패했습니다", error);
    });
});

chrome.commands.onCommand.addListener((command, tab) => {
  void (async () => {
    const tabId = tab.id;
    const url = tab.url ?? "";
    if (typeof tabId !== "number" || !isSupportedUrl(url)) {
      return;
    }

    const ready = await ensureTabReady(tabId);
    if (!ready) {
      return;
    }

    if (command === commandIds.launchPicker) {
      await sendMessageToAllFrames(tabId, messageTypes.stopPicker);
      pickerFocusByTab.set(tabId, {
        focused: true,
        frameScope: null,
        label: "메인 문서 선택 중"
      });
      await sendMessageToTopFrame(tabId, messageTypes.startPicker);
      return;
    }

    if (command === commandIds.togglePeek) {
      await sendMessageToAllFrames(tabId, messageTypes.togglePeek);
      return;
    }

    const toggleMessage = toggleCommandMessage(command);
    if (!toggleMessage) {
      return;
    }

    const store = await readStore();
    if (command === commandIds.toggleGlobal) {
      await sendToggleToTopFrame(tabId, toggleMessage, !store.settings.globalEnabled);
      return;
    }

    if (command === commandIds.toggleSiteProfile) {
      const profile = findMatchingProfile(store, url);
      await sendToggleToTopFrame(tabId, toggleMessage, !(profile?.enabled ?? true));
    }
  })().catch((error: unknown) => {
    console.warn("인포커터 단축키 처리에 실패했습니다", error);
  });
});
