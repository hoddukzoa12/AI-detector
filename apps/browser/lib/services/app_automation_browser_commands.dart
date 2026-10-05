part of 'app_automation_controller.dart';

/// 쿠키의 부가 속성 — 이름·값을 뺀 나머지. RFC 6265 의 속성 집합에 대응하며,
/// 하나의 도메인 개념이므로 개별 인자로 흩어놓지 않고 묶어서 넘긴다.
class CookieAttributes {
  const CookieAttributes({
    this.urlArg,
    this.domain,
    this.path,
    this.isSecure,
    this.isHttpOnly,
  });

  final String? urlArg;
  final String? domain;
  final String? path;
  final bool? isSecure;
  final bool? isHttpOnly;
}

class _AppAutomationBrowserCommands {
  const _AppAutomationBrowserCommands({
    required BrowserModel browser,
    required WindowModel window,
  })  : _browser = browser,
        _window = window;

  final BrowserModel _browser;
  final WindowModel _window;

  Future<AppAutomationResult> openTab(
    String target, {
    bool incognito = false,
  }) async {
    final url = normalizeTarget(target, _browser.getSettings());
    _window.addTab(WebViewModel(url: url, isIncognitoMode: incognito));
    return AppAutomationResult.success('tab.open', {
      'index': _window.getCurrentTabIndex(),
      'url': url.toString(),
    });
  }

  Future<AppAutomationResult> selectTab(int index) async {
    _ensureTabIndex(index);
    _window.showTab(index);
    return AppAutomationResult.success('tab.select', {'index': index});
  }

  Future<AppAutomationResult> closeTab(int index) async {
    _ensureTabIndex(index);
    _window.closeTab(index);
    return AppAutomationResult.success('tab.close', {
      'currentTabIndex': _window.getCurrentTabIndex(),
      'tabCount': _window.webViewModels.length,
    });
  }

  Future<AppAutomationResult> closeAllTabs() async {
    _window.closeAllTabs();
    return AppAutomationResult.success('tab.closeAll');
  }

  Future<AppAutomationResult> loadCurrent(String target) async {
    final tab = _requireCurrentTab();
    final url = normalizeTarget(target, _browser.getSettings());
    tab.url = url;
    await tab.webViewController?.loadUrl(urlRequest: URLRequest(url: url));
    return AppAutomationResult.success('page.load', {'url': url.toString()});
  }

  Future<AppAutomationResult> goBack() async {
    await _requireCurrentController().goBack();
    return AppAutomationResult.success('page.back');
  }

  Future<AppAutomationResult> goForward() async {
    await _requireCurrentController().goForward();
    return AppAutomationResult.success('page.forward');
  }

  Future<AppAutomationResult> reload() async {
    await _requireCurrentController().reload();
    return AppAutomationResult.success('page.reload');
  }

  Future<AppAutomationResult> stopLoading() async {
    await _requireCurrentController().stopLoading();
    return AppAutomationResult.success('page.stop');
  }

  Future<AppAutomationResult> goHome() async {
    return loadCurrent(_browser.getSettings().startPageUrl);
  }

  Future<AppAutomationResult> findOnPage(String text) async {
    final controller = _requireCurrentTab().findInteractionController;
    if (controller == null) {
      throw StateError('find interaction is not available for this tab');
    }
    await controller.findAll(find: text);
    return AppAutomationResult.success('page.find', {'text': text});
  }

  Future<AppAutomationResult> findNext({bool forward = true}) async {
    final controller = _requireCurrentTab().findInteractionController;
    if (controller == null) {
      throw StateError('find interaction is not available for this tab');
    }
    await controller.findNext(forward: forward);
    return AppAutomationResult.success('page.findNext', {'forward': forward});
  }

  Future<AppAutomationResult> clearFind() async {
    final controller = _requireCurrentTab().findInteractionController;
    if (controller == null) {
      throw StateError('find interaction is not available for this tab');
    }
    await controller.clearMatches();
    return AppAutomationResult.success('page.clearFind');
  }

