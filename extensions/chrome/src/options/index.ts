import { NETWORK_RULE_STORAGE_KEY, STORAGE_KEY, TEXT_BLOCK_STORAGE_KEY } from "../shared/constants.js";
import { readNetworkRuleStore } from "../shared/network-rules.js";
import { createProfile, deleteProfile, findMatchingProfile, groupRulesByCard, moveProfile, readStore, renameCardInProfile, removeCardFromProfile, renameProfile, setCardEnabled, setProfileMatchers, writeStore } from "../shared/storage.js";
import { readTextBlockStore, setTextBlockGlobalEnabled, setTextBlockHiddenObjectTag, upsertTextBlockProfileRule } from "../shared/text-block-storage.js";
import * as optionsElements from "./elements.js";
import { renderNameWatch, wireNameWatch } from "./name-watch.js";
import { wireAiSettings } from "./ai-settings.js";
import { wireAiRules } from "./ai-rules.js";
import { DEFAULT_TEMPLATE_SERVER_URL, TEMPLATE_SERVER_TOKEN_KEY, TEMPLATE_SERVER_URL_KEY, fetchTemplateJson, profileToTemplate, readTemplateServerToken, readTemplateServerUrl, slugFromProfileName, writeTemplateServerToken, writeTemplateServerUrl } from "./template-server.js";
import { parseObjectTags } from "../../packages/infocutter-text-blocks/src/index.js";
import { frameScopeLabel } from "../../packages/infocutter-selector-rules/src/index.js";
import type { RuleProfile, StoredRule } from "../shared/types.js";
import type { RemoteTemplate } from "./template-server.js";
import { renderNetworkRules } from "./network-rules.js";
import { filterImportSummaryLabel, importSupportedFilterRules } from "./filter-import.js";
import { renderTemplates } from "./template-ui.js";
import { firstNormalizedTag, renderTextBlocks } from "./text-blocks-view.js";
import { clearSelectedPreviewTabIfMatches, getSelectedPreviewTabId, setSelectedPreviewTabId } from "./preview-tab.js";
import { setRenderImpl } from "./render-bus.js";
import { createProfileEditFields, createSecondaryButton, createSiteCardShell } from "./site-card-dom.js";

const {
  createProfileButtonElement,
  emptyStateElement,
  filterImportApplyButtonElement,
  filterImportPreviewButtonElement,
  filterImportStatusElement,
  globalStatusElement,
  newProfileMatcherElement,
  newProfileNameElement,
  refreshButtonElement,
  refreshTemplatesButtonElement,
  scopeFilterElement,
  searchInputElement,
  siteListElement,
  summaryElement,
  templateServerTokenElement,
  templateServerUrlElement,
  templateStatusElement,
  textBlockAddHiddenTagButtonElement,
  textBlockCreateButtonElement,
  textBlockHiddenTagInputElement,
  textBlockKeywordElement,
  textBlockMatcherElement,
  textBlockMinMatchCountElement,
  textBlockObjectNameElement,
  textBlockObjectTagsElement,
  textBlockOpenTabButtonElement,
  textBlockPreviewStatusElement,
  textBlockPreviewTabElement,
  textBlockProfileNameElement,
  textBlockRefreshTabsButtonElement,
  textBlockSummaryElement,
  textBlockToggleAdTagButtonElement,
  textBlockToggleGlobalButtonElement,
  toggleGlobalButtonElement,
  urlTestButtonElement,
  urlTestInputElement,
  urlTestResultElement
} = optionsElements;
let renderScheduled = false;

function scheduleRender(): void {
  if (renderScheduled) {
    return;
  }

  renderScheduled = true;
  queueMicrotask(() => {
    renderScheduled = false;
    void render();
  });
}

function profileMatchersLabel(profile: RuleProfile): string {
  return profile.matchers.join(", ");
}

function matchesScopeFilter(rule: StoredRule, scopeFilterValue: string): boolean {
  if (scopeFilterValue === "main") {
    return rule.frameScope === null;
  }

  if (scopeFilterValue === "iframe") {
    return rule.frameScope !== null;
  }

  return true;
}

