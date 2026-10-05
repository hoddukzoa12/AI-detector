part of 'webview_tab.dart';

class _WebViewTabCallbacks {
  const _WebViewTabCallbacks({
    required _WebViewTabState state,
    required InAppWebViewSettings initialSettings,
    required InfocutterService infocutter,
    required _InfocutterRuntimeServices infocutterRuntime,
    required WebViewModel currentWebViewModel,
    required WindowModel windowModel,
  })  : _state = state,
        _initialSettings = initialSettings,
        _infocutter = infocutter,
        _infocutterRuntime = infocutterRuntime,
        _currentWebViewModel = currentWebViewModel,
        _windowModel = windowModel;

  final _WebViewTabState _state;
  final InAppWebViewSettings _initialSettings;
  final InfocutterService _infocutter;
  final _InfocutterRuntimeServices _infocutterRuntime;
  final WebViewModel _currentWebViewModel;
  final WindowModel _windowModel;

  Future<void> onWebViewCreated(InAppWebViewController controller) {
    return _state._handleWebViewCreated(
      controller: controller,
      initialSettings: _initialSettings,
      infocutter: _infocutter,
      currentWebViewModel: _currentWebViewModel,
    );
  }

  Future<void> onLoadStart(InAppWebViewController controller, WebUri? url) {
    return _state._handleLoadStart(
      controller: controller,
      url: url,
      infocutter: _infocutter,
      currentWebViewModel: _currentWebViewModel,
      windowModel: _windowModel,
    );
  }

  Future<void> onLoadStop(InAppWebViewController controller, WebUri? url) {
    return _state._handleLoadStop(
      controller: controller,
      url: url,
      runtimeServices: _infocutterRuntime,
      currentWebViewModel: _currentWebViewModel,
      windowModel: _windowModel,
    );
  }

  void onProgressChanged(InAppWebViewController controller, int progress) {
    _state._handleProgressChanged(
      progress: progress,
      currentWebViewModel: _currentWebViewModel,
    );
  }

  Future<void> onUpdateVisitedHistory(
    InAppWebViewController controller,
    WebUri? url,
    bool? androidIsReload,
  ) {
    return _state._handleVisitedHistoryUpdated(
      controller: controller,
      url: url,
      currentWebViewModel: _currentWebViewModel,
      windowModel: _windowModel,
    );
  }

  Future<void> onLongPressHitTestResult(
    InAppWebViewController controller,
    InAppWebViewHitTestResult hitTestResult,
  ) {
    return _state._handleLongPressHitTestResult(
      controller: controller,
      hitTestResult: hitTestResult,
    );
  }

  void onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  ) {
    _state._handleConsoleMessage(
      consoleMessage: consoleMessage,
      currentWebViewModel: _currentWebViewModel,
    );
  }

  void onLoadResource(
    InAppWebViewController controller,
    LoadedResource resource,
  ) {
    _state._handleLoadResource(
      resource: resource,
      currentWebViewModel: _currentWebViewModel,
    );
  }

  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) {
    return _state._handleShouldOverrideUrlLoading(navigationAction);
  }

  Future<WebResourceResponse?> shouldInterceptRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) {
    return _state._handleShouldInterceptRequest(request);
  }

  Future<DownloadStartResponse?> onDownloadStarting(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    await _state._handleDownloadStartRequest(request);
    return null;
  }

  Future<ServerTrustAuthResponse> onReceivedServerTrustAuthRequest(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) async {
    return _state._handleServerTrustAuthRequest(
      challenge: challenge,
      currentWebViewModel: _currentWebViewModel,
    );
  }

  Future<void> onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    return _state._handleReceivedError(
      request: request,
      error: error,
      currentWebViewModel: _currentWebViewModel,
    );
  }

  Future<void> onTitleChanged(
    InAppWebViewController controller,
    String? title,
  ) {
    return _state._handleTitleChanged(
      title: title,
      currentWebViewModel: _currentWebViewModel,
      windowModel: _windowModel,
    );
  }

  Future<bool> onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction createWindowRequest,
  ) async {
    _state._handleCreateWindow(
      createWindowRequest: createWindowRequest,
      windowModel: _windowModel,
    );
    return true;
  }

  void onCloseWindow(InAppWebViewController controller) {
    _state._handleCloseWindow(_windowModel);
  }

  Future<PermissionResponse> onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest permissionRequest,
  ) async {
    return _state._handlePermissionRequest(permissionRequest);
  }

  Future<HttpAuthResponse> onReceivedHttpAuthRequest(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) {
    return _state._handleHttpAuthRequest(challenge);
  }

  void onWebContentProcessDidTerminate(InAppWebViewController controller) {
    _state._handleRendererGone(currentWebViewModel: _currentWebViewModel);
  }

  void onRenderProcessGone(
    InAppWebViewController controller,
    RenderProcessGoneDetail detail,
  ) {
    _state._handleRendererGone(currentWebViewModel: _currentWebViewModel);
  }

  Future<JsAlertResponse?> onJsAlert(
    InAppWebViewController controller,
    JsAlertRequest jsAlertRequest,
  ) {
    return _state._handleJsAlert(jsAlertRequest);
  }

  Future<JsConfirmResponse?> onJsConfirm(
    InAppWebViewController controller,
    JsConfirmRequest jsConfirmRequest,
  ) {
    return _state._handleJsConfirm(jsConfirmRequest);
  }

  Future<JsPromptResponse?> onJsPrompt(
    InAppWebViewController controller,
    JsPromptRequest jsPromptRequest,
  ) {
    return _state._handleJsPrompt(jsPromptRequest);
  }

  Future<ShowFileChooserResponse?> onShowFileChooser(
    InAppWebViewController controller,
    ShowFileChooserRequest fileChooserRequest,
  ) {
    return _state._handleShowFileChooser(fileChooserRequest);
  }
}