  Future<AppAutomationResult> evaluateJavascript(String source) async {
    final value = await _requireCurrentController().evaluateJavascript(
      source: source,
    );
    return AppAutomationResult.success('page.evalJs', {'value': value});
  }

  Future<AppAutomationResult> takeScreenshot() async {
    final bytes = await _requireCurrentController().takeScreenshot();
    return AppAutomationResult.success('page.screenshot', {
      'byteLength': bytes?.lengthInBytes ?? 0,
      'base64Png': bytes == null ? '' : base64Encode(bytes),
    });
  }

  // --- Playwright-style DOM interaction (selectors injected via jsonEncode so
  // user input never breaks out of the JS string). ---

  Future<AppAutomationResult> clickSelector(String selector) async {
    final result = await _requireCurrentController().evaluateJavascript(
      source: '(function(s){'
          'var el=document.querySelector(s);'
          'if(!el)return false;'
          'el.scrollIntoView({block:"center",inline:"center"});'
          'el.click();'
          'return true;'
          '})(${jsonEncode(selector)})',
    );
    return AppAutomationResult.success('page.click', {
      'selector': selector,
      'clicked': result == true,
    });
  }

  Future<AppAutomationResult> fillSelector(
    String selector,
    String value,
  ) async {
    final result = await _requireCurrentController().evaluateJavascript(
      source: '(function(s,v){'
          'var el=document.querySelector(s);'
          'if(!el)return false;'
          'var proto=(el instanceof HTMLTextAreaElement)'
          '?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;'
          'var d=Object.getOwnPropertyDescriptor(proto,"value");'
          'if(d&&d.set){d.set.call(el,v);}else{el.value=v;}'
          'el.dispatchEvent(new Event("input",{bubbles:true}));'
          'el.dispatchEvent(new Event("change",{bubbles:true}));'
          'return true;'
          '})(${jsonEncode(selector)},${jsonEncode(value)})',
    );
    return AppAutomationResult.success('page.fill', {
      'selector': selector,
      'filled': result == true,
    });
  }

  Future<AppAutomationResult> pageCandidates() async {
    final raw = await _requireCurrentController().evaluateJavascript(
      source: aiMaskingCandidateCollectorScript,
    );
    final candidates = parseAiPageCandidates(raw);
    return AppAutomationResult.success('page.candidates', {
      'candidates': candidates.map((c) => c.toJson()).toList(),
      'count': candidates.length,
    });
  }

  Future<AppAutomationResult> getText(String selector) async {
    final value = await _requireCurrentController().evaluateJavascript(
      source: '(function(s){'
          'var el=document.querySelector(s);'
          'return el?(el.innerText||el.textContent||""):null;'
          '})(${jsonEncode(selector)})',
    );
    return AppAutomationResult.success('page.getText', {
      'selector': selector,
      'found': value != null,
      'text': value is String ? value : null,
    });
  }