function matchesSearch(rule: StoredRule, profile: RuleProfile, keyword: string): boolean {
  if (!keyword) {
    return true;
  }

  return (
    profile.name.toLowerCase().includes(keyword) ||
    profileMatchersLabel(profile).toLowerCase().includes(keyword) ||
    rule.cardName.toLowerCase().includes(keyword) ||
    rule.selector.includes(keyword) ||
    (rule.frameScope?.includes(keyword) ?? false)
  );
}

function matchesProfileSearch(profile: RuleProfile, keyword: string): boolean {
  if (!keyword) {
    return true;
  }

  return (
    profile.name.toLowerCase().includes(keyword) ||
    profileMatchersLabel(profile).toLowerCase().includes(keyword)
  );
}

function isSameStoredRule(rule: StoredRule, targetRule: StoredRule): boolean {
  return (
    rule.cardId === targetRule.cardId &&
    rule.createdAt === targetRule.createdAt &&
    rule.frameScope === targetRule.frameScope &&
    rule.mode === targetRule.mode &&
    rule.selector === targetRule.selector
  );
}

async function updateProfile(profileId: string, updater: (profile: RuleProfile) => RuleProfile): Promise<void> {
  const store = await readStore();
  await writeStore({
    ...store,
    profiles: store.profiles.map((profile) => (
      profile.id === profileId ? updater(profile) : profile
    ))
  });
}

async function deleteRule(profileId: string, targetRule: StoredRule): Promise<void> {
  await updateProfile(profileId, (profile) => ({
    ...profile,
    rules: profile.rules.filter((rule) => !isSameStoredRule(rule, targetRule)),
    updatedAt: new Date().toISOString()
  }));
}

async function editRule(profileId: string, targetRule: StoredRule, selector: string): Promise<void> {
  await updateProfile(profileId, (profile) => ({
    ...profile,
    rules: profile.rules.map((rule) => (
      isSameStoredRule(rule, targetRule)
        ? {
            ...rule,
            selector: selector.trim() || rule.selector
          }
        : rule
    )),
    updatedAt: new Date().toISOString()
  }));
}

async function clearProfile(profileId: string): Promise<void> {
  await updateProfile(profileId, (profile) => ({
    ...profile,
    rules: [],
    updatedAt: new Date().toISOString()
  }));
}

async function toggleProfile(profileId: string): Promise<void> {
  await updateProfile(profileId, (profile) => ({
    ...profile,
    enabled: !profile.enabled,
    updatedAt: new Date().toISOString()
  }));
}

