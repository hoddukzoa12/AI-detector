import { app, BrowserWindow, dialog } from 'electron';
import { access } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { loadRuntimeConfig } from '../application/index.js';
import { startServer } from '../server/index.js';
import { desktopPaths, desktopWindowOptions, existingInstanceExitCode, guardDesktopContents, shutdownDesktop } from './policy.js';

app.disableHardwareAcceleration();
app.enableSandbox();
const acquired = app.requestSingleInstanceLock();
if (!acquired) {
  const code = existingInstanceExitCode(process.argv);
  if (code !== 0) dialog.showErrorBox('자체 점검 시작 실패', '기존 점검 앱을 종료한 뒤 --self-test를 다시 실행하세요.');
  app.exit(code);
}
else {
  // Electron must finish evaluating this ESM entry before it can emit ready.
  void app.whenReady().then(async () => {
    const exePath = app.getPath('exe');
    const paths = desktopPaths(process.resourcesPath, app.getAppPath());
    await access(paths.executablePath);
    if (process.argv.includes('--self-test')) {
      await access(paths.selfTestPath);
      await access(paths.nodePath);
      const config = await loadRuntimeConfig({ mode: 'desktop', exePath });
      const child = spawn(paths.nodePath, [paths.selfTestPath, '--mode', 'desktop', '--exe-path', exePath,
        '--chromium-path', paths.executablePath, '--output-dir', config.outputRoot], { stdio: 'inherit', windowsHide: true });
      child.once('error', () => app.exit(1));
      child.once('exit', code => app.exit(code ?? 1));
    } else {
      const server = await startServer({ mode: 'desktop', exePath, host: '127.0.0.1', port: 0,
        publicDir: paths.publicDir, executablePath: paths.executablePath });
      const window = new BrowserWindow(desktopWindowOptions);
      window.removeMenu();
      guardDesktopContents(window.webContents, server.url);
      const shutdown = shutdownDesktop(server, code => app.exit(code));
      // Window closing and application quitting await the same cancellation/save promise.
      window.on('close', event => { event.preventDefault(); window.hide(); void shutdown(); });
      app.on('before-quit', event => { event.preventDefault(); void shutdown(); });
      app.on('second-instance', () => { if (!window.isDestroyed()) { window.show(); window.focus(); } });
      window.once('ready-to-show', () => window.show());
      await window.loadURL(server.url);
    }
  }).catch(() => {
    dialog.showErrorBox('점검 앱 시작 실패', '실행 설정, Chromium 파일, 출력 폴더 권한을 확인하세요. 키 값은 표시하지 않습니다.');
    app.exit(1);
  });
}
