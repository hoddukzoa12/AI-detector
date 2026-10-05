part of 'window_model.dart';

extension WindowModelPersistence on WindowModel {
  Future<void> saveInfo() async {
    _timerSave?.cancel();

    if (!_shouldSave) {
      return;
    }

    if (DateTime.now().difference(_lastTrySave) >=
        const Duration(milliseconds: 400)) {
      _lastTrySave = DateTime.now();
      await flushInfo();
    } else {
      _lastTrySave = DateTime.now();
      _timerSave = Timer(const Duration(milliseconds: 500), () {
        saveInfo();
      });
    }
  }

  Future<void> removeInfo() async {
    final persistence = _persistence;
    if (persistence == null) {
      return;
    }
    try {
      await persistence.deleteWindow(id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Cannot delete window $id: $e");
      }
    }
  }

  Future<void> flushInfo() async {
    if (!_shouldSave) {
      return;
    }
    _updatedTime = DateTime.now();
    final persistence = _persistence;
    if (persistence == null) {
      return;
    }
    try {
      await persistence.saveWindowJson(id, json.encode(toJson()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Cannot insert/update window $id: $e");
      }
    }
  }

  Future<void> restoreInfo() async {
    try {
      final persistence = _persistence;
      if (persistence == null) {
        return;
      }

      final source = await _loadWindowSource(persistence);
      if (source == null) {
        return;
      }

      final browserData = json.decode(source);
      _id = browserData["id"] as String? ?? _id;
      _shouldSave = browserData["shouldSave"] ?? false;

      closeAllTabs();
      addTabs(WindowModelCodec.webViewModelsFromMap(browserData));

      final currentTabIndex = WindowModelCodec.currentTabIndexFromMap(
        browserData,
        fallback: _currentTabIndex,
        maxIndex: _webViewModels.length - 1,
      );
      if (currentTabIndex >= 0) {
        showTab(currentTabIndex);
      }

      await flushInfo();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<String?> _loadWindowSource(WindowPersistence persistence) async {
    if (!Util.isDesktop()) {
      return persistence.loadFirstWindowJson();
    }

    final windowId = persistence.initialWindowId;
    return windowId != null ? persistence.loadWindowJson(windowId) : null;
  }
}
