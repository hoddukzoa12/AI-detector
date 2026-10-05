import 'package:flutter/foundation.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';

/// Browser / Window / 현재 탭 변경을 영속 저장에 한 번만 연결한다.
///
/// 과거에는 `build` 안에서 `addListener` 를 호출해 리빌드마다 리스너가 쌓였다.
class BrowserPersistenceBindings {
  BrowserModel? _browser;
  WindowModel? _window;
  WebViewModel? _currentTab;

  VoidCallback? _onBrowser;
  VoidCallback? _onWindow;
  VoidCallback? _onTab;
  VoidCallback? _onWindowTabs;

  /// 모델 인스턴스가 바뀌면 재바인딩. 같으면 no-op.
  void bind({
    required BrowserModel browser,
    required WindowModel window,
  }) {
    if (!identical(_browser, browser)) {
      _detachBrowser();
      _browser = browser;
      _onBrowser = () {
        browser.save();
      };
      browser.addListener(_onBrowser!);
    }

    if (!identical(_window, window)) {
      _detachWindow();
      _window = window;
      _onWindow = () {
        window.saveInfo();
      };
      window.addListener(_onWindow!);
      // 탭 전환 시 현재 탭 모델 리스너를 갈아낀다.
      _onWindowTabs = () => bindCurrentTab(window.getCurrentWebViewModel());
      window.addListener(_onWindowTabs!);
      bindCurrentTab(window.getCurrentWebViewModel());
    }
  }

  void bindCurrentTab(WebViewModel? tab) {
    if (identical(_currentTab, tab)) return;
    _detachTab();
    _currentTab = tab;
    final window = _window;
    if (tab == null || window == null) return;
    _onTab = () {
      window.saveInfo();
    };
    tab.addListener(_onTab!);
  }

  void dispose() {
    _detachTab();
    _detachWindow();
    _detachBrowser();
  }

  void _detachBrowser() {
    final browser = _browser;
    final listener = _onBrowser;
    if (browser != null && listener != null) {
      browser.removeListener(listener);
    }
    _browser = null;
    _onBrowser = null;
  }

  void _detachWindow() {
    final window = _window;
    if (window != null) {
      if (_onWindow != null) window.removeListener(_onWindow!);
      if (_onWindowTabs != null) window.removeListener(_onWindowTabs!);
    }
    _window = null;
    _onWindow = null;
    _onWindowTabs = null;
  }

  void _detachTab() {
    final tab = _currentTab;
    final listener = _onTab;
    if (tab != null && listener != null) {
      tab.removeListener(listener);
    }
    _currentTab = null;
    _onTab = null;
  }
}
