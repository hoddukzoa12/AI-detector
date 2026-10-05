import 'package:infocutter_app/services/window_service.dart';
import 'package:window_manager_plus/window_manager_plus.dart';

class WindowManagerPlusWindowLauncher implements WindowLauncher {
  const WindowManagerPlusWindowLauncher();

  @override
  Future<bool> openWindow({String? initialWindowId}) async {
    final window = await WindowManagerPlus.createWindow(
      initialWindowId == null ? null : [initialWindowId],
    );
    return window != null;
  }
}

class WindowManagerPlusWindowControls implements WindowControls {
  const WindowManagerPlusWindowControls();

  @override
  Future<void> close() {
    return WindowManagerPlus.current.close();
  }

  @override
  Future<void> minimizeIfNotFullScreen() async {
    if (!(await WindowManagerPlus.current.isFullScreen())) {
      await WindowManagerPlus.current.minimize();
    }
  }

  @override
  Future<void> toggleFullScreen() async {
    await WindowManagerPlus.current.setFullScreen(
      !(await WindowManagerPlus.current.isFullScreen()),
    );
  }

  @override
  Future<void> setMovable(bool movable) {
    return WindowManagerPlus.current.setMovable(movable);
  }

  @override
  Future<void> maximize() {
    return WindowManagerPlus.current.maximize();
  }
}
