/* eslint-disable @typescript-eslint/no-unused-vars */

function emptyTextBlockStore(): TextBlockStore {
  return InfocutterTextBlocks.emptyTextBlockStore();
}

function normalizeObjectTags(tags: unknown): string[] {
  return InfocutterTextBlocks.normalizeObjectTags(tags);
}

function normalizeTextBlockRule(rule: unknown): TextBlockRule | null {
  return InfocutterTextBlocks.normalizeTextBlockRule(rule, generateId);
}

function normalizeTextBlockProfile(profile: unknown): TextBlockProfile | null {
  return InfocutterTextBlocks.normalizeTextBlockProfile(profile, generateId);
}

function normalizeTextBlockStore(candidate: unknown): TextBlockStore {
  return InfocutterTextBlocks.normalizeTextBlockStore(candidate, generateId);
}

async function readTextBlockStore(): Promise<TextBlockStore> {
  const result = await chrome.storage.local.get(TEXT_BLOCK_STORAGE_KEY);
  return normalizeTextBlockStore(result[TEXT_BLOCK_STORAGE_KEY]);
}

function findMatchingTextBlockProfile(store: TextBlockStore, url: string): TextBlockProfile | null {
  return InfocutterTextBlocks.findMatchingTextBlockProfile(store, url, matchesUrl);
}

async function setTextBlockProfileEnabled(profileId: string, enabled: boolean): Promise<TextBlockProfile | null> {
  const store = await readTextBlockStore();
  const targetProfile = store.profiles.find((item) => item.id === profileId) ?? null;
  if (!targetProfile) {
    return null;
  }

  const nextProfile: TextBlockProfile = { ...targetProfile, enabled, updatedAt: new Date().toISOString() };
  const nextStore: TextBlockStore = {
    ...store,
    profiles: store.profiles.map((item) => item.id === profileId ? nextProfile : item)
  };

  await chrome.storage.local.set({ [TEXT_BLOCK_STORAGE_KEY]: nextStore });
  return nextProfile;
}

async function setTextBlockGlobalEnabled(globalEnabled: boolean): Promise<TextBlockStore> {
  const store = await readTextBlockStore();
  const nextStore: TextBlockStore = {
    ...store,
    settings: {
      ...store.settings,
      globalEnabled
    }
  };

  await chrome.storage.local.set({
    [TEXT_BLOCK_STORAGE_KEY]: nextStore
  });

  return nextStore;
}

async function readActiveTextBlockState(url: string): Promise<ActiveTextBlockState> {
  const store = await readTextBlockStore();
  return InfocutterTextBlocks.buildActiveTextBlockState(store, url, matchesUrl);
}

function textBlockRuleMatchesHiddenTags(rule: TextBlockRule, hiddenObjectTags: string[]): boolean {
  return InfocutterTextBlocks.textBlockRuleMatchesHiddenTags(rule, hiddenObjectTags);
}

function ensureTextBlockStyleElement(): HTMLStyleElement {
  const existing = document.getElementById(TEXT_BLOCK_STYLE_ELEMENT_ID);
  if (existing instanceof HTMLStyleElement) {
    return existing;
  }

  const style = document.createElement("style");
  style.id = TEXT_BLOCK_STYLE_ELEMENT_ID;
  document.documentElement.append(style);
  return style;
}

function clearTextBlockHiddenMarkers(): void {
  document.querySelectorAll(`[${TEXT_BLOCK_HIDDEN_ATTR}]`).forEach((element) => {
    element.removeAttribute(TEXT_BLOCK_HIDDEN_ATTR);
  });
}

function stableTextBlockClasses(element: Element): string[] {
  return stableClasses(element).sort().slice(0, 2);
}

function textBlockFingerprint(element: Element): string {
  const parentTag = element.parentElement?.localName ?? "root";
  const rawClassSignature = stableTextBlockClasses(element).join(".");
  const classSignature = rawClassSignature.length > 0 ? rawClassSignature : "_";
  const rawChildSignature = Array.from(element.children)
    .slice(0, 4)
    .map((child) => child.localName)
    .join(",");
  const childSignature = rawChildSignature.length > 0 ? rawChildSignature : "_";

  return [element.localName, classSignature, parentTag, childSignature].join("|");
}

function textBlockRuntimeId(element: Element): string {
  const existing = textBlockRuntimeIds.get(element);
  if (existing) {
    return existing;
  }

  textBlockRuntimeIdCounter += 1;
  const nextId = `itb-${textBlockRuntimeIdCounter.toString(36)}`;
  textBlockRuntimeIds.set(element, nextId);
  return nextId;
}

function textBlockSample(element: Element): TextBlockDebugSample {
  const snippet = normalizeBlockText(element.textContent)
    .slice(0, 120)
    .trim();
  return {
    classSignature: stableTextBlockClasses(element).join(".") || "-",
    parentTag: element.parentElement?.localName ?? "root",
    tagName: element.localName,
    textSnippet: snippet || "(텍스트 없음)"
  };
}

