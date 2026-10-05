import { afterEach, expect, it } from 'vitest';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadRuntimeConfig, publicConfig } from '../../src/application/index.js';
const roots: string[] = [];
afterEach(async () => { await Promise.all(roots.splice(0).map(path => rm(path, { recursive: true, force: true }))); });
async function root() { const path = await mkdtemp(join(tmpdir(), 'config-')); roots.push(path); return path; }
it('loads npm .env with environment priority and no credential in public config', async () => {
  const cwd = await root(); await writeFile(join(cwd, '.env'), 'OPENROUTER_API_KEY="file-placeholder"\nINSPECTOR_OUTPUT_DIR=local-output\nINSPECTOR_PORT=4500\n');
  const env = { OPENROUTER_API_KEY: 'environment-placeholder', INSPECTOR_OUTPUT_DIR: 'actual-output' };
  const config = await loadRuntimeConfig({ cwd, env });
  expect(config.apiKey).toBe('environment-placeholder'); expect(config.outputRoot).toBe(join(cwd, 'actual-output')); expect(config.port).toBe(4500);
  expect(config.host).toBe('127.0.0.1'); expect(publicConfig(config)).toEqual(expect.objectContaining({ aiConfigured: true, model: 'cloudflare/clef', outputRoot: join(cwd, 'actual-output') }));
  expect(env).toEqual({ OPENROUTER_API_KEY: 'environment-placeholder', INSPECTOR_OUTPUT_DIR: 'actual-output' });
});
it('loads desktop beside the executable and docker from app directory', async () => {
  const cwd = await root(); const desktop = await root(); await writeFile(join(desktop, '.env'), 'OPENROUTER_API_KEY=desktop-placeholder\n');
  const config = await loadRuntimeConfig({ mode: 'desktop', cwd, exePath: join(desktop, 'Inspector.exe'), env: {} });
  expect(config.apiKey).toBe('desktop-placeholder'); expect(config.outputRoot).toBe(desktop);
  const docker = await loadRuntimeConfig({ mode: 'docker', cwd, env: { INSPECTOR_PORT: '0' } });
  expect(docker.host).toBe('0.0.0.0'); expect(docker.outputRoot).toBe(join(cwd, 'output')); expect(docker.port).toBe(0);
});
it('rejects invalid config and reads modified keys without rebuilding', async () => {
  const cwd = await root(); await writeFile(join(cwd, '.env'), 'OPENROUTER_API_KEY=first-placeholder');
  expect((await loadRuntimeConfig({ cwd, env: {} })).apiKey).toBe('first-placeholder');
  await writeFile(join(cwd, '.env'), 'OPENROUTER_API_KEY=second-placeholder');
  expect((await loadRuntimeConfig({ cwd, env: {} })).apiKey).toBe('second-placeholder');
  await expect(loadRuntimeConfig({ cwd, env: { INSPECTOR_PORT: '-1' } })).rejects.toThrow('INVALID_CONFIG');
  await expect(loadRuntimeConfig({ cwd, env: { INSPECTOR_HOST: '0.0.0.0' } })).rejects.toThrow('INVALID_CONFIG');
});
it('loads validated numeric OCR/CLEF and image limits without provider override configuration', async () => {
  const cwd = await root();
  const config = await loadRuntimeConfig({ cwd, env: { INSPECTOR_MAX_OCR_REQUESTS: '8', INSPECTOR_MAX_CLEF_REQUESTS: '16', INSPECTOR_MAX_IMAGE_BYTES: '4096', INSPECTOR_MAX_IMAGE_PIXELS: '100' } });
  expect(publicConfig(config).limits).toEqual({ maxOcrRequests: 8, maxClefRequests: 16, maxImageBytes: 4096, maxImagePixels: 100 });
  await expect(loadRuntimeConfig({ cwd, env: { INSPECTOR_MAX_OCR_REQUESTS: '0' } })).rejects.toThrow('INVALID_CONFIG');
});
