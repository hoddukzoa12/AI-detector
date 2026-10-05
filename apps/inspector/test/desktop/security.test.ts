import { describe, expect, it } from 'vitest';
import { desktopPaths, desktopWindowOptions, existingInstanceExitCode, guardDesktopContents, shutdownDesktop } from '../../src/desktop/policy.js';

describe('desktop trust boundary', () => {
  it('does not report self-test success when another app holds the instance lock', () => {
    expect(existingInstanceExitCode(['Inspektor.exe', '--self-test'])).toBe(2);
    expect(existingInstanceExitCode(['Inspektor.exe'])).toBe(0);
  });
  it('uses the packaged app and Chromium locations and a sandbox without Node', () => {
    expect(desktopPaths('/release/resources', '/release/resources/app')).toEqual({
      publicDir: '/release/resources/app/dist/public',
      executablePath: '/release/resources/browser/chrome-win64/chrome.exe',
      nodePath: '/release/resources/runtime/node.exe',
      selfTestPath: '/release/resources/app/dist/self-test.mjs',
    });
    expect(desktopWindowOptions.webPreferences).toMatchObject({ nodeIntegration: false, contextIsolation: true, sandbox: true, devTools: false });
    expect(desktopWindowOptions.webPreferences).not.toHaveProperty('preload');
  });
  it('blocks external navigation, redirects, popups, webviews, downloads and permissions', () => {
    const listeners = new Map<string, (...args: never[]) => void>();
    let popup: ((details: { url: string }) => { action: 'deny' }) | undefined;
    let permission: ((...args: unknown[]) => void) | undefined;
    let permissionCheck: (() => boolean) | undefined;
    guardDesktopContents({
      getURL: () => 'http://127.0.0.1:45001/',
      on: (name, handler) => { listeners.set(name, handler as (...args: never[]) => void); },
      setWindowOpenHandler: handler => { popup = handler; },
      session: {
        setPermissionRequestHandler: handler => { permission = handler as (...args: unknown[]) => void; },
        setPermissionCheckHandler: handler => { permissionCheck = handler; },
        on: (name, handler) => { listeners.set(name, handler as (...args: never[]) => void); },
      },
    }, 'http://127.0.0.1:45001');
    for (const name of ['will-navigate', 'will-redirect']) {
      let blocked = false;
      const invoke = listeners.get(name)! as unknown as (event: { preventDefault(): void }, url: string) => void;
      invoke({ preventDefault: () => { blocked = true; } }, 'https://outside.invalid');
      expect(blocked).toBe(true);
      blocked = false;
      invoke({ preventDefault: () => { blocked = true; } }, 'http://127.0.0.1:45001/');
      expect(blocked).toBe(false);
      invoke({ preventDefault: () => { blocked = true; } }, 'http://localhost:45001/');
      expect(blocked).toBe(true);
    }
    expect(popup!({ url: 'http://127.0.0.1:45001/' })).toEqual({ action: 'deny' });
    expect(permissionCheck!()).toBe(false);
    let allowed = true;
    permission!({}, 'camera', (value: boolean) => { allowed = value; }, {});
    expect(allowed).toBe(false);
    for (const name of ['will-attach-webview']) {
      let blocked = false;
      (listeners.get(name)! as unknown as (event: { preventDefault(): void }) => void)({ preventDefault: () => { blocked = true; } });
      expect(blocked).toBe(true);
    }
    const download = listeners.get('will-download')! as unknown as (event: { preventDefault(): void }, item: { getURL(): string; getMimeType(): string; getFilename(): string }) => void;
    for (const [url, mime, filename, expected] of [
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', 'run_123-result.json', false],
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', 'run_123-snapshot_123.json', false],
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', 'run_123-result_extra.json', false],
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', 'run_123-ocr.json', false],
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', '5b2a90fe-1122-3344-5566-aabbccddeeff-5b2a90fe-1122-3344-5566-aabbccddeeff.json', false],
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', 'arbitrary.json', true],
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', 'run_123-input.png.json', true],
      ['https://outside.invalid/file.json', 'application/json', 'result.json', true],
      ['blob:http://localhost:45001/uuid', 'application/json', 'result.json', true],
      ['blob:http://127.0.0.1:45001/uuid', 'application/octet-stream', 'exploit.exe', true],
      ['blob:http://127.0.0.1:45001/uuid', 'application/json', '../result.json', true],
    ] as const) {
      let blocked = false;
      download({ preventDefault: () => { blocked = true; } }, { getURL: () => url, getMimeType: () => mime, getFilename: () => filename });
      expect(blocked).toBe(expected);
    }
  });
  it('waits for active execution cancellation and saving before exiting; close is idempotent', async () => {
    const sequence: string[] = [];
    let release!: () => void;
    const pending = new Promise<void>(resolve => { release = resolve; });
    const shutdown = shutdownDesktop({ close: async () => { sequence.push('cancel-and-save'); await pending; sequence.push('server-closed'); } }, code => { sequence.push(`exit-${code}`); });
    const first = shutdown();
    const second = shutdown();
    expect(first).toBe(second);
    expect(sequence).toEqual(['cancel-and-save']);
    release(); await first;
    expect(sequence).toEqual(['cancel-and-save', 'server-closed', 'exit-0']);
  });
});