async function render(): Promise<void> {
  const store = await readStore();
  const networkStore = await readNetworkRuleStore();
  const keyword = searchInputElement.value.trim().toLowerCase();
  const scope = scopeFilterElement.value;

  globalStatusElement.textContent = store.settings.globalEnabled ? "전역 상태: 켜짐" : "전역 상태: 꺼짐";
  toggleGlobalButtonElement.textContent = store.settings.globalEnabled ? "전체 끄기" : "전체 켜기";

  const profileCards: HTMLElement[] = [];
  let totalVisibleRules = 0;
  let totalVisibleCards = 0;

  for (const [profileIndex, profile] of store.profiles.entries()) {
    const rules = profile.rules.filter((rule) => matchesScopeFilter(rule, scope) && matchesSearch(rule, profile, keyword));
    const profileMatches = matchesProfileSearch(profile, keyword);
    if (!profileMatches && rules.length === 0) {
      continue;
    }

    totalVisibleRules += rules.length;

    const { card, header, headingWrap, title, subtitle } = createSiteCardShell(
      profile.name,
      `${profile.enabled ? "프로필 사용 중" : "프로필 꺼짐"} · 매처 ${profileMatchersLabel(profile)} · 카드 ${groupRulesByCard(profile.rules, profile.cards).length}개 · 규칙 ${profile.rules.length}개${profile.sourceTemplateSlug ? ` · 템플릿 ${profile.sourceTemplateSlug}` : ""}`
    );

    const priorityBadge = document.createElement("div");
    priorityBadge.className = "options__priority-badge";
    priorityBadge.textContent = `우선순위 ${profileIndex + 1} · 위에 있을수록 먼저 적용`;

    const { editWrap, nameInput, matcherEditor, matcherHint } = createProfileEditFields(
      profile.name,
      profile.matchers.join("\n"),
      [
        "<li>한 줄에 matcher 하나씩 입력</li>",
        "<li>예: https://mail.naver.com/*</li>",
        "<li>* 와일드카드를 사용할 수 있습니다</li>"
      ]
    );

    const actions = document.createElement("div");
    actions.className = "options__site-actions";

    const toggleProfileButton = document.createElement("button");
    toggleProfileButton.type = "button";
    toggleProfileButton.textContent = profile.enabled ? "프로필 끄기" : "프로필 켜기";
    toggleProfileButton.className = "options__secondary";
    toggleProfileButton.addEventListener("click", () => {
      void (async () => {
        await toggleProfile(profile.id);
        await render();
      })();
    });

    const clearProfileButton = document.createElement("button");
    clearProfileButton.type = "button";
    clearProfileButton.textContent = "프로필 규칙 삭제";
    clearProfileButton.addEventListener("click", () => {
      void (async () => {
        await clearProfile(profile.id);
        await render();
      })();
    });

    const moveUpButton = document.createElement("button");
    moveUpButton.type = "button";
    moveUpButton.textContent = "위로";
    moveUpButton.className = "options__secondary";
    moveUpButton.disabled = profileIndex === 0;
    moveUpButton.addEventListener("click", () => {
      void (async () => {
        await moveProfile(profile.id, "up");
        await render();
      })();
    });

    const moveDownButton = document.createElement("button");
    moveDownButton.type = "button";
    moveDownButton.textContent = "아래로";
    moveDownButton.className = "options__secondary";
    moveDownButton.disabled = profileIndex === store.profiles.length - 1;
    moveDownButton.addEventListener("click", () => {
      void (async () => {
        await moveProfile(profile.id, "down");
        await render();
      })();
    });

    const saveTemplateButton = document.createElement("button");
    saveTemplateButton.type = "button";
    saveTemplateButton.textContent = profile.sourceTemplateSlug ? "템플릿 갱신" : "템플릿 등록";
    saveTemplateButton.className = "options__secondary";
    saveTemplateButton.addEventListener("click", () => {
      void (async () => {
        const serverUrl = templateServerUrlElement.value.trim() || DEFAULT_TEMPLATE_SERVER_URL;
        const token = templateServerTokenElement.value;
        const slug = profile.sourceTemplateSlug ?? slugFromProfileName(profile.name);
        const name = profile.name;

        await fetchTemplateJson<{ ok: boolean; template: RemoteTemplate }>(serverUrl, token, "/templates", {
          body: JSON.stringify(profileToTemplate(profile, slug, name)),
          headers: {
            "content-type": "application/json"
          },
          method: profile.sourceTemplateSlug ? "PUT" : "POST"
        });

        templateStatusElement.textContent = profile.sourceTemplateSlug
          ? `${name} 템플릿을 갱신했습니다.`
          : `${name} 템플릿을 등록했습니다.`;
        await renderTemplates();
      })().catch((error: unknown) => {
        templateStatusElement.textContent = error instanceof Error ? error.message : "템플릿 저장에 실패했습니다.";
      });
    });

    const saveProfileButton = document.createElement("button");
    saveProfileButton.type = "button";
    saveProfileButton.textContent = "프로필 저장";
    saveProfileButton.className = "options__secondary";
    saveProfileButton.addEventListener("click", () => {
      void (async () => {
        await renameProfile(profile.id, nameInput.value);
        await setProfileMatchers(profile.id, matcherEditor.value.split("\n"));
        await render();
      })();
    });

    const deleteProfileButton = document.createElement("button");
    deleteProfileButton.type = "button";
    deleteProfileButton.textContent = "프로필 삭제";
    deleteProfileButton.addEventListener("click", () => {
      void (async () => {
        await deleteProfile(profile.id);
        await render();
      })();
    });

    actions.append(moveUpButton, moveDownButton, toggleProfileButton, clearProfileButton, saveTemplateButton, saveProfileButton, deleteProfileButton);
    headingWrap.append(title, subtitle, priorityBadge);
    header.append(headingWrap, actions);
    editWrap.append(nameInput, matcherEditor, matcherHint);

    const list = document.createElement("ul");
    list.className = "options__rule-list";

    const cards = groupRulesByCard(rules, profile.cards);
    totalVisibleCards += cards.length;

    if (cards.length === 0) {
      const emptyCard = document.createElement("li");
      emptyCard.className = "options__rule-item";

      const emptyTitle = document.createElement("p");
      emptyTitle.className = "options__rule-meta";
      emptyTitle.textContent = "이 프로파일에는 아직 카드가 없습니다.";

      const emptyGuide = document.createElement("p");
      emptyGuide.className = "options__rule-meta";
      emptyGuide.textContent = "선택 모드에서 오브젝트를 카드로 추가하면 여기에서 이름과 규칙을 관리할 수 있습니다.";

      emptyCard.append(emptyTitle, emptyGuide);
      list.append(emptyCard);
    }

    for (const cardGroup of cards) {
      const item = document.createElement("li");
      item.className = "options__rule-item";

      const cardNameInput = document.createElement("input");
      cardNameInput.className = "options__input";
      cardNameInput.type = "text";
      cardNameInput.value = cardGroup.cardName;

      const cardMeta = document.createElement("p");
      cardMeta.className = "options__rule-meta";
      cardMeta.textContent = `${cardGroup.mode === "unhide" ? "예외 카드" : "숨김 카드"} · 규칙 ${cardGroup.rules.length}개 · 카드 ID ${cardGroup.cardId} · ${cardGroup.enabled ? "활성" : "비활성"}`;

      const cardActions = document.createElement("div");
      cardActions.className = "options__rule-actions";

      const toggleCardButton = document.createElement("button");
      toggleCardButton.type = "button";
      toggleCardButton.textContent = cardGroup.enabled ? "카드 끄기" : "카드 켜기";
      toggleCardButton.className = "options__secondary";
      toggleCardButton.addEventListener("click", () => {
        void (async () => {
          await setCardEnabled(profile.id, cardGroup.cardId, !cardGroup.enabled);
          await render();
        })();
      });

      const saveCardButton = document.createElement("button");
      saveCardButton.type = "button";
      saveCardButton.textContent = "카드 이름 저장";
      saveCardButton.className = "options__secondary";
      saveCardButton.addEventListener("click", () => {
        void (async () => {
          await renameCardInProfile(profile.id, cardGroup.cardId, cardNameInput.value);
          await render();
        })();
      });

      const deleteCardButton = document.createElement("button");
      deleteCardButton.type = "button";
      deleteCardButton.textContent = "카드 삭제";
      deleteCardButton.className = "options__secondary";
      deleteCardButton.addEventListener("click", () => {
        void (async () => {
          await removeCardFromProfile(profile.id, cardGroup.cardId);
          await render();
        })();
      });

      cardActions.append(toggleCardButton, saveCardButton, deleteCardButton);
      item.append(cardNameInput, cardMeta, cardActions);

      const innerList = document.createElement("div");
      innerList.style.display = "grid";
      innerList.style.gap = "10px";
      innerList.style.marginTop = "10px";

      for (const rule of cardGroup.rules) {
        const ruleWrap = document.createElement("div");
        ruleWrap.style.padding = "10px";
        ruleWrap.style.background = "rgba(255,255,255,0.06)";

        const scopeText = document.createElement("p");
        scopeText.className = "options__rule-scope";
        scopeText.textContent = `${rule.mode === "unhide" ? "예외" : "숨김"} · ${frameScopeLabel(rule.frameScope)}`;

        const metaText = document.createElement("p");
        metaText.className = "options__rule-meta";
        metaText.textContent = `생성 시각: ${rule.createdAt}`;

        const code = document.createElement("textarea");
        code.className = "options__input options__rule-editor";
        code.value = rule.selector;

        const actions = document.createElement("div");
        actions.className = "options__rule-actions";

        const saveButton = document.createElement("button");
        saveButton.type = "button";
        saveButton.textContent = "저장";
        saveButton.className = "options__secondary";
        saveButton.addEventListener("click", () => {
          void (async () => {
            await editRule(profile.id, rule, code.value);
            await render();
          })();
        });

        const deleteButton = createSecondaryButton("삭제", async () => {
          await deleteRule(profile.id, rule);
          await render();
        });

        actions.append(saveButton, deleteButton);
        ruleWrap.append(scopeText, metaText, code, actions);
        innerList.append(ruleWrap);
      }

      item.append(innerList);
      list.append(item);
    }

    card.append(header, editWrap, list);
    profileCards.push(card);
  }

  siteListElement.replaceChildren(...profileCards);
  emptyStateElement.hidden = profileCards.length > 0;
  const enabledNetworkRuleCount = networkStore.rules.filter((rule) => rule.enabled).length;
  summaryElement.textContent = `표시 중인 프로필 ${profileCards.length}개 / 카드 ${totalVisibleCards}개 / 규칙 ${totalVisibleRules}개 / 네트워크 ${enabledNetworkRuleCount}/${networkStore.rules.length}개`;
  renderNetworkRules(networkStore);
  await renderTextBlocks(keyword);

  const testUrl = urlTestInputElement.value.trim();
  if (testUrl) {
    try {
      const matchedProfile = findMatchingProfile(store, testUrl);
      urlTestResultElement.textContent = matchedProfile
        ? `매칭 결과: ${matchedProfile.name} (${matchedProfile.matchers.join(", ")})`
        : "매칭 결과: 일치하는 프로필이 없습니다.";
    } catch {
      urlTestResultElement.textContent = "매칭 결과: URL 형식이 올바르지 않습니다.";
    }
  }
}

