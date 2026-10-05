import { messageTypes } from "../shared/messages.js";
import { readNetworkRuleStore, removeNetworkRule, setNetworkRuleEnabled, updateNetworkRuleRaw } from "../shared/network-rules.js";
import { filterImportStatusElement, networkRuleEmptyStateElement, networkRuleListElement } from "./elements.js";
import { requestRender } from "./render-bus.js";
import { createSiteCardShell } from "./site-card-dom.js";

type NetworkRuleApplyData = {
  addedRuleCount: number;
  removedRuleCount: number;
};

function parseNetworkRuleApplyResponse(response: unknown): NetworkRuleApplyData | null {
  if (!response || typeof response !== "object" || !("ok" in response) || response.ok !== true) {
    return null;
  }

  const data = "data" in response ? response.data : null;
  if (!data || typeof data !== "object") {
    return null;
  }

  const addedRuleCount = "addedRuleCount" in data && typeof data.addedRuleCount === "number"
    ? data.addedRuleCount
    : null;
  const removedRuleCount = "removedRuleCount" in data && typeof data.removedRuleCount === "number"
    ? data.removedRuleCount
    : null;

  return addedRuleCount !== null && removedRuleCount !== null
    ? { addedRuleCount, removedRuleCount }
    : null;
}

export async function applyNetworkRulesNow(): Promise<NetworkRuleApplyData> {
  const response = await chrome.runtime.sendMessage({
    type: messageTypes.applyNetworkRules
  }) as unknown;
  const data = parseNetworkRuleApplyResponse(response);
  if (!data) {
    throw new Error("네트워크 규칙 적용에 실패했습니다.");
  }

  return data;
}

function networkRuleConditionLabel(rule: Awaited<ReturnType<typeof readNetworkRuleStore>>["rules"][number]): string {
  const condition = rule.rule.condition;
  const target = condition.urlFilter ?? condition.regexFilter ?? "조건 없음";
  const targetType = condition.regexFilter ? "regex" : "url";
  const resources = condition.resourceTypes?.join(", ") ?? condition.excludedResourceTypes?.map((type) => `~${type}`).join(", ") ?? "전체 리소스";
  const domains = condition.initiatorDomains?.join(", ") ?? "모든 시작 도메인";
  return `${rule.rule.action.type === "allow" ? "허용" : "차단"} · ${targetType}: ${target} · ${resources} · ${domains}`;
}

export function renderNetworkRules(networkStore: Awaited<ReturnType<typeof readNetworkRuleStore>>): void {
  const cards = networkStore.rules.map((rule) => {
    const { card, header, headingWrap, title, subtitle } = createSiteCardShell(
      `네트워크 규칙 #${rule.id}`,
      `${rule.enabled ? "활성" : "비활성"} · ${networkRuleConditionLabel(rule)} · 갱신 ${rule.updatedAt}`
    );

    const actions = document.createElement("div");
    actions.className = "options__site-actions";

    const toggleButton = document.createElement("button");
    toggleButton.type = "button";
    toggleButton.className = "options__secondary";
    toggleButton.textContent = rule.enabled ? "네트워크 규칙 끄기" : "네트워크 규칙 켜기";
    toggleButton.addEventListener("click", () => {
      void (async () => {
        await setNetworkRuleEnabled(rule.id, !rule.enabled);
        await applyNetworkRulesNow();
        await requestRender();
      })().catch((error: unknown) => {
        filterImportStatusElement.textContent = error instanceof Error ? error.message : "네트워크 규칙 상태 변경에 실패했습니다.";
      });
    });

    const deleteButton = document.createElement("button");
    deleteButton.type = "button";
    deleteButton.textContent = "네트워크 규칙 삭제";
    deleteButton.addEventListener("click", () => {
      void (async () => {
        await removeNetworkRule(rule.id);
        await applyNetworkRulesNow();
        await requestRender();
      })().catch((error: unknown) => {
        filterImportStatusElement.textContent = error instanceof Error ? error.message : "네트워크 규칙 삭제에 실패했습니다.";
      });
    });

    actions.append(toggleButton, deleteButton);
    headingWrap.append(title, subtitle);
    header.append(headingWrap, actions);

    const editor = document.createElement("textarea");
    editor.className = "options__input options__rule-editor";
    editor.value = rule.raw;

    const saveButton = document.createElement("button");
    saveButton.type = "button";
    saveButton.className = "options__secondary";
    saveButton.textContent = "네트워크 규칙 저장";
    saveButton.addEventListener("click", () => {
      void (async () => {
        await updateNetworkRuleRaw(rule.id, editor.value);
        const applyData = await applyNetworkRulesNow();
        filterImportStatusElement.textContent = `네트워크 규칙을 저장했습니다. DNR ${applyData.addedRuleCount}개 적용 중입니다.`;
        await requestRender();
      })().catch((error: unknown) => {
        filterImportStatusElement.textContent = error instanceof Error ? error.message : "네트워크 규칙 저장에 실패했습니다.";
      });
    });

    const ruleActions = document.createElement("div");
    ruleActions.className = "options__rule-actions";
    ruleActions.append(saveButton);
    card.append(header, editor, ruleActions);
    return card;
  });

  networkRuleListElement.replaceChildren(...cards);
  networkRuleEmptyStateElement.hidden = cards.length > 0;
}
