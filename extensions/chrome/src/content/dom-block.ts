/* eslint-disable @typescript-eslint/no-unused-vars */

function normalizeBlockText(value: string): string {
  return value.replace(/\s+/g, " ").trim().toLowerCase();
}

function isIgnoredTextHost(element: Element): boolean {
  return ["script", "style", "noscript", "textarea", "input", "select", "option"].includes(element.localName);
}

function isBlockContainer(element: Element): boolean {
  if (!(element instanceof HTMLElement)) {
    return false;
  }

  if (element === document.body || element === document.documentElement) {
    return false;
  }

  if (
    [
      "article",
      "aside",
      "dd",
      "details",
      "div",
      "dl",
      "dt",
      "fieldset",
      "figure",
      "footer",
      "form",
      "header",
      "li",
      "main",
      "nav",
      "section",
      "summary",
      "td",
      "th",
      "tr"
    ].includes(element.localName)
  ) {
    return true;
  }

  return ["block", "flex", "grid", "list-item", "table", "table-cell", "table-row"].includes(
    window.getComputedStyle(element).display
  );
}

function preferredBlockContainer(element: Element): Element {
  let current: Element | null = element;

  while (current && current !== document.body && current !== document.documentElement) {
    if (isBlockContainer(current)) {
      const text = normalizeBlockText(current.textContent);
      if (text.length > 1) {
        return current;
      }
    }

    current = current.parentElement;
  }

  return element;
}
