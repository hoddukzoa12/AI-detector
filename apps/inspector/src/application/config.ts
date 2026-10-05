/** Node-only deployment configuration. Environment values override the local .env file. */
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { parse } from 'dotenv';
import { CLEF_MODEL, ContractError, OCR_MODEL, DEFAULT_ANALYSIS_LIMITS, type AnalysisLimits, type PublicConfigV2 } from '../core/index.js';
export type RuntimeMode = 'npm' | 'docker' | 'desktop';
export interface RuntimeConfig { mode: RuntimeMode; apiKey: string; outputRoot: string; host: string; port: number; executablePath?: string; limits?: Partial<AnalysisLimits> }
export interface LoadRuntimeConfigOptions { mode?: RuntimeMode; cwd?: string; exePath?: string; env?: NodeJS.ProcessEnv }
export function publicConfig(config: Pick<RuntimeConfig, 'apiKey' | 'outputRoot' | 'limits'>): PublicConfigV2 {
  return { aiRequired: true, ocrModel: OCR_MODEL, limits: { ...DEFAULT_ANALYSIS_LIMITS, ...config.limits }, aiConfigured: Boolean(config.apiKey.trim()), model: CLEF_MODEL, outputRoot: resolve(config.outputRoot) };
}
export async function loadRuntimeConfig(options: LoadRuntimeConfigOptions = {}): Promise<RuntimeConfig> {
  const env = options.env ?? process.env;
  const mode = options.mode ?? env.INSPECTOR_RUNTIME ?? 'npm';
  if (!['npm', 'docker', 'desktop'].includes(mode)) throw new ContractError('INVALID_CONFIG', 'Unknown runtime mode');
  const cwd = resolve(options.cwd ?? process.cwd());
  const base = mode === 'desktop' ? dirname(resolve(options.exePath ?? process.execPath)) : cwd;
  let file: Record<string, string> = {};
  try { file = parse(await readFile(resolve(base, '.env'), 'utf8')); }
  catch (error) { if (!(typeof error === 'object' && error !== null && 'code' in error && error.code === 'ENOENT')) throw new ContractError('INVALID_CONFIG', 'Unable to read runtime .env'); }
  const value = (name: string) => env[name] ?? file[name];
  const port = Number(value('INSPECTOR_PORT') ?? 4173);
  const host = value('INSPECTOR_HOST') ?? (mode === 'docker' ? '0.0.0.0' : '127.0.0.1');
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw new ContractError('INVALID_CONFIG', 'Invalid port');
  if (!['127.0.0.1', 'localhost', '::1', '0.0.0.0'].includes(host) || (host === '0.0.0.0' && mode !== 'docker')) throw new ContractError('INVALID_CONFIG', 'Invalid runtime host');
  const limits: AnalysisLimits = { ...DEFAULT_ANALYSIS_LIMITS };
  for (const [key, name] of [['maxOcrRequests', 'INSPECTOR_MAX_OCR_REQUESTS'], ['maxClefRequests', 'INSPECTOR_MAX_CLEF_REQUESTS'], ['maxImageBytes', 'INSPECTOR_MAX_IMAGE_BYTES'], ['maxImagePixels', 'INSPECTOR_MAX_IMAGE_PIXELS']] as const) {
    const configured = value(name); if (configured !== undefined) limits[key] = Number(configured);
    if (!Number.isSafeInteger(limits[key]) || limits[key] < 1) throw new ContractError('INVALID_CONFIG', `Invalid ${name}`);
  }
  return { limits, mode: mode as RuntimeMode, apiKey: value('OPENROUTER_API_KEY') ?? '',
    outputRoot: resolve(base, value('INSPECTOR_OUTPUT_DIR') ?? (mode === 'desktop' ? '.' : 'output')), host, port,
    ...(value('INSPECTOR_CHROMIUM_PATH') ? { executablePath: value('INSPECTOR_CHROMIUM_PATH') } : {}) };
}
