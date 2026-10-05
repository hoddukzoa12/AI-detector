import type { AiConfig } from "./ai-config.js";
import { readAiConfig, markHostAnalyzed } from "./ai-config.js";
import type { AiRuleStore, AiRuleCategory } from "./ai-types.js";
import { readAiRuleStore } from "./ai-rule-storage.js";
import { runAiDetection } from "./ai-detection.js";
import { buildAiDetectionPrompt, parseAiDetectionResponse, callLiteLLM } from "./ai-llm-client.js";
import type { AiBlock, AiDetection } from "./ai-llm-client.js";
import { hostnameMatcher, hostnameFromUrl } from "./storage-matchers.js";

export type AiAnalysisDecision =
  | { proceed: true; categories: AiRuleCategory[]; model: string }
  | { proceed: false; reason: "no-api-key" | "disabled" | "no-categories" };

export function decideAiAnalysis(config: AiConfig, store: AiRuleStore): AiAnalysisDecision {
  if (config.apiKey.trim().length === 0) {
    return { proceed: false, reason: "no-api-key" };
  }
  if (!store.settings.globalEnabled) {
    return { proceed: false, reason: "disabled" };
  }
  if (store.settings.enabledCategories.length === 0) {
    return { proceed: false, reason: "no-categories" };
  }
  return { proceed: true, categories: store.settings.enabledCategories, model: config.model };
}

export type AiAnalysisSkipReason = "no-api-key" | "disabled" | "no-categories" | "no-blocks";

export type AiAnalysisOutcome =
  | { status: "ok"; count: number }
  | { status: "skipped"; reason: AiAnalysisSkipReason };

export async function analyzePageForAi(
  url: string,
  collectBlocks: () => Promise<AiBlock[]>
): Promise<AiAnalysisOutcome> {
  const config = await readAiConfig();
  const store = await readAiRuleStore();
  const decision = decideAiAnalysis(config, store);
  if (!decision.proceed) {
    return { status: "skipped", reason: decision.reason };
  }
  const blocks = await collectBlocks();
  if (blocks.length === 0) {
    return { status: "skipped", reason: "no-blocks" };
  }
  const detect = async (input: AiBlock[]): Promise<AiDetection[]> => {
    const prompt = buildAiDetectionPrompt(input, decision.categories);
    const text = await callLiteLLM(config, prompt);
    return parseAiDetectionResponse(text);
  };
  const count = await runAiDetection([hostnameMatcher(url)], blocks, decision.categories, decision.model, detect);
  await markHostAnalyzed(hostnameFromUrl(url));
  return { status: "ok", count };
}
