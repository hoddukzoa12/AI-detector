import { addTextBlockObjectCondition, deleteTextBlockProfile, readTextBlockStore, removeTextBlockObject, removeTextBlockRule, renameTextBlockObject, renameTextBlockProfile, setTextBlockHiddenObjectTag, setTextBlockObjectEnabled, setTextBlockObjectTags, setTextBlockProfileEnabled, setTextBlockProfileMatchers, setTextBlockRuleEnabled, setTextBlockRuleFingerprint, updateTextBlockRule } from "../shared/text-block-storage.js";
import { groupTextBlockRulesByObject, parseObjectTags } from "../../packages/infocutter-text-blocks/src/index.js";
import type { ActiveTextBlockDiagnostics, TextBlockProfile, TextBlockRule, TextBlockRuleDiagnostics, TextBlockStore } from "../shared/types.js";
import { textBlockEmptyStateElement, textBlockGlobalStatusElement, textBlockHiddenTagListElement, textBlockListElement, textBlockSummaryElement, textBlockToggleAdTagButtonElement, textBlockToggleGlobalButtonElement } from "./elements.js";
import { readActiveTextBlockDiagnostics } from "./preview-tab.js";
import { requestRender } from "./render-bus.js";
import { createProfileEditFields, createSiteCardShell } from "./site-card-dom.js";

function textBlockMatchersLabel(profile: TextBlockProfile): string {
  return profile.matchers.join(", ");
}

function textBlockTagsLabel(tags: string[]): string {
  return tags.length > 0 ? tags.join(", ") : "태그 없음";
}

export function firstNormalizedTag(value: string): string | null {
  return parseObjectTags(value)[0] ?? null;
}

function renderHiddenObjectTags(tags: string[]): void {
  textBlockHiddenTagListElement.replaceChildren();

  if (tags.length === 0) {
    const empty = document.createElement("p");
    empty.className = "options__rule-meta";
    empty.textContent = "숨김 태그가 없습니다. 태그가 없는 오브젝트와 태그 설정에서 제외되지 않은 오브젝트만 동작합니다.";
    textBlockHiddenTagListElement.append(empty);
    return;
  }

  for (const tag of tags) {
    const chip = document.createElement("span");
    chip.className = "options__tag-chip";

    const label = document.createElement("span");
    label.textContent = tag;

    const removeButton = document.createElement("button");
    removeButton.type = "button";
    removeButton.textContent = "삭제";
    removeButton.addEventListener("click", () => {
      void (async () => {
        await setTextBlockHiddenObjectTag(tag, false);
        await requestRender();
      })();
    });

    chip.append(label, removeButton);
    textBlockHiddenTagListElement.append(chip);
  }
}

function matchesTextBlockSearch(profile: TextBlockProfile, rule: TextBlockRule, keyword: string): boolean {
  if (!keyword) {
    return true;
  }

  return (
    profile.name.toLowerCase().includes(keyword) ||
    textBlockMatchersLabel(profile).toLowerCase().includes(keyword) ||
    rule.objectName.toLowerCase().includes(keyword) ||
    rule.objectTags.some((tag) => tag.includes(keyword)) ||
    rule.keyword.toLowerCase().includes(keyword)
  );
}

function ruleDiagnosticsById(diagnostics: ActiveTextBlockDiagnostics | null): Map<string, TextBlockRuleDiagnostics> {
  return new Map((diagnostics?.rules ?? []).map((rule) => [rule.ruleId, rule]));
}

