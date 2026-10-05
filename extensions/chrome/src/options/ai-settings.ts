import { AI_RULE_CATEGORIES, AI_DETECTION_ENDPOINT_DEFAULT } from "../shared/constants.js";
import type { AiRuleCategory } from "../shared/ai-types.js";
import { readAiConfig, writeAiConfig, resetAnalyzedHosts } from "../shared/ai-config.js";
import { readAiRuleStore, setAiGlobalEnabled, setAiEnabledCategories } from "../shared/ai-rule-storage.js";
import {
  aiGlobalToggleElement, aiStatusElement, aiCategoryListElement,
  aiEndpointElement, aiApiKeyElement, aiModelElement, aiSaveConfigButtonElement
} from "./elements.js";
import { AI_CATEGORY_LABELS } from "./ai-category-labels.js";

function buildCategoryCheckboxes(enabled: AiRuleCategory[]): void {
  aiCategoryListElement.replaceChildren();
  for (const category of AI_RULE_CATEGORIES) {
    const label = document.createElement("label");
    label.className = "options__ai-category";
    const input = document.createElement("input");
    input.type = "checkbox";
    input.value = category;
    input.checked = enabled.includes(category);
    input.addEventListener("change", () => {
      void (async () => {
        const next = Array.from(
          aiCategoryListElement.querySelectorAll<HTMLInputElement>("input[type='checkbox']")
        )
          .filter((box) => box.checked)
          .map((box) => box.value as AiRuleCategory);
        await setAiEnabledCategories(next);
        await resetAnalyzedHosts();
        aiStatusElement.textContent = "카테고리를 저장했습니다.";
      })();
    });
    const span = document.createElement("span");
    span.textContent = AI_CATEGORY_LABELS[category];
    label.append(input, span);
    aiCategoryListElement.append(label);
  }
}

export function wireAiSettings(): void {
  aiGlobalToggleElement.addEventListener("change", () => {
    void (async () => {
      await setAiGlobalEnabled(aiGlobalToggleElement.checked);
      aiStatusElement.textContent = aiGlobalToggleElement.checked ? "AI 자동 가림을 켰습니다." : "AI 자동 가림을 껐습니다.";
    })();
  });

  aiSaveConfigButtonElement.addEventListener("click", () => {
    void (async () => {
      const current = await readAiConfig();
      await writeAiConfig({
        ...current,
        endpoint: aiEndpointElement.value.trim() || AI_DETECTION_ENDPOINT_DEFAULT,
        apiKey: aiApiKeyElement.value.trim(),
        model: aiModelElement.value.trim(),
        analyzedHosts: []
      });
      aiStatusElement.textContent = "연결 설정을 저장했습니다.";
    })();
  });

  void (async () => {
    const config = await readAiConfig();
    const store = await readAiRuleStore();
    aiEndpointElement.value = config.endpoint;
    aiApiKeyElement.value = config.apiKey;
    aiModelElement.value = config.model;
    aiGlobalToggleElement.checked = store.settings.globalEnabled;
    buildCategoryCheckboxes(store.settings.enabledCategories);
    aiStatusElement.textContent = config.apiKey.trim().length === 0
      ? "API 키를 입력하면 AI 자동 가림을 사용할 수 있습니다."
      : "AI 설정을 불러왔습니다.";
  })();
}