  Future<AppAutomationResult> waitForSelector(
    String selector, {
    int timeoutMs = 5000,
  }) async {
    final controller = _requireCurrentController();
    final source = '!!document.querySelector(${jsonEncode(selector)})';
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (true) {
      if (await controller.evaluateJavascript(source: source) == true) {
        return AppAutomationResult.success('page.waitForSelector', {
          'selector': selector,
          'found': true,
        });
      }
      if (DateTime.now().isAfter(deadline)) {
        return AppAutomationResult.success('page.waitForSelector', {
          'selector': selector,
          'found': false,
          'timedOut': true,
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<AppAutomationResult> waitForLoad({int timeoutMs = 15000}) async {
    final tab = _requireCurrentTab();
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (!tab.loaded) {
      if (DateTime.now().isAfter(deadline)) {
        return AppAutomationResult.success('page.waitForLoad', {
          'loaded': tab.loaded,
          'progress': tab.progress,
          'timedOut': true,
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return AppAutomationResult.success('page.waitForLoad', {
      'loaded': true,
      'url': tab.url?.toString(),
    });
  }

  // ---------------------------------------------------------------------------
  // Cookie management (token-gated; operates on the shared cookie store)
  // ---------------------------------------------------------------------------

  /// Resolves the URL to use for cookie operations. When [urlArg] is provided
  /// it is used as-is; otherwise the current tab's URL is required.
  WebUri _requireCookieUrl(String? urlArg) {
    if (urlArg != null) return WebUri(urlArg);
    final tab = _requireCurrentTab();
    final url = tab.url;
    if (url == null || url.host.isEmpty) {
      throw StateError('no url with host available for cookie operation');
    }
    return url;
  }

  Future<AppAutomationResult> cookieList(String? urlArg) async {
    final url = _requireCookieUrl(urlArg);
    final cookies = await CookieManager.instance().getCookies(url: url);
    return AppAutomationResult.success('cookie.list', {
      'cookies': cookies
          .map(
            (c) => {
              'name': c.name,
              'value': c.value,
              'domain': c.domain,
              'path': c.path,
              'isSecure': c.isSecure,
              'isHttpOnly': c.isHttpOnly,
              'sameSite': c.sameSite?.toValue(),
              'expiresDate': c.expiresDate,
            },
          )
          .toList(),
      'count': cookies.length,
      'url': url.toString(),
    });
  }

  Future<AppAutomationResult> cookieGet(String? urlArg, String name) async {
    final url = _requireCookieUrl(urlArg);
    final cookie =
        await CookieManager.instance().getCookie(url: url, name: name);
    final mapped = cookie == null
        ? null
        : {
            'name': cookie.name,
            'value': cookie.value,
            'domain': cookie.domain,
            'path': cookie.path,
            'isSecure': cookie.isSecure,
            'isHttpOnly': cookie.isHttpOnly,
            'sameSite': cookie.sameSite?.toValue(),
            'expiresDate': cookie.expiresDate,
          };
    return AppAutomationResult.success('cookie.get', {
      'cookie': mapped,
      'name': name,
    });
  }

  Future<AppAutomationResult> cookieSet({
    required String name,
    required String value,
    CookieAttributes attributes = const CookieAttributes(),
  }) async {
    final url = _requireCookieUrl(attributes.urlArg);
    await CookieManager.instance().setCookie(
      url: url,
      name: name,
      value: value,
      domain: attributes.domain,
      path: attributes.path ?? '/',
      isSecure: attributes.isSecure,
      isHttpOnly: attributes.isHttpOnly,
    );
    return AppAutomationResult.success('cookie.set', {
      'set': true,
      'name': name,
    });
  }

  Future<AppAutomationResult> cookieDelete(String? urlArg, String name) async {
    final url = _requireCookieUrl(urlArg);
    await CookieManager.instance().deleteCookie(url: url, name: name);
    return AppAutomationResult.success('cookie.delete', {
      'deleted': true,
      'name': name,
    });
  }

  // ---------------------------------------------------------------------------
  // browser.clearData (token-gated; destructive)
  // ---------------------------------------------------------------------------

  Future<AppAutomationResult> clearBrowserData({
    bool cookies = true,
    bool cache = true,
    bool storage = true,
  }) async {
    if (cookies) {
      await CookieManager.instance().deleteAllCookies();
    }
    if (cache) {
      await InAppWebViewController.clearAllCache();
    }
    if (storage) {
      await WebStorageManager.instance().deleteAllData();
    }
    return AppAutomationResult.success('browser.clearData', {
      'cleared': {
        'cookies': cookies,
        'cache': cache,
        'storage': storage,
      },
    });
  }

  WebViewModel? _currentTab() => _window.getCurrentWebViewModel();

  WebViewModel _requireCurrentTab() {
    final tab = _currentTab();
    if (tab == null) {
      throw StateError('no current tab');
    }
    return tab;
  }

  InAppWebViewController _requireCurrentController() {
    final controller = _requireCurrentTab().webViewController;
    if (controller == null) {
      throw StateError('current tab has no WebView controller');
    }
    return controller;
  }

  void _ensureTabIndex(int index) {
    if (index < 0 || index >= _window.webViewModels.length) {
      throw RangeError.range(index, 0, _window.webViewModels.length - 1);
    }
  }
}
