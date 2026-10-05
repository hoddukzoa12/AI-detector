import { groupRulesByCard } from "../shared/storage.js";
import type { RuleProfile, StoredRule } from "../shared/types.js";

export const TEMPLATE_SERVER_URL_KEY = "infocutter.templateServerUrl";
export const TEMPLATE_SERVER_TOKEN_KEY = "infocutter.templateServerToken";
export const DEFAULT_TEMPLATE_SERVER_URL = "http://127.0.0.1:41800";

export type RemoteTemplate = {
  version: number;
  slug: string;
  name: string;
  description: string;
  matchers: string[];
  cards: {
    id: string;
    name: string;
    enabled?: boolean;
    note?: string;
    rules: {
      frameScope: string | null;
      mode?: StoredRule["mode"];
      selector: string;
    }[];
  }[];
};

export type RemoteTemplateSummary = {
  slug: string;
  name: string;
  description: string;
  matcherCount: number;
  cardCount: number;
  ruleCount: number;
};

export async function readTemplateServerUrl(): Promise<string> {
  const result = await chrome.storage.local.get(TEMPLATE_SERVER_URL_KEY);
  return typeof result[TEMPLATE_SERVER_URL_KEY] === "string"
    ? result[TEMPLATE_SERVER_URL_KEY]
    : DEFAULT_TEMPLATE_SERVER_URL;
}

export async function writeTemplateServerUrl(serverUrl: string): Promise<void> {
  await chrome.storage.local.set({
    [TEMPLATE_SERVER_URL_KEY]: serverUrl.trim() || DEFAULT_TEMPLATE_SERVER_URL
  });
}

export async function readTemplateServerToken(): Promise<string> {
  const result = await chrome.storage.local.get(TEMPLATE_SERVER_TOKEN_KEY);
  return typeof result[TEMPLATE_SERVER_TOKEN_KEY] === "string"
    ? result[TEMPLATE_SERVER_TOKEN_KEY]
    : "";
}

export async function writeTemplateServerToken(token: string): Promise<void> {
  await chrome.storage.local.set({
    [TEMPLATE_SERVER_TOKEN_KEY]: token.trim()
  });
}

export async function fetchTemplateJson<T>(
  serverUrl: string,
  token: string,
  pathname: string,
  init?: RequestInit
): Promise<T> {
  const headers = new Headers(init?.headers);
  if (token.trim()) {
    headers.set("authorization", `Bearer ${token.trim()}`);
  }
  const response = await fetch(new URL(pathname, serverUrl), {
    ...init,
    headers
  });
  if (!response.ok) {
    throw new Error(`템플릿 서버 요청 실패: ${response.status}`);
  }
  return response.json() as Promise<T>;
}

export function slugFromProfileName(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9가-힣._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    || "template";
}

export function profileToTemplate(profile: RuleProfile, slug: string, name: string): RemoteTemplate {
  const groupedCards = groupRulesByCard(profile.rules, profile.cards);
  return {
    version: 1,
    slug,
    name,
    description: `${profile.name} 프로필에서 저장한 템플릿`,
    matchers: [...profile.matchers],
    cards: groupedCards.map((card) => ({
      id: card.cardId.replace(/^tpl:[^:]+:/, ""),
      name: card.cardName,
      enabled: card.enabled,
      note: "",
      rules: card.rules.map((rule) => ({
        frameScope: rule.frameScope,
        mode: rule.mode,
        selector: rule.selector
      }))
    }))
  };
}