setRenderImpl(render, renderTemplates);

refreshButtonElement.addEventListener("click", () => {
  void render();
  void renderTemplates();
});

toggleGlobalButtonElement.addEventListener("click", () => {
  void (async () => {
    const store = await readStore();
    await writeStore({
      ...store,
      settings: {
        globalEnabled: !store.settings.globalEnabled
      }
    });
    await render();
  })();
});

createProfileButtonElement.addEventListener("click", () => {
  void (async () => {
    await createProfile(newProfileNameElement.value, newProfileMatcherElement.value);
    newProfileNameElement.value = "";
    newProfileMatcherElement.value = "";
    await render();
  })();
});

textBlockCreateButtonElement.addEventListener("click", () => {
  void (async () => {
    if (!textBlockMatcherElement.value.trim() || !textBlockKeywordElement.value.trim()) {
      textBlockSummaryElement.textContent = "텍스트 matcher와 키워드를 함께 입력하세요.";
      return;
    }

    await upsertTextBlockProfileRule({
      keyword: textBlockKeywordElement.value,
      matcher: textBlockMatcherElement.value,
      minMatchCount: Number.parseInt(textBlockMinMatchCountElement.value, 10) || 2,
      objectName: textBlockObjectNameElement.value,
      objectTags: parseObjectTags(textBlockObjectTagsElement.value),
      profileName: textBlockProfileNameElement.value
    });
    textBlockProfileNameElement.value = "";
    textBlockMatcherElement.value = "";
    textBlockObjectNameElement.value = "";
    textBlockObjectTagsElement.value = "";
    textBlockKeywordElement.value = "";
    textBlockMinMatchCountElement.value = "2";
    await render();
  })();
});

