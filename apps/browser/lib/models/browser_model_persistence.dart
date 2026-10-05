part of 'browser_model.dart';

extension BrowserModelPersistence on BrowserModel {
  Future<List<WindowModel>> getWindows() async {
    final persistence = _persistence;
    if (persistence == null) {
      return [];
    }
    final windowJsons = await persistence.loadWindowJsons();
    return windowJsons
        .map((source) => json.decode(source))
        .whereType<Map<String, dynamic>>()
        .map((data) => WindowModel.fromMap(
              data,
              persistence: _windowPersistence,
            ))
        .toList();
  }

  Future<void> save() async {
    _timerSave?.cancel();

    if (DateTime.now().difference(_lastTrySave) >=
        const Duration(milliseconds: 400)) {
      _lastTrySave = DateTime.now();
      await flush();
    } else {
      _lastTrySave = DateTime.now();
      _timerSave = Timer(const Duration(milliseconds: 500), () {
        save();
      });
    }
  }

  Future<void> flush() async {
    final persistence = _persistence;
    if (persistence == null) {
      return;
    }
    try {
      await persistence.saveBrowserJson(json.encode(toJson()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Cannot insert/update browser 1: $e");
      }
    }
  }

  Future<void> restore() async {
    final persistence = _persistence;
    if (persistence == null) {
      return;
    }
    final source = await persistence.loadBrowserJson();
    if (source == null) {
      return;
    }

    try {
      final browserData = json.decode(source);
      clearFavorites();
      clearWebArchives();
      addFavorites(BrowserModelCodec.favoritesFromMap(browserData));
      addWebArchives(BrowserModelCodec.webArchivesFromMap(browserData));
      updateSettings(BrowserModelCodec.settingsFromMap(browserData));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }
}
