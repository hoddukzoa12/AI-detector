abstract interface class WindowLauncher {
  Future<bool> openWindow({String? initialWindowId});
}

abstract interface class WindowControls {
  Future<void> close();
  Future<void> minimizeIfNotFullScreen();
  Future<void> toggleFullScreen();
  Future<void> setMovable(bool movable);
  Future<void> maximize();
}

class NoopWindowLauncher implements WindowLauncher {
  const NoopWindowLauncher();

  @override
  Future<bool> openWindow({String? initialWindowId}) async => false;
}