filterImportPreviewButtonElement.addEventListener("click", () => {
  filterImportStatusElement.textContent = `가져오기 미리보기 · ${filterImportSummaryLabel()}`;
});

filterImportApplyButtonElement.addEventListener("click", () => {
  void (async () => {
    await importSupportedFilterRules();
    await render();
  })().catch((error: unknown) => {
    filterImportStatusElement.textContent = error instanceof Error ? error.message : "필터 가져오기에 실패했습니다.";
  });
});

textBlockToggleGlobalButtonElement.addEventListener("click", () => {
  void (async () => {
    const store = await readTextBlockStore();
    await setTextBlockGlobalEnabled(!store.settings.globalEnabled);
    await render();
  })();
});

textBlockToggleAdTagButtonElement.addEventListener("click", () => {
  void (async () => {
    const store = await readTextBlockStore();
    await setTextBlockHiddenObjectTag("ad", !store.settings.hiddenObjectTags.includes("ad"));
    await render();
  })();
});

textBlockAddHiddenTagButtonElement.addEventListener("click", () => {
  void (async () => {
    const tag = firstNormalizedTag(textBlockHiddenTagInputElement.value);
    if (!tag) {
      textBlockPreviewStatusElement.textContent = "추가할 숨김 태그를 영문/숫자/하이픈/언더스코어로 입력하세요.";
      return;
    }

    await setTextBlockHiddenObjectTag(tag, true);
    textBlockHiddenTagInputElement.value = "";
    await render();
  })();
});

