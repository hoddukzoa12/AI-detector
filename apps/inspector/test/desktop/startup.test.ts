import { afterEach, expect, it, vi } from 'vitest';
import { EventEmitter } from 'node:events';
import { setTimeout as delay } from 'node:timers/promises';

const originalArgv = process.argv;
const originalResources = Object.getOwnPropertyDescriptor(process, 'resourcesPath');
afterEach(() => {
  process.argv = originalArgv;
  if (originalResources) Object.defineProperty(process, 'resourcesPath', originalResources);
  else Reflect.deleteProperty(process, 'resourcesPath');
  vi.doUnmock('electron'); vi.doUnmock('node:fs/promises'); vi.doUnmock('node:child_process');
  vi.doUnmock('../../src/application/index.js'); vi.doUnmock('../../src/server/index.js'); vi.resetModules();
});

async function startup(selfTest: boolean) {
  process.argv = ['Inspektor.exe', ...(selfTest ? ['--self-test'] : [])];
  Object.defineProperty(process, 'resourcesPath', { value: '/pkg/resources', configurable: true });
  let ready!: () => void;
  const readiness = new Promise<void>(resolve => { ready = resolve; });
  const child = new EventEmitter();
  const exit = vi.fn(); const spawn = vi.fn(() => child);
  const loadURL = vi.fn(async () => {}); const windows: unknown[] = [];
  const startServer = vi.fn(async () => ({ url: 'http://127.0.0.1:12345', close: vi.fn(async () => {}) }));
  const app = { disableHardwareAcceleration: vi.fn(), enableSandbox: vi.fn(), requestSingleInstanceLock: () => true,
    whenReady: vi.fn(() => readiness), getPath: () => '/pkg/Inspektor.exe', getAppPath: () => '/pkg/resources/app',
    on: vi.fn(), exit };
  class Window {
    constructor(options: unknown) { windows.push(options); }
    webContents = { getURL: () => 'http://127.0.0.1:12345', on: vi.fn(), setWindowOpenHandler: vi.fn(), session: {
      setPermissionRequestHandler: vi.fn(), setPermissionCheckHandler: vi.fn(), on: vi.fn(),
    } };
    removeMenu = vi.fn(); on = vi.fn(); once = vi.fn(); hide = vi.fn(); show = vi.fn(); focus = vi.fn();
    isDestroyed = () => false; loadURL = loadURL;
  }
  vi.doMock('electron', () => ({ app, BrowserWindow: Window, dialog: { showErrorBox: vi.fn() } }));
  vi.doMock('node:fs/promises', () => ({ access: vi.fn(async () => {}) }));
  vi.doMock('node:child_process', () => ({ spawn }));
  vi.doMock('../../src/application/index.js', () => ({ loadRuntimeConfig: vi.fn(async () => ({ outputRoot: '/output' })) }));
  vi.doMock('../../src/server/index.js', () => ({ startServer }));
  // Electron completes the ESM entry's evaluation before issuing app.ready.
  // Resolving readiness only after import proves both startup paths avoid that cycle.
  const entry = import('../../src/desktop/main.js');
  try {
    expect(await Promise.race([entry.then(() => 'evaluated'), delay(1500, 'blocked')])).toBe('evaluated');
    expect(app.whenReady).toHaveBeenCalledOnce(); expect(startServer).not.toHaveBeenCalled(); expect(spawn).not.toHaveBeenCalled();
    ready(); await entry;
    if (selfTest) {
      await vi.waitFor(() => expect(spawn).toHaveBeenCalledOnce());
      expect(spawn.mock.calls[0]).toEqual(['/pkg/resources/runtime/node.exe', [
        '/pkg/resources/app/dist/self-test.mjs', '--mode', 'desktop', '--exe-path', '/pkg/Inspektor.exe',
        '--chromium-path', '/pkg/resources/browser/chrome-win64/chrome.exe', '--output-dir', '/output',
      ], { stdio: 'inherit', windowsHide: true }]);
      child.emit('exit', 7); expect(exit).toHaveBeenCalledWith(7); expect(windows).toEqual([]);
    } else {
      await vi.waitFor(() => expect(loadURL).toHaveBeenCalledWith('http://127.0.0.1:12345'));
      expect(windows).toHaveLength(1); expect(spawn).not.toHaveBeenCalled();
      expect(windows[0]).toMatchObject({ webPreferences: { sandbox: true, contextIsolation: true, nodeIntegration: false } });
    }
  } finally { ready(); await entry; }
}
it('evaluates the ESM entry before app readiness, then boots the private GUI', async () => { await startup(false); });
it('evaluates before app readiness, then delegates self-test and preserves its exit code', async () => { await startup(true); });
