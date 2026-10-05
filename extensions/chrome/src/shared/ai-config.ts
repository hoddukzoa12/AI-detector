import { AI_CONFIG_KEY, AI_DETECTION_ENDPOINT_DEFAULT } from "./constants.js";

export type AiConfig = {
  endpoint: string;
  apiKey: string;
  model: string;
  analyzedHosts: string[];
};

function emptyAiConfig(): AiConfig {
  return { endpoint: AI_DETECTION_ENDPOINT_DEFAULT, apiKey: "", model: "", analyzedHosts: [] };
}

export function normalizeAiConfig(candidate: unknown): AiConfig {
  if (!candidate || typeof candidate !== "object") {
    return emptyAiConfig();
  }
  const endpoint: unknown = Reflect.get(candidate, "endpoint");
  const apiKey: unknown = Reflect.get(candidate, "apiKey");
  const model: unknown = Reflect.get(candidate, "model");
  const analyzedHosts: unknown = Reflect.get(candidate, "analyzedHosts");
  return {
    endpoint: typeof endpoint === "string" && endpoint.length > 0 ? endpoint : AI_DETECTION_ENDPOINT_DEFAULT,
    apiKey: typeof apiKey === "string" ? apiKey : "",
    model: typeof model === "string" ? model : "",
    analyzedHosts: Array.isArray(analyzedHosts)
      ? analyzedHosts.filter((host): host is string => typeof host === "string")
      : []
  };
}

export async function readAiConfig(): Promise<AiConfig> {
  const result = await chrome.storage.local.get(AI_CONFIG_KEY);
  return normalizeAiConfig(result[AI_CONFIG_KEY]);
}

export async function writeAiConfig(config: AiConfig): Promise<void> {
  await chrome.storage.local.set({ [AI_CONFIG_KEY]: config });
}

export function isHostAnalyzed(config: AiConfig, host: string): boolean {
  return config.analyzedHosts.includes(host);
}

export async function markHostAnalyzed(host: string): Promise<AiConfig> {
  const config = await readAiConfig();
  if (config.analyzedHosts.includes(host)) {
    return config;
  }
  const next: AiConfig = { ...config, analyzedHosts: [...config.analyzedHosts, host] };
  await writeAiConfig(next);
  return next;
}

export async function resetAnalyzedHosts(): Promise<AiConfig> {
  const config = await readAiConfig();
  const next: AiConfig = { ...config, analyzedHosts: [] };
  await writeAiConfig(next);
  return next;
}
