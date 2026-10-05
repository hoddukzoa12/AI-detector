import { resolve } from 'node:path';
import type { BrowserWindowConstructorOptions } from 'electron';

export const desktopWindowOptions: BrowserWindowConstructorOptions = {
  width: 1200, height: 850, minWidth: 800, minHeight: 600, show: false,
  title: '공개 웹사이트 점검', autoHideMenuBar: true,
  webPreferences: { nodeIntegration: false, contextIsolation: true, sandbox: true, devTools: false, webviewTag: false },
};
export function existingInstanceExitCode(argv: readonly string[]): number { return argv.includes('--self-test') ? 2 : 0; }
export function desktopPaths(resourcesPath: string, appPath: string) {
  return {
    publicDir: resolve(appPath, 'dist/public'),
    executablePath: resolve(resourcesPath, 'browser/chrome-win64/chrome.exe'),
    nodePath: resolve(resourcesPath, 'runtime/node.exe'),
    selfTestPath: resolve(appPath, 'dist/self-test.mjs'),
  };
}
interface Preventable { preventDefault(): void }
interface GuardedContents {
  getURL(): string;
  on(name: 'will-navigate' | 'will-redirect', listener: (event: Preventable, url: string) => void): unknown;
  on(name: 'will-attach-webview', listener: (event: Preventable) => void): unknown;
  setWindowOpenHandler(handler: (details: { url: string }) => { action: 'deny' }): void;
  session: {
    setPermissionRequestHandler(handler: (_contents: unknown, _permission: string, callback: (granted: boolean) => void) => void): void;
    setPermissionCheckHandler(handler: () => boolean): void;
    on(name: 'will-download', handler: (event: Preventable, item: { getURL(): string; getMimeType(): string; getFilename(): string }) => void): unknown;
  };
}
/** Only the private HTTP UI may occupy the window. No renderer-to-Node bridge exists. */
export function guardDesktopContents(contents: GuardedContents, serverUrl: string): void {
  const origin = new URL(serverUrl).origin;
  const navigate = (event: Preventable, target: string) => {
    try { if (new URL(target).origin === origin) return; } catch { /* Deny malformed URLs too. */ }
    event.preventDefault();
  };
  contents.on('will-navigate', navigate);
  contents.on('will-redirect', navigate);
  contents.on('will-attach-webview', event => event.preventDefault());
  contents.setWindowOpenHandler(() => ({ action: 'deny' }));
  contents.session.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
  contents.session.setPermissionCheckHandler(() => false);
  contents.session.on('will-download', (event, item) => {
    try {
      const target = new URL(item.getURL());
      if (new URL(contents.getURL()).origin === origin && target.protocol === 'blob:' && target.origin === origin &&
          item.getMimeType() === 'application/json' && /^[A-Za-z0-9][A-Za-z0-9_-]{0,128}-(?:result(?:_extra)?|scan-status|review|finding-details|ocr|snapshot_[A-Za-z0-9_-]{1,128}|[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\.json$/.test(item.getFilename())) return;
    } catch { /* Fail closed on malformed download metadata. */ }
    event.preventDefault();
  });
}
/** Server.close already cancels active application work and awaits its durable save. */
export function shutdownDesktop(server: { close(): Promise<void> }, exit: (code: number) => void): () => Promise<void> {
  let pending: Promise<void> | undefined;
  return () => pending ??= (async () => {
    try { await server.close(); exit(0); }
    catch { exit(1); }
  })();
}
