import * as popupElements from "./elements.js";
import { messageTypes } from "../shared/messages.js";
import { frameScopeLabel } from "../../packages/infocutter-selector-rules/src/index.js";
import type { ActiveSiteState, ActiveTextBlockState } from "../shared/types.js";
import { readWatchStore } from "../shared/watch-storage.js";
import { listEvidence } from "../shared/evidence-db.js";

const {
  analyzeAiButtonElement,
  clearButtonElement,
  debugButtonElement,
  debugSummaryElement,
  emptyStateElement,
  globalStateElement,
  manageButtonElement,
  pickButtonElement,
  pickerStateElement,
  profileMatchersElement,
  profileNameElement,
  refreshButtonElement,
  ruleCountElement,
  ruleListElement,
  siteLabelElement,
  siteStateElement,
  statusElement,
  textBlockMatchersElement,
  textBlockProfileNameElement,
  textBlockStateElement,
  toggleGlobalButtonElement,
  toggleSiteButtonElement,
  toggleTextBlockGlobalButtonElement,
  toggleTextBlockProfileButtonElement,
  watchGlobalToggleElement,
  watchStatusElement
} = popupElements;

type ActiveTab = chrome.tabs.Tab & { id: number };
type MessagePayload = {
  cardId?: string;
  createdAt?: string;
  enabled?: boolean;
  frameScope?: string | null;
  mode?: "hide" | "unhide";
  profileId?: string | null;
  selector?: string;
};

function isSupportedUrl(url?: string): boolean {
  return typeof url === "string" && /^https?:\/\//.test(url);
}

function setUnsupportedState(url?: string): void {
  siteLabelElement.textContent = url ?? "지원되지 않는 페이지";
  ruleCountElement.textContent = "인포커터는 일반 http, https 웹페이지에서만 동작합니다.";
  siteStateElement.textContent = "이 페이지는 수정할 수 없습니다";
  globalStateElement.textContent = "선택 모드는 일반 웹사이트에서만 사용할 수 있습니다";
  textBlockProfileNameElement.textContent = "텍스트 프로필을 사용할 수 없습니다";
  textBlockMatchersElement.textContent = "텍스트 기반 블록 숨김도 일반 웹사이트에서만 동작합니다";
  textBlockStateElement.textContent = "이 페이지는 텍스트 규칙 적용 대상이 아닙니다";
  pickButtonElement.disabled = true;
  toggleSiteButtonElement.disabled = true;
  toggleGlobalButtonElement.disabled = true;
  clearButtonElement.disabled = true;
  toggleTextBlockProfileButtonElement.disabled = true;
  toggleTextBlockGlobalButtonElement.disabled = true;
  ruleListElement.replaceChildren();
  emptyStateElement.hidden = false;
  emptyStateElement.textContent = "Chrome 내부 페이지와 웹스토어는 확장 기능 적용 대상이 아닙니다.";
}

async function getActiveTab(): Promise<ActiveTab> {
  return new Promise((resolve, reject) => {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const error = chrome.runtime.lastError;
      if (error) {
        reject(new Error(error.message));
        return;
      }

      const [tab] = tabs;
      if (tab?.id === undefined) {
        reject(new Error("현재 활성 탭을 찾을 수 없습니다."));
        return;
      }

      resolve(tab as ActiveTab);
    });
  });
}

function settleChromeResponse(
  response: unknown,
  resolve: (value: object) => void,
  reject: (reason: Error) => void,
  invalidResponseMessage: string
): void {
  const error = chrome.runtime.lastError;
  if (error) {
    reject(new Error(error.message));
    return;
  }

  if (!response || typeof response !== "object") {
    reject(new Error(invalidResponseMessage));
    return;
  }

  resolve(response);
}

async function sendMessageToTab(
  tabId: number,
  type: string,
  payload?: MessagePayload
): Promise<{ ok: boolean; data?: unknown }> {
  return new Promise((resolve, reject) => {
    chrome.tabs.sendMessage(tabId, { type, ...payload }, (response: unknown) => {
      settleChromeResponse(response, resolve as (value: object) => void, reject, `메시지 처리에 실패했습니다: ${type}`);
    });
  });
}

