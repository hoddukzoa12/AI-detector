import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:infocutter_app/models/browser_model_codec.dart';
import 'package:infocutter_app/services/browser_persistence.dart';
import 'package:infocutter_app/services/window_service.dart';
import 'package:infocutter_app/util.dart';
import 'web_archive_model.dart';
import 'window_model.dart';

import 'favorite_model.dart';

import 'default_site_model.dart';
import 'search_engine_model.dart';
import 'package:collection/collection.dart';

part 'browser_model_persistence.dart';

enum BrowserThemeMode { system, light, dark }

extension BrowserThemeModeX on BrowserThemeMode {
  ThemeMode get materialThemeMode => switch (this) {
        BrowserThemeMode.system => ThemeMode.system,
        BrowserThemeMode.light => ThemeMode.light,
        BrowserThemeMode.dark => ThemeMode.dark,
      };

  static BrowserThemeMode fromMaterial(ThemeMode mode) => switch (mode) {
        ThemeMode.system => BrowserThemeMode.system,
        ThemeMode.light => BrowserThemeMode.light,
        ThemeMode.dark => BrowserThemeMode.dark,
      };
}

class BrowserSettings {
  SearchEngineModel searchEngine;
  DefaultSiteModel defaultSite;
  bool homePageEnabled;
  String customUrlHomePage;
  bool debuggingEnabled;
  BrowserThemeMode themeMode;

  BrowserSettings(
      {this.searchEngine = GoogleSearchEngine,
      this.defaultSite = GoogleDefaultSite,
      this.homePageEnabled = false,
      this.customUrlHomePage = "",
      this.debuggingEnabled = false,
      this.themeMode = BrowserThemeMode.system});

  BrowserSettings copy() {
    return BrowserSettings(
        searchEngine: searchEngine,
        defaultSite: defaultSite,
        homePageEnabled: homePageEnabled,
        customUrlHomePage: customUrlHomePage,
        debuggingEnabled: debuggingEnabled,
        themeMode: themeMode);
  }