extension _WebViewTabWebView on _WebViewTabState {
  InAppWebView _buildWebView() {
    var browserModel = Provider.of<BrowserModel>(context);
    var windowModel = Provider.of<WindowModel>(context);
    var settings = browserModel.getSettings();
    var currentWebViewModel = Provider.of<WebViewModel>(context);
    final appRuntime = Provider.of<AppRuntime>(context, listen: false);

    final initialSettings = _initialWebViewSettings(settings, appRuntime);
    final infocutter = Provider.of<InfocutterService>(context);
    final networkFilters = Provider.of<NetworkFilterService>(context);
    applyInfocutterSettings(
      initialSettings,
      infocutter,
      widget.webViewModel.url,
      networkFilters: networkFilters,
    );
    final callbacks = _WebViewTabCallbacks(
      state: this,
      initialSettings: initialSettings,
      infocutter: infocutter,
      infocutterRuntime: _infocutterRuntimeServices(),
      currentWebViewModel: currentWebViewModel,
      windowModel: windowModel,
    );

    return _buildConfiguredWebView(appRuntime, initialSettings, callbacks);
  }

  InAppWebViewSettings _initialWebViewSettings(
    BrowserSettings settings,
    AppRuntime appRuntime,
  ) {
    _settingsFactory.configureWebContentsDebugging(settings);
    return _settingsFactory.configureInitialTabSettings(
      baseSettings: widget.webViewModel.settings!,
      browserSettings: settings,
      webArchiveDirectory: appRuntime.webArchiveDirectory,
    );
  }

  _InfocutterRuntimeServices _infocutterRuntimeServices() =>
      _InfocutterRuntimeServices(
        infocutter: Provider.of<InfocutterService>(context),
        textBlocks: Provider.of<TextBlockService>(context),
        watch: Provider.of<WatchService>(context),
      );

  InAppWebView _buildConfiguredWebView(
    AppRuntime appRuntime,
    InAppWebViewSettings initialSettings,
    _WebViewTabCallbacks callbacks,
  ) {
    return InAppWebView(
      keepAlive: widget.webViewModel.keepAlive,
      webViewEnvironment: appRuntime.webViewEnvironment,
      initialUrlRequest: URLRequest(url: widget.webViewModel.url),
      initialSettings: initialSettings,
      initialUserScripts:
          UnmodifiableListView<UserScript>(buildInfocutterUserScripts()),
      windowId: widget.webViewModel.windowId,
      pullToRefreshController: _pullToRefreshController,
      findInteractionController: _findInteractionController,
      onWebViewCreated: callbacks.onWebViewCreated,
      onLoadStart: callbacks.onLoadStart,
      onLoadStop: callbacks.onLoadStop,
      onProgressChanged: callbacks.onProgressChanged,
      onUpdateVisitedHistory: callbacks.onUpdateVisitedHistory,
      onLongPressHitTestResult: callbacks.onLongPressHitTestResult,
      onConsoleMessage: callbacks.onConsoleMessage,
      onLoadResource: callbacks.onLoadResource,
      shouldOverrideUrlLoading: callbacks.shouldOverrideUrlLoading,
      shouldInterceptRequest: callbacks.shouldInterceptRequest,
      onDownloadStarting: callbacks.onDownloadStarting,
      onReceivedServerTrustAuthRequest:
          callbacks.onReceivedServerTrustAuthRequest,
      onReceivedError: callbacks.onReceivedError,
      onTitleChanged: callbacks.onTitleChanged,
      onCreateWindow: callbacks.onCreateWindow,
      onCloseWindow: callbacks.onCloseWindow,
      onPermissionRequest: callbacks.onPermissionRequest,
      onReceivedHttpAuthRequest: callbacks.onReceivedHttpAuthRequest,
      onWebContentProcessDidTerminate:
          callbacks.onWebContentProcessDidTerminate,
      onRenderProcessGone: callbacks.onRenderProcessGone,
      onJsAlert: callbacks.onJsAlert,
      onJsConfirm: callbacks.onJsConfirm,
      onJsPrompt: callbacks.onJsPrompt,
      onShowFileChooser: callbacks.onShowFileChooser,
    );
  }
}