async function sendMessageToTabWithRetry(
  tabId: number,
  type: string,
  payload?: MessagePayload
): Promise<{ ok: boolean; data?: unknown }> {
  try {
    return await sendMessageToTab(tabId, type, payload);
  } catch (error) {
    if (!(error instanceof Error) || !error.message.includes("Receiving end does not exist")) {
      throw error;
    }

    await ensureConnectedTab(tabId);
    await new Promise((resolve) => {
      setTimeout(resolve, 120);
    });
    return sendMessageToTab(tabId, type, payload);
  }
}

async function sendRuntimeMessage<T>(message: Record<string, unknown>): Promise<T> {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendMessage(message, (response: unknown) => {
      settleChromeResponse(response, resolve as (value: object) => void, reject, "백그라운드 메시지 처리에 실패했습니다.");
    });
  });
}

async function ensureConnectedTab(tabId: number): Promise<void> {
  const response = await sendRuntimeMessage<{ ok: boolean }>({
    type: messageTypes.ensureTabReady,
    tabId
  });

  if (response.ok) {
    return;
  }

  throw new Error("콘텐츠 스크립트를 연결하지 못했습니다.");
}

async function runDiagnostics(): Promise<void> {
  const tab = await getActiveTab();
  if (!isSupportedUrl(tab.url)) {
    debugSummaryElement.textContent = "진단 결과: 이 페이지는 확장 대상이 아닙니다.";
    return;
  }

  const response = await sendRuntimeMessage<{ ok: boolean; data?: string }>({
    type: messageTypes.runDiagnostics,
    tabId: tab.id,
    url: tab.url
  });

  debugSummaryElement.textContent = response.data ?? "진단 결과를 확인하지 못했습니다.";
}

async function refreshPickerFocus(tabId: number): Promise<void> {
  const response = await sendRuntimeMessage<{ ok: boolean; data?: { focused: boolean; frameScope: string | null; label: string } }>({
    type: messageTypes.getPickerFocus,
    tabId
  });

  pickerStateElement.textContent = response.data?.label ?? "선택 모드 상태를 확인하지 못했습니다.";
}

async function askContentScript<T>(type: string): Promise<T> {
  const tab = await getActiveTab();
  await ensureConnectedTab(tab.id);
  const response = await sendMessageToTabWithRetry(tab.id, type);

  if (!response.ok || response.data === undefined) {
    throw new Error(`메시지 처리에 실패했습니다: ${type}`);
  }

  return response.data as T;
}

async function mutateContentScript<T>(type: string, payload?: MessagePayload): Promise<T> {
  const tab = await getActiveTab();
  await ensureConnectedTab(tab.id);
  const response = await sendMessageToTabWithRetry(tab.id, type, payload);

  if (!response.ok || response.data === undefined) {
    throw new Error(`메시지 처리에 실패했습니다: ${type}`);
  }

  return response.data as T;
}

function buildRuleList(state: ActiveSiteState): void {
  const buildSectionTitle = (text: string): HTMLDivElement => {
    const title = document.createElement("div");
    title.className = "popup__meta";
    title.style.marginBottom = "6px";
    title.style.fontWeight = "700";
    title.textContent = text;
    return title;
  };

  const createCardItem = (card: ActiveSiteState["cards"][number]): HTMLLIElement => {
    const item = document.createElement("li");
    item.className = "popup__rule-item";
    if (!card.enabled) {
      item.style.opacity = "0.7";
    }

    const cardTitle = document.createElement("div");
    cardTitle.className = "popup__meta";
    cardTitle.style.fontWeight = "700";
    cardTitle.textContent = `카드: ${card.cardName}`;

    const summary = document.createElement("div");
      summary.className = "popup__meta";
    summary.textContent = `${card.mode === "unhide" ? "예외" : "숨김"} 규칙 ${card.ruleCount}개 · 카드 ID ${card.cardId} · ${card.enabled ? "활성" : "비활성"}`;

    const list = document.createElement("div");
    list.style.display = "grid";
    list.style.gap = "6px";

    for (const rule of card.rules) {
      const scopeText = document.createElement("div");
      scopeText.className = "popup__meta";
      scopeText.textContent = frameScopeLabel(rule.frameScope);

      const selectorText = document.createElement("code");
      selectorText.className = "popup__rule-selector";
      selectorText.textContent = `${rule.mode === "unhide" ? "[예외] " : ""}${rule.selector}`;

      const row = document.createElement("div");
      row.style.padding = "8px";
      row.style.background = "rgba(255,255,255,0.06)";

      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.className = "popup__rule-remove";
      removeButton.textContent = "삭제";
      removeButton.addEventListener("click", () => {
        void (async () => {
          const nextState = await mutateContentScript<ActiveSiteState>(messageTypes.removeSiteRule, {
            cardId: rule.cardId,
            createdAt: rule.createdAt,
            frameScope: rule.frameScope,
            mode: rule.mode,
            profileId: state.activeProfileId,
            selector: rule.selector
          });
          renderState(nextState);
          statusElement.textContent = "선택자를 삭제했습니다.";
        })().catch((error: unknown) => {
          statusElement.textContent = error instanceof Error ? error.message : "선택자 삭제에 실패했습니다.";
        });
      });

      row.append(scopeText, selectorText, removeButton);
      list.append(row);
    }

    item.append(cardTitle, summary, list);
    return item;
  };

  const enabledCards = state.cards.filter((card) => card.enabled);
  const disabledCards = state.cards.filter((card) => !card.enabled);
  const items: HTMLElement[] = [];

  if (enabledCards.length > 0) {
    items.push(buildSectionTitle(`활성 카드 ${enabledCards.length}개`));
    for (const card of enabledCards) {
      items.push(createCardItem(card));
    }
  }

  if (disabledCards.length > 0) {
    items.push(buildSectionTitle(`비활성 카드 ${disabledCards.length}개`));
    for (const card of disabledCards) {
      items.push(createCardItem(card));
    }
  }

  ruleListElement.replaceChildren(...items);
  emptyStateElement.hidden = items.length > 0;
}

