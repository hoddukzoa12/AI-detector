import 'dart:async';

// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/app_bar/browser_bottom_action_bar.dart';
import 'package:infocutter_app/app_bar/webview_tab_app_bar.dart';
import 'package:infocutter_app/custom_image.dart';
import 'package:infocutter_app/tab_viewer.dart';
import 'package:infocutter_app/app_bar/browser_app_bar.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/services/browser_persistence_bindings.dart';
import 'package:infocutter_app/util.dart';
import 'package:infocutter_app/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import 'app_bar/tab_viewer_app_bar.dart';
import 'empty_tab.dart';
import 'models/browser_model.dart';
import 'models/window_model.dart';

part 'browser_tab_scroller.dart';
part 'browser_bootstrap_splash.dart';

class Browser extends StatefulWidget {
  const Browser({super.key});

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.dalsoop.infocutter.intent_data');

  final _webViewTabAppBarController = WebViewTabAppBarController();
  final _persistence = BrowserPersistenceBindings();
  var _isRestored = false;
  /// 세션 복원·초기 인텐트가 끝나기 전 순백 빈 화면을 막는다.
  var _bootstrapReady = false;

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_onPlatformCall);
  }

  @override
  void dispose() {
    _persistence.dispose();
    super.dispose();
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'openUrl') {
      final url = call.arguments;
      if (url is String && url.isNotEmpty) {
        _openExternalUrl(url);
      }
    }
    return null;
  }

  void _openExternalUrl(String url) {
    if (!mounted) return;
    final normalized = _normalizeExternalUrl(url);
    if (normalized.isEmpty) return;
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    windowModel.addTab(WebViewModel(url: WebUri(normalized)));
  }

  /// `infocutter://https://…` · `infocutter://host` 형태를 브라우저 로드용 URL로.
  static String _normalizeExternalUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    const scheme = 'infocutter:';
    if (u.startsWith(scheme)) {
      u = u.substring(scheme.length);
      if (u.startsWith('//')) {
        u = u.substring(2);
      }
    }
    if (u.startsWith('//')) {
      u = 'https:$u';
    }
    if (!u.contains('://')) {
      u = 'https://$u';
    }
    return u;
  }

  /// part extension 에서 setState 를 쓰기 위한 공개 래퍼.
  void rebuild(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> getIntentData() async {
    // Android + iOS 모두 MethodChannel 로 런치/공유 URL 을 받는다.
    if (!Util.isAndroid() && !Util.isIOS()) {
      return;
    }
    try {
      // 테스트·미배선 채널에서 영구 대기를 막기 위해 짧게 타임아웃한다.
      final url = await platform
          .invokeMethod<String>('getIntentData')
          .timeout(const Duration(milliseconds: 200));
      if (url != null && url.isNotEmpty && mounted) {
        _openExternalUrl(url);
      }
    } on PlatformException {
      // 채널 미구현·무인텐트 — 무시
    } on MissingPluginException {
      // 테스트/데스크톱
    } on TimeoutException {
      // 핸들러 미응답
    }
  }

  Future<void> restore() async {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    await browserModel.restore();
    await windowModel.restoreInfo();
    await getIntentData();
    if (mounted) {
      setState(() {
        _bootstrapReady = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRestored) {
      _isRestored = true;
      unawaited(restore());
    }
    precacheImage(const AssetImage("assets/icon/icon.png"), context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapReady) {
      return _BootstrapSplash();
    }
    return _buildBrowser();
  }

  Widget _buildBrowser() {
    final browserModel = Provider.of<BrowserModel>(context);
    final windowModel = Provider.of<WindowModel>(context);
    // 리빌드마다 addListener 하지 않는다 — 동일 인스턴스면 no-op.
    _persistence.bind(browser: browserModel, window: windowModel);
    _persistence.bindCurrentTab(windowModel.getCurrentWebViewModel());

    var canShowTabScroller =
        browserModel.showTabScroller && windowModel.webViewModels.isNotEmpty;

    return IndexedStack(
      index: canShowTabScroller ? 1 : 0,
      children: [
        _buildWebViewTabs(),
        canShowTabScroller ? _buildWebViewTabsViewer() : Container()
      ],
    );
  }

  Widget _buildWebViewTabs() {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            _focusAddressBar,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _focusAddressBar,
      },
      child: Focus(
        autofocus: true,
        // ignore: deprecated_member_use
        child: WillPopScope(
            onWillPop: _onWillPopWebViewTabs,
            child: Listener(
              onPointerUp: _onWebViewTabsPointerUp,
              child: Scaffold(
                  appBar: BrowserAppBar(
                    webViewTabAppBarController: _webViewTabAppBarController,
                  ),
                  body: _buildWebViewTabsContent(),
                  bottomNavigationBar:
                      Util.isMobile() ? const BrowserBottomActionBar() : null),
            )),
      ),
    );
  }

  Future<bool> _onWillPopWebViewTabs() async {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final webViewModel = windowModel.getCurrentWebViewModel();
    final webViewController = webViewModel?.webViewController;

    if (webViewController != null) {
      if (await webViewController.canGoBack()) {
        webViewController.goBack();
        return false;
      }
    }

    if (webViewModel != null && webViewModel.tabIndex != null) {
      setState(() {
        windowModel.closeTab(webViewModel.tabIndex!);
      });
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
      return false;
    }

    return windowModel.webViewModels.isEmpty;
  }

  void _onWebViewTabsPointerUp(PointerUpEvent _) {
    if (Util.isIOS() || Util.isAndroid()) {
      FocusScopeNode currentFocus = FocusScope.of(context);
      if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
        currentFocus.focusedChild!.unfocus();
      }
    }
  }

  void _focusAddressBar() {
    _webViewTabAppBarController.focusAddressField();
  }

  Widget _buildWebViewTabsContent() {
    final windowModel = Provider.of<WindowModel>(context);

    if (windowModel.webViewModels.isEmpty) {
      return const EmptyTab();
    }

    for (final webViewModel in windowModel.webViewModels) {
      var isCurrentTab =
          webViewModel.tabIndex == windowModel.getCurrentTabIndex();

      if (isCurrentTab) {
        Future.delayed(const Duration(milliseconds: 100), () {
          webViewTabStateKey.currentState?.onShowTab();
        });
      } else {
        webViewTabStateKey.currentState?.onHideTab();
      }
    }

    var stackChildren = <Widget>[
      _buildCurrentWebViewTab(windowModel.getCurrentWebViewModel()),
      _createProgressIndicator()
    ];

    return Column(
      children: [
        Expanded(
            child: Stack(
          children: stackChildren,
        ))
      ],
    );
  }

  Widget _buildCurrentWebViewTab(WebViewModel? webViewModel) {
    if (webViewModel == null) {
      return Container();
    }
    return WebViewTab(
      key: ObjectKey(webViewModel),
      webViewModel: webViewModel,
    );
  }

  Widget _createProgressIndicator() {
    return Selector<WebViewModel, double>(
        selector: (context, webViewModel) => webViewModel.progress,
        builder: (context, progress, child) {
          if (progress >= 1.0) {
            return Container();
          }
          return PreferredSize(
              preferredSize: const Size(double.infinity, 4.0),
              child: SizedBox(
                  height: 4.0,
                  child: LinearProgressIndicator(
                    value: progress,
                  )));
        });
  }
}
