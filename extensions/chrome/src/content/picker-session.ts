/* eslint-disable @typescript-eslint/no-unused-vars */

function sessionAdd(entry: PickerSessionEntry): void {
  selectionSession = [...selectionSession, entry];
}

function sessionRemove(cardId: string): void {
  selectionSession = selectionSession.filter((entry) => entry.cardId !== cardId);
}

function sessionRename(cardId: string, name: string): void {
  selectionSession = selectionSession.map((entry) => (
    entry.cardId === cardId
      ? { ...entry, cardName: name.trim() || entry.cardName }
      : entry
  ));
}

function sessionClear(): void {
  selectionSession = [];
}

async function sessionPersist(): Promise<void> {
  for (const card of selectionSession) {
    await addSiteRule(ownerPageUrl(), card.selector, card.frameScope, {
      cardId: card.cardId,
      cardName: card.cardName
    });
  }

  selectionSession = [];
  applySelectionSessionHighlights();
}

function sessionEntryForElement(element: Element): PickerSessionEntry | null {
  const scope = currentFrameScope();
  for (const entry of selectionSession) {
    if (entry.frameScope !== scope) {
      continue;
    }
    try {
      if (element.matches(entry.selector)) {
        return entry;
      }
    } catch {
      /* ignore invalid selector */
    }
  }
  return null;
}

function sessionEntryById(cardId: string): PickerSessionEntry | null {
  return selectionSession.find((entry) => entry.cardId === cardId) ?? null;
}

function sessionIsSelected(element: Element): boolean {
  return sessionEntryForElement(element) !== null;
}

function quickSelectorForElement(element: Element): string {
  const candidates = buildSelectorCandidates(element);
  for (const candidate of candidates) {
    if (selectorAssessment(candidate).matches === 1) {
      return candidate;
    }
  }
  return buildSelector(element);
}

function sessionToggleElement(element: Element): "added" | "removed" {
  const existing = sessionEntryForElement(element);
  if (existing) {
    sessionRemove(existing.cardId);
    return "removed";
  }

  sessionAdd({
    cardId: generateId(),
    cardName: elementShortLabel(element),
    createdAt: new Date().toISOString(),
    frameScope: currentFrameScope(),
    selector: quickSelectorForElement(element)
  });
  return "added";
}

function sessionUpdateSelector(cardId: string, selector: string): void {
  selectionSession = selectionSession.map((entry) => (
    entry.cardId === cardId ? { ...entry, selector } : entry
  ));
}