function renderTextBlockState(state: ActiveTextBlockState): void {
  const profileStateLabel = state.activeProfileId === null
    ? "매칭된 텍스트 프로필 없음"
    : state.profileEnabled
      ? "현재 텍스트 프로필 사용 중"
      : "현재 텍스트 프로필 꺼짐";
  textBlockProfileNameElement.textContent = state.activeProfileName
    ? `텍스트 프로필: ${state.activeProfileName}`
    : "텍스트 프로필: 현재 URL에 매칭된 텍스트 프로필이 없습니다";
  textBlockMatchersElement.textContent = state.matchers.length > 0
    ? `텍스트 매처: ${state.matchers.join(", ")}`
    : "텍스트 매처: 저장된 텍스트 매처가 없습니다";
  textBlockStateElement.textContent =
    `텍스트 규칙 ${state.ruleCount}개 · ${profileStateLabel} · ${state.globalEnabled ? "전체 켜짐" : "전체 꺼짐"}`;
  toggleTextBlockProfileButtonElement.textContent = state.activeProfileId === null
    ? "텍스트 프로필 없음"
    : state.profileEnabled
      ? "텍스트 프로필 끄기"
      : "텍스트 프로필 켜기";
  toggleTextBlockProfileButtonElement.disabled = state.activeProfileId === null;
  toggleTextBlockGlobalButtonElement.textContent = state.globalEnabled
    ? "텍스트 규칙 전체 끄기"
    : "텍스트 규칙 전체 켜기";
  toggleTextBlockGlobalButtonElement.disabled = false;
}

function renderState(state: ActiveSiteState): void {
  const enabledCardCount = state.cards.filter((card) => card.enabled).length;
  siteLabelElement.textContent = state.activeProfileName
    ? `${state.hostname} · ${state.activeProfileName}`
    : `${state.hostname} · 기본 프로필`;
  ruleCountElement.textContent = `저장된 카드 ${state.cardCount}개 · 활성 카드 ${enabledCardCount}개 · 활성 선택자 ${state.enabledSelectorCount}개 / 전체 선택자 ${state.selectorCount}개 · 활성 예외 ${state.enabledExceptionCount}개 / 전체 예외 ${state.exceptionCount}개`;
  profileNameElement.textContent = state.activeProfileName
    ? `현재 프로필: ${state.activeProfileName}`
    : "현재 프로필: 아직 매칭된 프로필이 없습니다";
  profileMatchersElement.textContent = state.matchers.length > 0
    ? `매처: ${state.matchers.join(", ")}`
    : "매처: 기본 hostname 프로필이 아직 만들어지지 않았습니다";
  siteStateElement.textContent = state.profileEnabled ? "현재 프로필 사용 중" : "현재 프로필 꺼짐";
  globalStateElement.textContent = state.globalEnabled ? "확장 기능이 켜져 있음" : "확장 기능이 전체 꺼짐";
  toggleSiteButtonElement.textContent = state.profileEnabled ? "현재 프로필 끄기" : "현재 프로필 켜기";
  toggleGlobalButtonElement.textContent = state.globalEnabled ? "전체 끄기" : "전체 켜기";
  pickButtonElement.disabled = !state.globalEnabled;
  buildRuleList(state);
}