function buildTextBlockGroups(keyword: string): { groups: TextBlockDebugGroup[]; groupsByFingerprint: Map<string, Element[]> } {
  const normalizedKeyword = normalizeBlockText(keyword);
  if (!normalizedKeyword) {
    return {
      groups: [],
      groupsByFingerprint: new Map()
    };
  }

  const groupedTargets = new Map<string, Element[]>();
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      const parent = node.parentElement;
      if (!parent || isIgnoredTextHost(parent)) {
        return NodeFilter.FILTER_REJECT;
      }

      const text = normalizeBlockText(node.textContent ?? "");
      if (text.length === 0 || !text.includes(normalizedKeyword)) {
        return NodeFilter.FILTER_REJECT;
      }

      return NodeFilter.FILTER_ACCEPT;
    }
  });

  let currentNode = walker.nextNode();
  while (currentNode) {
    const parent = currentNode.parentElement;
    if (parent) {
      const container = preferredBlockContainer(parent);
      const fingerprint = textBlockFingerprint(container);
      const runtimeId = textBlockRuntimeId(container);
      const currentGroup = groupedTargets.get(fingerprint) ?? [];
      if (!currentGroup.some((target) => textBlockRuntimeId(target) === runtimeId)) {
        currentGroup.push(container);
        groupedTargets.set(fingerprint, currentGroup);
      }
    }

    currentNode = walker.nextNode();
  }

  const groups: TextBlockDebugGroup[] = [];
  for (const [fingerprint, group] of groupedTargets.entries()) {
    const first = group[0];
    if (!first) {
      continue;
    }

    const rawChildSignature = Array.from(first.children)
      .slice(0, 4)
      .map((child) => child.localName)
      .join(",");

    groups.push({
      blockCount: group.length,
      childSignature: rawChildSignature.length > 0 ? rawChildSignature : "_",
      classSignature: stableTextBlockClasses(first).join(".") || "-",
      fingerprint,
      matchesRuleFingerprint: true,
      parentTag: first.parentElement?.localName ?? "root",
      qualifies: false,
      samples: group.slice(0, 3).map((element) => textBlockSample(element)),
      tagName: first.localName
    });
  }

  groups.sort((left, right) => right.blockCount - left.blockCount);

  return {
    groups,
    groupsByFingerprint: groupedTargets
  };
}

function collectTextBlockTargets(
  keyword: string,
  minMatchCount: number,
  fingerprint: string | null
): { groups: TextBlockDebugGroup[]; targets: Element[] } {
  const { groups, groupsByFingerprint } = buildTextBlockGroups(keyword);
  const targets: Element[] = [];
  const seenTargetIds = new Set<string>();

  for (const group of groups) {
    group.matchesRuleFingerprint = fingerprint === null || group.fingerprint === fingerprint;
    group.qualifies = group.blockCount >= minMatchCount && group.matchesRuleFingerprint;
    if (!group.qualifies) {
      continue;
    }

    const rawTargets = groupsByFingerprint.get(group.fingerprint) ?? [];
    for (const target of rawTargets) {
      const runtimeId = textBlockRuntimeId(target);
      if (seenTargetIds.has(runtimeId)) {
        continue;
      }

      seenTargetIds.add(runtimeId);
      targets.push(target);
    }
  }

  return {
    groups,
    targets
  };
}

async function readTextBlockDiagnostics(url: string): Promise<ActiveTextBlockDiagnostics> {
  const activeState = await readActiveTextBlockState(url);
  return {
    activeProfileId: activeState.activeProfileId,
    activeProfileName: activeState.activeProfileName,
    globalEnabled: activeState.globalEnabled,
    hiddenObjectTags: [...activeState.hiddenObjectTags],
    profileEnabled: activeState.profileEnabled,
    rules: activeState.rules.map((rule) => {
      const tagMatched = textBlockRuleMatchesHiddenTags(rule, activeState.hiddenObjectTags);
      const { groups, targets } = collectTextBlockTargets(rule.keyword, rule.minMatchCount, rule.fingerprint);
      return {
        eligibleBlockCount: tagMatched ? targets.length : 0,
        eligibleGroupCount: tagMatched ? groups.filter((group) => group.qualifies).length : 0,
        fingerprint: rule.fingerprint,
        groups,
        keyword: rule.keyword,
        minMatchCount: rule.minMatchCount,
        objectId: rule.objectId,
        objectName: rule.objectName,
        objectTags: [...rule.objectTags],
        ruleId: rule.id,
        tagMatched
      };
    }),
    supported: true,
    url
  };
}

async function renderTextBlockRules(): Promise<void> {
  const activeTextBlockState = await readActiveTextBlockState(ownerPageUrl());
  const style = ensureTextBlockStyleElement();
  clearTextBlockHiddenMarkers();

  if (!activeTextBlockState.globalEnabled || !activeTextBlockState.profileEnabled) {
    style.textContent = "";
    return;
  }

  const enabledRules = activeTextBlockState.rules.filter((rule) => (
    rule.enabled && textBlockRuleMatchesHiddenTags(rule, activeTextBlockState.hiddenObjectTags)
  ));
  if (enabledRules.length === 0) {
    style.textContent = "";
    return;
  }

  style.textContent = hiddenAttrCss(TEXT_BLOCK_HIDDEN_ATTR);

  for (const rule of enabledRules) {
    const { targets } = collectTextBlockTargets(rule.keyword, rule.minMatchCount, rule.fingerprint);
    for (const target of targets) {
      target.setAttribute(TEXT_BLOCK_HIDDEN_ATTR, "true");
    }
  }
}

function scheduleTextBlockRender(): void {
  if (textBlockRenderTimer !== null) {
    window.clearTimeout(textBlockRenderTimer);
  }

  textBlockRenderTimer = window.setTimeout(() => {
    textBlockRenderTimer = null;
    void renderTextBlockRules();
  }, 120);
}

function ensureTextBlockObserver(): void {
  if (textBlockObserver) {
    return;
  }

  textBlockObserver = new MutationObserver(() => {
    scheduleTextBlockRender();
  });
  textBlockObserver.observe(document.documentElement, {
    characterData: true,
    childList: true,
    subtree: true
  });
}