function buildTextBlockDiagnosticsCard(
  profileId: string,
  rule: TextBlockRule,
  ruleDiagnostics: TextBlockRuleDiagnostics | null
): HTMLElement {
  const diagnosticsWrap = document.createElement("div");
  diagnosticsWrap.style.marginTop = "10px";
  diagnosticsWrap.style.display = "grid";
  diagnosticsWrap.style.gap = "8px";

  const previewMeta = document.createElement("p");
  previewMeta.className = "options__rule-meta";

  if (!ruleDiagnostics) {
    previewMeta.textContent = "현재 활성 탭 미리보기 없음 · 이 규칙이 적용되는 페이지를 열어두면 몇 개 블록이 잡히는지 볼 수 있습니다.";
    diagnosticsWrap.append(previewMeta);
    return diagnosticsWrap;
  }

  previewMeta.textContent = `오브젝트 ${ruleDiagnostics.objectName} · 현재 탭 미리보기 · 숨김 대상 블록 ${ruleDiagnostics.eligibleBlockCount}개 · 조건을 만족한 그룹 ${ruleDiagnostics.eligibleGroupCount}개 · ${
    ruleDiagnostics.fingerprint ? "특정 그룹 고정" : "전체 그룹 허용"
  } · 태그 ${textBlockTagsLabel(ruleDiagnostics.objectTags)} · ${ruleDiagnostics.tagMatched ? "태그 숨김 적용" : "태그 설정으로 제외"}`;
  diagnosticsWrap.append(previewMeta);

  const debugDetails = document.createElement("details");
  debugDetails.style.marginTop = "2px";
  if (ruleDiagnostics.eligibleGroupCount > 0) {
    debugDetails.open = true;
  }

  const summary = document.createElement("summary");
  summary.textContent = `디버그 그룹 ${ruleDiagnostics.groups.length}개 보기`;
  summary.style.cursor = "pointer";
  summary.style.fontWeight = "700";
  summary.style.color = "#5b4e3f";

  const list = document.createElement("div");
  list.style.display = "grid";
  list.style.gap = "8px";
  list.style.marginTop = "8px";

  for (const group of ruleDiagnostics.groups) {
    const groupCard = document.createElement("div");
    groupCard.style.padding = "10px";
    groupCard.style.border = "1px solid #d7ceb9";
    groupCard.style.background = group.qualifies
      ? "rgba(187, 247, 208, 0.22)"
      : group.matchesRuleFingerprint
        ? "rgba(255,255,255,0.4)"
        : "rgba(254, 240, 138, 0.18)";

    const groupMeta = document.createElement("p");
    groupMeta.className = "options__rule-meta";
    groupMeta.textContent = `${group.qualifies ? "적용 대상 그룹" : group.matchesRuleFingerprint ? "관찰 그룹" : "현재 규칙에서 제외된 그룹"} · 블록 ${group.blockCount}개 · ${group.tagName} · parent ${group.parentTag}`;

    const fingerprint = document.createElement("code");
    fingerprint.className = "options__rule-code";
    fingerprint.textContent = `fingerprint ${group.fingerprint}`;

    const structure = document.createElement("p");
    structure.className = "options__rule-meta";
    structure.textContent = `class ${group.classSignature} · children ${group.childSignature}`;

    const actionRow = document.createElement("div");
    actionRow.className = "options__rule-actions";

    const scopeButton = document.createElement("button");
    scopeButton.type = "button";
    scopeButton.className = "options__secondary";
    if (group.blockCount < ruleDiagnostics.minMatchCount) {
      scopeButton.textContent = "최소 개수 부족";
      scopeButton.disabled = true;
    } else if (ruleDiagnostics.fingerprint === group.fingerprint) {
      scopeButton.textContent = "그룹 고정 해제";
      scopeButton.addEventListener("click", () => {
        void (async () => {
          await setTextBlockRuleFingerprint(profileId, rule.id, null);
          await requestRender();
        })();
      });
    } else {
      scopeButton.textContent = "이 그룹만 적용";
      scopeButton.addEventListener("click", () => {
        void (async () => {
          await setTextBlockRuleFingerprint(profileId, rule.id, group.fingerprint);
          await requestRender();
        })();
      });
    }
    actionRow.append(scopeButton);

    const sampleList = document.createElement("div");
    sampleList.style.display = "grid";
    sampleList.style.gap = "6px";
    sampleList.style.marginTop = "8px";

    for (const sample of group.samples) {
      const sampleCard = document.createElement("div");
      sampleCard.style.padding = "8px";
      sampleCard.style.background = "rgba(255,255,255,0.55)";

      const sampleMeta = document.createElement("p");
      sampleMeta.className = "options__rule-meta";
      sampleMeta.textContent = `${sample.tagName} · parent ${sample.parentTag} · class ${sample.classSignature}`;

      const sampleSnippet = document.createElement("code");
      sampleSnippet.className = "options__rule-code";
      sampleSnippet.textContent = sample.textSnippet;

      sampleCard.append(sampleMeta, sampleSnippet);
      sampleList.append(sampleCard);
    }

    groupCard.append(groupMeta, fingerprint, structure, actionRow, sampleList);
    list.append(groupCard);
  }

  debugDetails.append(summary, list);
  diagnosticsWrap.append(debugDetails);
  return diagnosticsWrap;
}