async function refreshWatchState(): Promise<void> {
  const [store, evidenceList] = await Promise.all([
    readWatchStore(),
    listEvidence()
  ]);
  watchGlobalToggleElement.checked = store.settings.globalEnabled;
  watchStatusElement.textContent = `등록 ${store.targets.length}건 · 저장된 증거 ${evidenceList.length}건`;
}

async function refreshState(): Promise<void> {
  statusElement.textContent = "";
  const tab = await getActiveTab();
  if (!isSupportedUrl(tab.url)) {
    setUnsupportedState(tab.url);
    debugSummaryElement.textContent = "진단 결과: chrome 내부 페이지라 콘텐츠 스크립트를 붙일 수 없습니다.";
    pickerStateElement.textContent = "선택 포커스 없음";
    return;
  }

  debugSummaryElement.textContent = "진단 결과: 콘텐츠 스크립트 연결 상태를 확인하는 중...";
  await ensureConnectedTab(tab.id);
  debugSummaryElement.textContent = "진단 결과: 콘텐츠 스크립트 연결됨.";
  await refreshPickerFocus(tab.id);
  const [state, textBlockState] = await Promise.all([
    askContentScript<ActiveSiteState>(messageTypes.getPageState),
    askContentScript<ActiveTextBlockState>(messageTypes.getTextBlockState)
  ]);
  renderState(state);
  renderTextBlockState(textBlockState);
}

pickButtonElement.addEventListener("click", () => {
  void (async () => {
    const tab = await getActiveTab();
    const response = await sendRuntimeMessage<{ ok: boolean; data?: string }>({
      type: messageTypes.startPickerFlow,
      tabId: tab.id,
      url: tab.url
    });
    if (!response.ok) {
      throw new Error(response.data ?? "선택 모드 시작에 실패했습니다.");
    }
    await refreshPickerFocus(tab.id);
    statusElement.textContent = "선택 모드를 시작했습니다. 페이지로 돌아가서 숨길 요소를 클릭하세요.";
  })().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "선택 모드 시작에 실패했습니다.";
  });
});

debugButtonElement.addEventListener("click", () => {
  void runDiagnostics().catch((error: unknown) => {
    debugSummaryElement.textContent = error instanceof Error ? error.message : "진단 실행에 실패했습니다.";
  });
});

manageButtonElement.addEventListener("click", () => {
  void chrome.runtime.openOptionsPage();
});

toggleSiteButtonElement.addEventListener("click", () => {
  void (async () => {
    const currentState = await askContentScript<ActiveSiteState>(messageTypes.getPageState);
    const nextState = await mutateContentScript<ActiveSiteState>(messageTypes.toggleSiteEnabled, {
      enabled: !currentState.profileEnabled
    });
    renderState(nextState);
    statusElement.textContent = nextState.profileEnabled ? "현재 프로필을 다시 켰습니다." : "현재 프로필을 껐습니다.";
  })().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "사이트 상태 변경에 실패했습니다.";
  });
});

toggleGlobalButtonElement.addEventListener("click", () => {
  void (async () => {
    const currentState = await askContentScript<ActiveSiteState>(messageTypes.getPageState);
    const nextState = await mutateContentScript<ActiveSiteState>(messageTypes.toggleGlobalEnabled, {
      enabled: !currentState.globalEnabled
    });
    renderState(nextState);
    statusElement.textContent = nextState.globalEnabled ? "확장 기능을 전체 켰습니다." : "확장 기능을 전체 껐습니다.";
  })().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "전체 상태 변경에 실패했습니다.";
  });
});

toggleTextBlockProfileButtonElement.addEventListener("click", () => {
  void (async () => {
    const currentState = await askContentScript<ActiveTextBlockState>(messageTypes.getTextBlockState);
    if (!currentState.activeProfileId) {
      throw new Error("현재 URL에는 매칭된 텍스트 프로필이 없습니다.");
    }

    const nextState = await mutateContentScript<ActiveTextBlockState>(messageTypes.toggleTextBlockProfileEnabled, {
      enabled: !currentState.profileEnabled
    });
    renderTextBlockState(nextState);
    statusElement.textContent = nextState.profileEnabled
      ? "텍스트 프로필을 다시 켰습니다."
      : "텍스트 프로필을 껐습니다.";
  })().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "텍스트 프로필 상태 변경에 실패했습니다.";
  });
});

