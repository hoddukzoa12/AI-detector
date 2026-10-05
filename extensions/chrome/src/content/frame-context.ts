/* eslint-disable @typescript-eslint/no-unused-vars */

function hostnameFromUrl(url: string): string {
  return InfocutterSelectorRules.hostnameFromUrl(url);
}

function hostnameMatcher(url: string): string {
  return InfocutterSelectorRules.hostnameMatcher(url);
}

function matcherToRegExp(matcher: string): RegExp {
  return InfocutterSelectorRules.matcherToRegExp(matcher);
}

function matchesUrl(matcher: string, url: string): boolean {
  return InfocutterSelectorRules.matchesUrl(matcher, url);
}

function parseFrameMessage(event: MessageEvent): { requestId: unknown; source: unknown; type: unknown } | null {
  const payload: unknown = event.data;
  if (!payload || typeof payload !== "object") {
    return null;
  }

  return {
    requestId: "requestId" in payload ? Reflect.get(payload, "requestId") : null,
    source: "source" in payload ? Reflect.get(payload, "source") : null,
    type: "type" in payload ? Reflect.get(payload, "type") : null
  };
}

function ownerPageUrl(): string {
  if (window.top === window) {
    return window.location.href;
  }

  return document.referrer || window.location.href;
}

function currentFrameScope(): string | null {
  if (window.top === window) {
    return null;
  }

  return `${window.location.origin}${window.location.pathname}`;
}

function currentFrameLabel(): string {
  const frameScope = currentFrameScope();
  return frameScope ? `iframe 안 선택 중: ${frameScope}` : "메인 문서에서 선택 중";
}

function updatePickerFocusState(focused: boolean, label: string): void {
  void chrome.runtime.sendMessage({
    type: messageTypes.updatePickerFocus,
    focused,
    frameScope: currentFrameScope(),
    label
  }).catch(() => undefined);
}

function iframeAccessMode(iframeElement: HTMLIFrameElement): "same-origin" | "cross-origin" | "unknown" {
  try {
    void iframeElement.contentDocument?.body;
    return iframeElement.contentWindow ? "same-origin" : "unknown";
  } catch {
    return "cross-origin";
  }
}