  static BrowserSettings? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }

    return BrowserSettings(
        searchEngine: _valueAtOrDefault(
            SearchEngines, map["searchEngineIndex"], GoogleSearchEngine),
        defaultSite: _valueAtOrDefault(
            DefaultSites, map["defaultSiteIndex"], GoogleDefaultSite),
        homePageEnabled: map["homePageEnabled"] == true,
        customUrlHomePage: map["customUrlHomePage"] as String? ?? "",
        debuggingEnabled: map["debuggingEnabled"] == true,
        themeMode: _themeModeFromName(map["themeMode"]));
  }

  static BrowserThemeMode _themeModeFromName(Object? value) {
    if (value is String) {
      return BrowserThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => BrowserThemeMode.system,
      );
    }
    return BrowserThemeMode.system;
  }

  static T _valueAtOrDefault<T>(List<T> values, Object? index, T fallback) {
    if (index is int && index >= 0 && index < values.length) {
      return values[index];
    }
    return fallback;
  }

  String get startPageUrl {
    final customHomePage = customUrlHomePage.trim();
    if (homePageEnabled && customHomePage.isNotEmpty) {
      return customHomePage;
    }
    return defaultSite.url;
  }

  Map<String, dynamic> toMap() {
    return {
      "searchEngineIndex": SearchEngines.indexOf(searchEngine),
      "defaultSiteIndex": DefaultSites.indexOf(defaultSite),
      "homePageEnabled": homePageEnabled,
      "customUrlHomePage": customUrlHomePage,
      "debuggingEnabled": debuggingEnabled,
      "themeMode": themeMode.name
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

class BrowserModel extends ChangeNotifier {
  BrowserModel({
    BrowserPersistence? persistence,
    WindowPersistence? windowPersistence,
    WindowLauncher windowLauncher = const NoopWindowLauncher(),
    bool Function()? isMobile,
  })  : _persistence = persistence,
        _windowPersistence = windowPersistence,
        _windowLauncher = windowLauncher,
        _isMobile = isMobile ?? Util.isMobile;

  final BrowserPersistence? _persistence;
  final WindowPersistence? _windowPersistence;
  final WindowLauncher _windowLauncher;
  final bool Function() _isMobile;
  final List<FavoriteModel> _favorites = [];
  final Map<String, WebArchiveModel> _webArchives = {};
  BrowserSettings _settings = BrowserSettings();

  bool _showTabScroller = false;

  bool get showTabScroller => _showTabScroller;

  set showTabScroller(bool value) {
    if (value != _showTabScroller) {
      _showTabScroller = value;
      notifyListeners();
    }
  }

  UnmodifiableListView<FavoriteModel> get favorites =>
      UnmodifiableListView(_favorites);

  UnmodifiableMapView<String, WebArchiveModel> get webArchives =>
      UnmodifiableMapView(_webArchives);

  Future<void> openWindow(WindowModel? windowModel) async {
    if (_isMobile()) {
      return;
    }

    final opened = await _windowLauncher.openWindow(
      initialWindowId: windowModel?.id,
    );
    if (opened) {
      if (kDebugMode) {
        debugPrint("Window created");
      }
    } else {
      if (kDebugMode) {
        debugPrint("Cannot create window");
      }
    }

    notifyListeners();
  }

  Future<void> removeWindow(WindowModel window) async {
    await window.removeInfo();
  }

  Future<void> removeAllWindows() async {
    final persistence = _persistence;
    if (persistence == null) {
      if (kDebugMode) {
        debugPrint("Cannot delete windows");
      }
      return;
    }
    try {
      await persistence.deleteAllWindows();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Cannot delete windows: $e");
      }
    }
  }

  bool containsFavorite(FavoriteModel favorite) {
    return _favorites.contains(favorite) ||
        _favorites
                .map((e) => e)
                .firstWhereOrNull((element) => element.url == favorite.url) !=
            null;
  }

  void addFavorite(FavoriteModel favorite) {
    _favorites.add(favorite);
    notifyListeners();
  }

  void addFavorites(List<FavoriteModel> favorites) {
    _favorites.addAll(favorites);
    notifyListeners();
  }

  void clearFavorites() {
    _favorites.clear();
    notifyListeners();
  }

  void removeFavorite(FavoriteModel favorite) {
    if (!_favorites.remove(favorite)) {
      var favToRemove = _favorites
          .map((e) => e)
          .firstWhereOrNull((element) => element.url == favorite.url);
      _favorites.remove(favToRemove);
    }

    notifyListeners();
  }

  void addWebArchive(String url, WebArchiveModel webArchiveModel) {
    _webArchives.putIfAbsent(url, () => webArchiveModel);
    notifyListeners();
  }

  void addWebArchives(Map<String, WebArchiveModel> webArchives) {
    _webArchives.addAll(webArchives);
    notifyListeners();
  }

  void removeWebArchive(WebArchiveModel webArchive) {
    var path = webArchive.path;
    if (path != null) {
      final webArchiveFile = File(path);
      try {
        webArchiveFile.deleteSync();
      } finally {
        _webArchives.remove(webArchive.url.toString());
      }
      notifyListeners();
    }
  }

  void clearWebArchives() {
    final keys = _webArchives.keys.toList();
    for (final key in keys) {
      final path = _webArchives[key]?.path;
      if (path != null) {
        final webArchiveFile = File(path);
        try {
          webArchiveFile.deleteSync();
        } finally {
          _webArchives.remove(key);
        }
      }
    }

    notifyListeners();
  }

  BrowserSettings getSettings() {
    return _settings.copy();
  }

  BrowserSettings get settingsSnapshot => _settings;

  void updateSettings(BrowserSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  DateTime _lastTrySave = DateTime.now();
  Timer? _timerSave;

  Map<String, dynamic> toMap() {
    return BrowserModelCodec.toMap(this);
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return toMap().toString();
  }
}