toggleTextBlockGlobalButtonElement.addEventListener("click", () => {
  void (async () => {
    const currentState = await askContentScript<ActiveTextBlockState>(messageTypes.getTextBlockState);
    const nextState = await mutateContentScript<ActiveTextBlockState>(messageTypes.toggleTextBlockGlobalEnabled, {
      enabled: !currentState.globalEnabled
    });
    renderTextBlockState(nextState);
    statusElement.textContent = nextState.globalEnabled
      ? "텍스트 기반 블록 숨김을 전체 켰습니다."
      : "텍스트 기반 블록 숨김을 전체 껐습니다.";
  })().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "텍스트 전역 상태 변경에 실패했습니다.";
  });
});

watchGlobalToggleElement.addEventListener("change", () => {
  void (async () => {
    const response = await sendRuntimeMessage<{ ok: boolean }>({
      type: messageTypes.toggleWatchGlobalEnabled,
      enabled: watchGlobalToggleElement.checked
    });
    if (!response.ok) {
      throw new Error("이름 감시 전역 상태 변경에 실패했습니다.");
    }
    statusElement.textContent = watchGlobalToggleElement.checked
      ? "이름 감시를 켰습니다."
      : "이름 감시를 껐습니다.";
  })().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "이름 감시 상태 변경에 실패했습니다.";
  });
});

refreshButtonElement.addEventListener("click", () => {
  void refreshState().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "새로고침에 실패했습니다.";
  });
});

clearButtonElement.addEventListener("click", () => {
  void (async () => {
    const state = await askContentScript<ActiveSiteState>(messageTypes.clearSiteRules);
    renderState(state);
    statusElement.textContent = "이 사이트 규칙을 모두 삭제했습니다.";
  })().catch((error: unknown) => {
    statusElement.textContent = error instanceof Error ? error.message : "이 사이트 규칙 삭제에 실패했습니다.";
  });
});

function describeAiOutcome(outcome: unknown): string {
  if (outcome && typeof outcome === "object") {
    const status: unknown = Reflect.get(outcome, "status");
    if (status === "ok") {
      const count: unknown = Reflect.get(outcome, "count");
      const n = typeof count === "number" ? count : 0;
      return n > 0 ? `자극 영역 ${n}곳을 가렸습니다.` : "가릴 영역을 찾지 못했습니다.";
    }
    if (status === "skipped") {
      const reason: unknown = Reflect.get(outcome, "reason");
      if (reason === "no-api-key") return "옵션에서 API 키를 먼저 입력하세요.";
      if (reason === "disabled") return "옵션에서 AI 자동 가림을 먼저 켜세요.";
      if (reason === "no-categories") return "옵션에서 가릴 카테고리를 한 개 이상 고르세요.";
      if (reason === "no-blocks") return "분석할 콘텐츠를 찾지 못했습니다.";
    }
  }
  return "분석을 완료했습니다.";
}

analyzeAiButtonElement.addEventListener("click", () => {
  void (async () => {
    try {
      statusElement.textContent = "자극 영역을 분석하는 중...";
      const tab = await getActiveTab();
      if (!isSupportedUrl(tab.url)) {
        statusElement.textContent = "이 페이지에서는 분석할 수 없습니다.";
        return;
      }
      const response = await sendRuntimeMessage<{ ok: boolean; data?: unknown }>({
        type: messageTypes.analyzePageAi,
        tabId: tab.id,
        url: tab.url
      });
      statusElement.textContent = response.ok ? describeAiOutcome(response.data) : "분석에 실패했습니다.";
    } catch (error) {
      statusElement.textContent = error instanceof Error ? error.message : "분석에 실패했습니다.";
    }
  })();
});

void refreshState().catch((error: unknown) => {
  statusElement.textContent = error instanceof Error ? error.message : "팝업 초기화에 실패했습니다.";
});

void refreshWatchState().catch((error: unknown) => {
  statusElement.textContent = error instanceof Error ? error.message : "이름 감시 상태를 불러오지 못했습니다.";
});
