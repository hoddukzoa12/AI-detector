import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/default_site_model.dart';
import 'package:infocutter_app/models/search_engine_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/browser_persistence.dart';
import 'package:infocutter_app/services/browser_url_resolver.dart';
import 'package:infocutter_app/services/window_service.dart';

void main() {
  group('BrowserSettings', () {
    test('startPageUrl uses selected default site by default', () {
      final settings = BrowserSettings(defaultSite: NaverDefaultSite);

      expect(settings.startPageUrl, 'https://www.naver.com/');
    });

    test('startPageUrl uses custom home page when home page is enabled', () {
      final settings = BrowserSettings(
        defaultSite: NaverDefaultSite,
        homePageEnabled: true,
        customUrlHomePage: 'https://example.com/dashboard',
      );

      expect(settings.startPageUrl, 'https://example.com/dashboard');
    });

    test('fromMap supports older settings without defaultSiteIndex', () {
      final settings = BrowserSettings.fromMap({
        'searchEngineIndex': 3,
        'homePageEnabled': true,
        'customUrlHomePage': '',
        'debuggingEnabled': true,
      });

      expect(settings?.searchEngine, DuckDuckGoSearchEngine);
      expect(settings?.defaultSite, GoogleDefaultSite);
      expect(settings?.startPageUrl, 'https://www.google.com/');
    });

    test('fromMap falls back on invalid indexes and missing booleans', () {
      final settings = BrowserSettings.fromMap({
        'searchEngineIndex': 999,
        'defaultSiteIndex': -1,
      });

      expect(settings?.searchEngine, GoogleSearchEngine);
      expect(settings?.defaultSite, GoogleDefaultSite);
      expect(settings?.homePageEnabled, isFalse);
      expect(settings?.debuggingEnabled, isFalse);
      expect(settings?.themeMode, BrowserThemeMode.system);
    });

    test('theme mode persists as a stable string', () {
      final settings = BrowserSettings(themeMode: BrowserThemeMode.light);

      expect(settings.toMap()['themeMode'], 'light');
      expect(BrowserSettings.fromMap(settings.toMap())?.themeMode,
          BrowserThemeMode.light);
    });

    test('url resolver opens domain input as https url', () {
      final url = const BrowserUrlResolver().resolve(
        'naver.com',
        BrowserSettings(),
      );

      expect(url.toString(), 'https://naver.com');
    });

    test('url resolver sends plain text through selected search engine', () {
      final url = const BrowserUrlResolver().resolve(
        'flutter automation',
        BrowserSettings(searchEngine: DuckDuckGoSearchEngine),
      );

      expect(url.toString(), contains('duckduckgo.com'));
      expect(url.toString(), contains('flutter%20automation'));
    });
  });

  group('BrowserModel persistence', () {
    test('flush saves through BrowserPersistence', () async {
      final persistence = _FakePersistence();
      final model = BrowserModel(persistence: persistence);
      model.updateSettings(BrowserSettings(defaultSite: NaverDefaultSite));

      await model.flush();

      expect(persistence.savedBrowserJson, isNotNull);
      final saved = jsonDecode(persistence.savedBrowserJson!);
      expect(saved['settings']['defaultSiteIndex'], 1);
      expect(saved['settings']['themeMode'], 'system');
    });

    test('restore loads through BrowserPersistence', () async {
      final persistence = _FakePersistence()
        ..browserJson = jsonEncode({
          'favorites': [],
          'webArchives': {},
          'settings': {
            'defaultSiteIndex': 1,
            'homePageEnabled': true,
            'customUrlHomePage': '',
            'themeMode': 'dark',
          },
        });
      final model = BrowserModel(persistence: persistence);

      await model.restore();

      expect(model.getSettings().defaultSite, NaverDefaultSite);
      expect(model.getSettings().startPageUrl, 'https://www.naver.com/');
      expect(model.getSettings().themeMode, BrowserThemeMode.dark);
    });

    test('getWindows maps persisted window JSON into models', () async {
      final persistence = _FakePersistence()
        ..windowJsons = [
          jsonEncode({
            'id': 'window_test',
            'name': 'Saved',
            'webViewTabs': [],
            'currentTabIndex': -1,
            'shouldSave': true,
            'updatedTime': DateTime.utc(2026).toIso8601String(),
            'createdTime': DateTime.utc(2026).toIso8601String(),
          })
        ];
      final model = BrowserModel(
        persistence: persistence,
        windowPersistence: persistence,
      );

      final windows = await model.getWindows();

      expect(windows, hasLength(1));
      expect(windows.single.id, 'window_test');
    });

    test('openWindow delegates native creation through WindowLauncher',
        () async {
      final launcher = _FakeWindowLauncher()..result = true;
      final model = BrowserModel(
        windowLauncher: launcher,
        isMobile: () => false,
      );
      final windowModel = WindowModel(id: 'window_test');

      await model.openWindow(windowModel);

      expect(launcher.openedWindowIds, ['window_test']);
    });

    test('openWindow skips native creation on mobile platforms', () async {
      final launcher = _FakeWindowLauncher()..result = true;
      final model = BrowserModel(
        windowLauncher: launcher,
        isMobile: () => true,
      );

      await model.openWindow(WindowModel(id: 'window_test'));

      expect(launcher.openedWindowIds, isEmpty);
    });
  });

  group('WindowModel persistence', () {
    test('stores serializable WebViewModel tabs without widget ownership', () {
      final model = WindowModel(id: 'window_test');
      final webViewModel = WebViewModel(url: WebUri('https://example.com'));

      model.addTab(webViewModel);

      expect(model.webViewModels.single, same(webViewModel));
      expect(model.getCurrentWebViewModel(), same(webViewModel));
      final saved = model.toMap();
      expect(saved['webViewTabs'], hasLength(1));
      expect(saved['webViewTabs'].single['url'], 'https://example.com');
    });

    test('flushInfo saves through WindowPersistence', () async {
      final persistence = _FakePersistence();
      final model = WindowModel(
        id: 'window_test',
        shouldSave: true,
        persistence: persistence,
      );

      await model.flushInfo();

      expect(persistence.savedWindowIds, ['window_test']);
      expect(persistence.savedWindowJsons, hasLength(1));
    });

    test('removeInfo deletes through WindowPersistence', () async {
      final persistence = _FakePersistence();
      final model = WindowModel(
        id: 'window_test',
        persistence: persistence,
      );

      await model.removeInfo();

      expect(persistence.deletedWindowIds, ['window_test']);
    });
  });
}