export async function renderTextBlocks(keyword: string): Promise<void> {
  const store: TextBlockStore = await readTextBlockStore();
  const diagnostics = await readActiveTextBlockDiagnostics();
  const diagnosticsMap = ruleDiagnosticsById(diagnostics);
  const profileCards: HTMLElement[] = [];
  let totalVisibleRules = 0;

  textBlockGlobalStatusElement.textContent = store.settings.globalEnabled
    ? "텍스트 기반 블록 숨김 전역 상태: 켜짐"
    : "텍스트 기반 블록 숨김 전역 상태: 꺼짐";
  textBlockToggleGlobalButtonElement.textContent = store.settings.globalEnabled
    ? "텍스트 규칙 전체 끄기"
    : "텍스트 규칙 전체 켜기";
  const adHidden = store.settings.hiddenObjectTags.includes("ad");
  textBlockToggleAdTagButtonElement.textContent = adHidden ? "ad 태그 숨김 끄기" : "ad 태그 숨김 켜기";
  renderHiddenObjectTags(store.settings.hiddenObjectTags);
  if (diagnostics?.supported) {
    let diagnosticsHost = diagnostics.url;
    try {
      diagnosticsHost = new URL(diagnostics.url).hostname;
    } catch {
      /* keep raw diagnostics url when parsing fails */
    }
    textBlockSummaryElement.textContent = `현재 페이지 진단 연결됨 · ${diagnosticsHost} · ${diagnostics.activeProfileName ?? "매칭된 텍스트 프로필 없음"} · 숨김 태그 ${textBlockTagsLabel(store.settings.hiddenObjectTags)}`;
  } else {
    textBlockSummaryElement.textContent = `현재 페이지 진단 없음 · 숨김 태그 ${textBlockTagsLabel(store.settings.hiddenObjectTags)}`;
  }

  for (const profile of store.profiles) {
    const visibleRules = profile.rules.filter((rule) => matchesTextBlockSearch(profile, rule, keyword));
    const profileMatches =
      !keyword ||
      profile.name.toLowerCase().includes(keyword) ||
      textBlockMatchersLabel(profile).toLowerCase().includes(keyword);

    if (!profileMatches && visibleRules.length === 0) {
      continue;
    }

    totalVisibleRules += visibleRules.length;

    const { card, header, headingWrap, title, subtitle } = createSiteCardShell(
      profile.name,
      `${profile.enabled ? "텍스트 프로필 사용 중" : "텍스트 프로필 꺼짐"} · 매처 ${textBlockMatchersLabel(profile)} · 규칙 ${profile.rules.length}개`
    );

    const { editWrap, nameInput, matcherEditor, matcherHint } = createProfileEditFields(
      profile.name,
      profile.matchers.join("\n"),
      [
        "<li>한 줄에 matcher 하나씩 입력</li>",
        "<li>예: https://www.naver.com/*</li>",
        "<li>이 텍스트 규칙은 같은 구조의 블록이 최소 개수 이상 잡힐 때만 숨깁니다</li>"
      ]
    );

    const actions = document.createElement("div");
    actions.className = "options__site-actions";

    const toggleProfileButton = document.createElement("button");
    toggleProfileButton.type = "button";
    toggleProfileButton.textContent = profile.enabled ? "텍스트 프로필 끄기" : "텍스트 프로필 켜기";
    toggleProfileButton.className = "options__secondary";
    toggleProfileButton.addEventListener("click", () => {
      void (async () => {
        await setTextBlockProfileEnabled(profile.id, !profile.enabled);
        await requestRender();
      })();
    });

    const saveProfileButton = document.createElement("button");
    saveProfileButton.type = "button";
    saveProfileButton.textContent = "텍스트 프로필 저장";
    saveProfileButton.className = "options__secondary";
    saveProfileButton.addEventListener("click", () => {
      void (async () => {
        await renameTextBlockProfile(profile.id, nameInput.value);
        await setTextBlockProfileMatchers(profile.id, matcherEditor.value.split("\n"));
        await requestRender();
      })();
    });

    const deleteProfileButton = document.createElement("button");
    deleteProfileButton.type = "button";
    deleteProfileButton.textContent = "텍스트 프로필 삭제";
    deleteProfileButton.addEventListener("click", () => {
      void (async () => {
        await deleteTextBlockProfile(profile.id);
        await requestRender();
      })();
    });

    actions.append(toggleProfileButton, saveProfileButton, deleteProfileButton);
    headingWrap.append(title, subtitle);
    header.append(headingWrap, actions);
    editWrap.append(nameInput, matcherEditor, matcherHint);

    const list = document.createElement("ul");
    list.className = "options__rule-list";

    const objectGroups = groupTextBlockRulesByObject(visibleRules);

    if (objectGroups.length === 0) {
      const emptyRule = document.createElement("li");
      emptyRule.className = "options__rule-item";

      const emptyMeta = document.createElement("p");
      emptyMeta.className = "options__rule-meta";
      emptyMeta.textContent = "이 텍스트 프로필에는 아직 오브젝트가 없습니다.";

      emptyRule.append(emptyMeta);
      list.append(emptyRule);
    }

    for (const objectGroup of objectGroups) {
      const item = document.createElement("li");
      item.className = "options__rule-item";
      if (!objectGroup.enabled) {
        item.style.opacity = "0.72";
      }

      const objectNameInput = document.createElement("input");
      objectNameInput.className = "options__input";
      objectNameInput.type = "text";
      objectNameInput.value = objectGroup.objectName;
      objectNameInput.placeholder = "오브젝트 이름";

      const objectTagsInput = document.createElement("input");
      objectTagsInput.className = "options__input";
      objectTagsInput.type = "text";
      objectTagsInput.value = objectGroup.objectTags.join(", ");
      objectTagsInput.placeholder = "태그 예: ad";

      const metaText = document.createElement("p");
      metaText.className = "options__rule-meta";
      metaText.textContent = `텍스트 오브젝트 ${objectGroup.objectName} · ID ${objectGroup.objectId} · 조건 ${objectGroup.rules.length}개 · ${objectGroup.enabled ? "활성" : "비활성"} · 태그 ${textBlockTagsLabel(objectGroup.objectTags)}`;

      const objectActions = document.createElement("div");
      objectActions.className = "options__rule-actions";

      const toggleObjectButton = document.createElement("button");
      toggleObjectButton.type = "button";
      toggleObjectButton.textContent = objectGroup.enabled ? "오브젝트 끄기" : "오브젝트 켜기";
      toggleObjectButton.className = "options__secondary";
      toggleObjectButton.addEventListener("click", () => {
        void (async () => {
          await setTextBlockObjectEnabled(profile.id, objectGroup.objectId, !objectGroup.enabled);
          await requestRender();
        })();
      });

      const saveObjectButton = document.createElement("button");
      saveObjectButton.type = "button";
      saveObjectButton.textContent = "오브젝트 이름 저장";
      saveObjectButton.className = "options__secondary";
      saveObjectButton.addEventListener("click", () => {
        void (async () => {
          await renameTextBlockObject(profile.id, objectGroup.objectId, objectNameInput.value);
          await setTextBlockObjectTags(profile.id, objectGroup.objectId, parseObjectTags(objectTagsInput.value));
          await requestRender();
        })();
      });

      const deleteObjectButton = document.createElement("button");
      deleteObjectButton.type = "button";
      deleteObjectButton.textContent = "오브젝트 삭제";
      deleteObjectButton.addEventListener("click", () => {
        void (async () => {
          await removeTextBlockObject(profile.id, objectGroup.objectId);
          await requestRender();
        })();
      });

      objectActions.append(toggleObjectButton, saveObjectButton, deleteObjectButton);

      const addConditionGrid = document.createElement("div");
      addConditionGrid.className = "options__create-grid";
      addConditionGrid.style.gridTemplateColumns = "minmax(220px, 1fr) 160px 140px";
      addConditionGrid.style.marginTop = "10px";

      const newConditionKeywordInput = document.createElement("input");
      newConditionKeywordInput.className = "options__input";
      newConditionKeywordInput.type = "text";
      newConditionKeywordInput.placeholder = "추가 조건 키워드";

      const newConditionMinInput = document.createElement("input");
      newConditionMinInput.className = "options__input";
      newConditionMinInput.type = "number";
      newConditionMinInput.min = "2";
      newConditionMinInput.step = "1";
      newConditionMinInput.value = "2";

      const addConditionButton = document.createElement("button");
      addConditionButton.type = "button";
      addConditionButton.textContent = "조건 추가";
      addConditionButton.className = "options__secondary";
      addConditionButton.addEventListener("click", () => {
        void (async () => {
          await addTextBlockObjectCondition(profile.id, objectGroup.objectId, {
            keyword: newConditionKeywordInput.value,
            minMatchCount: Number.parseInt(newConditionMinInput.value, 10) || 2
          });
          await requestRender();
        })();
      });

      addConditionGrid.append(newConditionKeywordInput, newConditionMinInput, addConditionButton);

      const conditionList = document.createElement("div");
      conditionList.style.display = "grid";
      conditionList.style.gap = "10px";
      conditionList.style.marginTop = "12px";

      for (const rule of objectGroup.rules) {
        const conditionItem = document.createElement("div");
        conditionItem.style.padding = "10px";
        conditionItem.style.background = "rgba(255,255,255,0.48)";
        if (!rule.enabled) {
          conditionItem.style.opacity = "0.72";
        }

        const keywordInput = document.createElement("input");
        keywordInput.className = "options__input";
        keywordInput.type = "text";
        keywordInput.value = rule.keyword;

        const minMatchCountInput = document.createElement("input");
        minMatchCountInput.className = "options__input";
        minMatchCountInput.type = "number";
        minMatchCountInput.min = "2";
        minMatchCountInput.step = "1";
        minMatchCountInput.value = String(rule.minMatchCount);

        const conditionGrid = document.createElement("div");
        conditionGrid.className = "options__create-grid";
        conditionGrid.style.gridTemplateColumns = "minmax(220px, 1fr) 160px";
        conditionGrid.append(keywordInput, minMatchCountInput);

        const conditionMeta = document.createElement("p");
        conditionMeta.className = "options__rule-meta";
        conditionMeta.textContent = `조건 ${rule.keyword} · 최소 블록 수 ${rule.minMatchCount}개 · ${rule.enabled ? "활성" : "비활성"} · ${
          rule.fingerprint ? "특정 그룹 고정" : "전체 그룹"
        }`;

        const conditionActions = document.createElement("div");
        conditionActions.className = "options__rule-actions";

        const toggleConditionButton = document.createElement("button");
        toggleConditionButton.type = "button";
        toggleConditionButton.textContent = rule.enabled ? "조건 끄기" : "조건 켜기";
        toggleConditionButton.className = "options__secondary";
        toggleConditionButton.addEventListener("click", () => {
          void (async () => {
            await setTextBlockRuleEnabled(profile.id, rule.id, !rule.enabled);
            await requestRender();
          })();
        });

        const saveConditionButton = document.createElement("button");
        saveConditionButton.type = "button";
        saveConditionButton.textContent = "조건 저장";
        saveConditionButton.className = "options__secondary";
        saveConditionButton.addEventListener("click", () => {
          void (async () => {
            await updateTextBlockRule(profile.id, rule.id, {
              keyword: keywordInput.value,
              minMatchCount: Number.parseInt(minMatchCountInput.value, 10) || 2
            });
            await requestRender();
          })();
        });

        const deleteConditionButton = document.createElement("button");
        deleteConditionButton.type = "button";
        deleteConditionButton.textContent = "조건 삭제";
        deleteConditionButton.className = "options__secondary";
        deleteConditionButton.addEventListener("click", () => {
          void (async () => {
            await removeTextBlockRule(profile.id, rule.id);
            await requestRender();
          })();
        });

        const diagnosticsCard = buildTextBlockDiagnosticsCard(profile.id, rule, diagnosticsMap.get(rule.id) ?? null);
        conditionActions.append(toggleConditionButton, saveConditionButton, deleteConditionButton);
        conditionItem.append(conditionGrid, conditionMeta, conditionActions, diagnosticsCard);
        conditionList.append(conditionItem);
      }

      item.append(objectNameInput, objectTagsInput, metaText, objectActions, addConditionGrid, conditionList);
      list.append(item);
    }

    card.append(header, editWrap, list);
    profileCards.push(card);
  }

  textBlockListElement.replaceChildren(...profileCards);
  textBlockEmptyStateElement.hidden = profileCards.length > 0;
  textBlockSummaryElement.textContent += ` · 표시 중인 텍스트 프로필 ${profileCards.length}개 / 규칙 ${totalVisibleRules}개`;
}