textBlockPreviewTabElement.addEventListener("change", () => {
  const nextValue = Number.parseInt(textBlockPreviewTabElement.value, 10);
  setSelectedPreviewTabId(Number.isFinite(nextValue) ? nextValue : null);
  scheduleRender();
});

textBlockRefreshTabsButtonElement.addEventListener("click", () => {
  scheduleRender();
});

textBlockOpenTabButtonElement.addEventListener("click", () => {
  const selectedPreviewTabId = getSelectedPreviewTabId();
  if (selectedPreviewTabId === null) {
    return;
  }

  void chrome.tabs.update(selectedPreviewTabId, { active: true }).catch(() => {
    textBlockPreviewStatusElement.textContent = "선택한 진단 탭으로 이동하지 못했습니다. 탭 목록을 새로고침하세요.";
  });
});

urlTestButtonElement.addEventListener("click", () => {
  void render();
});

urlTestInputElement.addEventListener("input", () => {
  if (!urlTestInputElement.value.trim()) {
    urlTestResultElement.textContent = "테스트할 URL을 입력하면 현재 우선순위 기준으로 어떤 프로필이 적용되는지 보여줍니다.";
    return;
  }

  void render();
});

refreshTemplatesButtonElement.addEventListener("click", () => {
  void (async () => {
    await writeTemplateServerUrl(templateServerUrlElement.value);
    await writeTemplateServerToken(templateServerTokenElement.value);
    await renderTemplates();
  })();
});

searchInputElement.addEventListener("input", () => {
  scheduleRender();
});

scopeFilterElement.addEventListener("change", () => {
  scheduleRender();
});

chrome.storage.onChanged.addListener((changes, areaName) => {
  if (
    areaName !== "local" ||
    (
      !(STORAGE_KEY in changes) &&
      !(NETWORK_RULE_STORAGE_KEY in changes) &&
      !(TEXT_BLOCK_STORAGE_KEY in changes) &&
      !(TEMPLATE_SERVER_URL_KEY in changes) &&
      !(TEMPLATE_SERVER_TOKEN_KEY in changes)
    )
  ) {
    return;
  }

  scheduleRender();
  void renderTemplates();
});

chrome.tabs.onActivated.addListener(() => {
  scheduleRender();
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete" || changeInfo.url) {
    const selectedPreviewTabId = getSelectedPreviewTabId();
    if (selectedPreviewTabId === null || selectedPreviewTabId === tabId) {
      scheduleRender();
    }
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  clearSelectedPreviewTabIfMatches(tabId);
  scheduleRender();
});

wireNameWatch();
wireAiSettings();
wireAiRules();

void (async () => {
  templateServerUrlElement.value = await readTemplateServerUrl();
  templateServerTokenElement.value = await readTemplateServerToken();
  await render();
  await renderTemplates();
  await renderNameWatch();
})();