class _FakeWindowLauncher implements WindowLauncher {
  bool result = false;
  final openedWindowIds = <String?>[];

  @override
  Future<bool> openWindow({String? initialWindowId}) async {
    openedWindowIds.add(initialWindowId);
    return result;
  }
}

class _FakePersistence implements BrowserPersistence, WindowPersistence {
  String? browserJson;
  String? savedBrowserJson;
  List<String> windowJsons = [];
  final savedWindowIds = <String>[];
  final savedWindowJsons = <String>[];
  final deletedWindowIds = <String>[];

  @override
  String? initialWindowId;

  @override
  Future<void> deleteAllWindows() async {
    windowJsons = [];
  }

  @override
  Future<void> deleteWindow(String id) async {
    deletedWindowIds.add(id);
  }

  @override
  Future<String?> loadBrowserJson() async {
    return browserJson;
  }

  @override
  Future<String?> loadFirstWindowJson() async {
    return windowJsons.isEmpty ? null : windowJsons.first;
  }

  @override
  Future<String?> loadWindowJson(String id) async {
    for (final raw in windowJsons) {
      if (jsonDecode(raw)['id'] == id) {
        return raw;
      }
    }
    return null;
  }

  @override
  Future<List<String>> loadWindowJsons() async {
    return windowJsons;
  }

  @override
  Future<void> saveBrowserJson(String raw) async {
    savedBrowserJson = raw;
  }

  @override
  Future<void> saveWindowJson(String id, String raw) async {
    savedWindowIds.add(id);
    savedWindowJsons.add(raw);
  }
}
