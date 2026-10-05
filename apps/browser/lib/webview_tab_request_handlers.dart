part of 'webview_tab.dart';

extension _WebViewTabRequestHandlers on _WebViewTabState {
  bool isCurrentTab(WebViewModel currentWebViewModel) {
    return currentWebViewModel.tabIndex == widget.webViewModel.tabIndex;
  }

  Future<void> _handleLongPressHitTestResult({
    required InAppWebViewController controller,
    required InAppWebViewHitTestResult hitTestResult,
  }) async {
    if (!LongPressAlertDialog.hitTestResultSupported
        .contains(hitTestResult.type)) {
      return;
    }

    final requestFocusNodeHrefResult = await controller.requestFocusNodeHref();
    if (requestFocusNodeHrefResult == null || !mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return LongPressAlertDialog(
          webViewModel: widget.webViewModel,
          hitTestResult: hitTestResult,
          requestFocusNodeHrefResult: requestFocusNodeHrefResult,
        );
      },
    );
  }

  void _handleConsoleMessage({
    required ConsoleMessage consoleMessage,
    required WebViewModel currentWebViewModel,
  }) {
    widget.webViewModel.addJavaScriptConsoleLog(
      JavaScriptConsoleLog(
        message: consoleMessage.message,
        level: _consoleLogLevel(consoleMessage.messageLevel),
      ),
    );

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
  }

  void _handleLoadResource({
    required LoadedResource resource,
    required WebViewModel currentWebViewModel,
  }) {
    widget.webViewModel.addLoadedResources(resource);

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
  }

  Future<NavigationActionPolicy> _handleShouldOverrideUrlLoading(
    NavigationAction navigationAction,
  ) async {
    final url = navigationAction.request.url;

    // 인증 origin 으로의 이동은 절대 가로채지 않는다.
    // #20 사이트 보호 끄기 중이면 네트워크 필터도 적용하지 않는다.
    if (url != null &&
        !isAuthOrigin(url) &&
        !SiteProtectionBypass.instance.isBypassed(widget.webViewModel.url) &&
        !SiteProtectionBypass.instance.isBypassed(url)) {
      final networkFilter = Provider.of<NetworkFilterService>(
        context,
        listen: false,
      );
      if (networkFilter.shouldBlock(url)) {
        return NavigationActionPolicy.CANCEL;
      }
    }

    if (url != null &&
        !["http", "https", "file", "chrome", "data", "javascript", "about"]
            .contains(url.scheme)) {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return NavigationActionPolicy.CANCEL;
      }
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<WebResourceResponse?> _handleShouldInterceptRequest(
    WebResourceRequest request,
  ) async {
    final url = request.url;
    // 인증 페이지 자체이거나, 그 페이지가 부르는 요청이면 가로채지 않는다.
    if (isAuthOrigin(url) || isAuthOrigin(widget.webViewModel.url)) {
      return null;
    }
    if (SiteProtectionBypass.instance.isBypassed(widget.webViewModel.url) ||
        SiteProtectionBypass.instance.isBypassed(url)) {
      return null;
    }
    final networkFilter = Provider.of<NetworkFilterService>(
      context,
      listen: false,
    );
    if (!networkFilter.shouldBlock(url)) {
      return null;
    }

    return WebResourceResponse(
      contentType: 'text/plain',
      data: Uint8List(0),
      headers: const <String, String>{},
      reasonPhrase: 'OK',
      statusCode: 200,
    );
  }

  Future<void> _handleDownloadStartRequest(
    DownloadStartRequest request,
  ) async {
    final downloadService = Provider.of<DownloadService>(
      context,
      listen: false,
    );

    await downloadService.enqueue(
      DownloadTaskRequest(
        url: request.url.toString(),
        fileName: DownloadTaskRequest.fileNameFromPath(request.url.path),
        destination: DownloadDestination.temporaryDirectory,
      ),
    );
  }

  ServerTrustAuthResponse _handleServerTrustAuthRequest({
    required URLAuthenticationChallenge challenge,
    required WebViewModel currentWebViewModel,
  }) {
    final sslError = challenge.protectionSpace.sslError;
    if (sslError != null && (sslError.code != null)) {
      if ((Util.isIOS() || Util.isMacOS()) &&
          sslError.code == SslErrorType.UNSPECIFIED) {
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      }
      widget.webViewModel.isSecure = false;
      if (isCurrentTab(currentWebViewModel)) {
        currentWebViewModel.updateWithValue(widget.webViewModel);
      }
      return ServerTrustAuthResponse();
    }
    return ServerTrustAuthResponse(
      action: ServerTrustAuthResponseAction.PROCEED,
    );
  }

  Future<void> _handleReceivedError({
    required WebResourceRequest request,
    required WebResourceError error,
    required WebViewModel currentWebViewModel,
  }) async {
    final isForMainFrame = request.isForMainFrame ?? false;
    if (!isForMainFrame) {
      return;
    }

    _pullToRefreshController?.endRefreshing();
    _loadWatchdog.cancel();

    if ((Util.isIOS() || Util.isMacOS() || Util.isWindows()) &&
        error.type == WebResourceErrorType.CANCELLED) {
      return;
    }
    if (Util.isWindows() &&
        error.type == WebResourceErrorType.CONNECTION_ABORTED) {
      return;
    }

    final errorUrl = request.url;
    final description = error.description.trim();

    // HTML loadData 는 렌더러/네트워크 상태에 따라 백지로 남을 수 있다.
    // Flutter 오버레이가 정본 오류 UI 다 (#25).
    _setLoadError(
      LoadErrorState(
        url: errorUrl.toString(),
        reason: description.isEmpty
            ? AppLocalizations.of(context).loadErrorBodyGeneric
            : description,
      ),
    );

    widget.webViewModel.url = errorUrl;
    widget.webViewModel.isSecure = false;
    widget.webViewModel.loaded = false;

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
  }

  /// 렌더러 프로세스가 사라졌다 (iOS/macOS `onWebContentProcessDidTerminate`,
  /// Android `onRenderProcessGone`). 화면은 빈 채로 남고 `onReceivedError` 는
  /// 오지 않으므로, 여기서 잡지 않으면 원인 없는 흰 화면이 된다.
  void _handleRendererGone({required WebViewModel currentWebViewModel}) {
    final action = _rendererCrashTracker.recordCrash(DateTime.now());

    if (action == RendererCrashAction.reload) {
      unawaited(_webViewController?.reload() ?? Future<void>.value());
      return;
    }

    _setRendererCrashedUrl(widget.webViewModel.url?.toString());
    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
  }

  void _retryAfterRendererCrash() {
    final url = widget.webViewModel.url;
    _setRendererCrashedUrl(null);
    if (url == null) {
      unawaited(_webViewController?.reload() ?? Future<void>.value());
      return;
    }
    unawaited(
      _webViewController?.loadUrl(urlRequest: URLRequest(url: url)) ??
          Future<void>.value(),
    );
  }

  void _handleCreateWindow({
    required CreateWindowAction createWindowRequest,
    required WindowModel windowModel,
  }) {
    // 자식 창(window.open / OAuth 팝업)은 빈 settings 로 만들면 기본 WebView UA 가
    // 남는다 (#22). 부모 settings 를 copy 하고, 빌드 시 factory 가 UA 를 다시 박는다.
    final parentSettings = widget.webViewModel.settings;
    final childSettings =
        parentSettings?.copy() ?? InAppWebViewSettings();

    windowModel.addTab(
      WebViewModel(
        url: WebUri("about:blank"),
        windowId: createWindowRequest.windowId,
        settings: childSettings,
      ),
    );
  }

  void _handleCloseWindow(WindowModel windowModel) {
    if (_isWindowClosed) {
      return;
    }
    _isWindowClosed = true;
    if (widget.webViewModel.tabIndex != null) {
      windowModel.closeTab(widget.webViewModel.tabIndex!);
    }
  }

  Future<PermissionResponse> _handlePermissionRequest(
    PermissionRequest request,
  ) {
    final gate = WebViewPermissionGate(
      requestOsPermission: requestOsPermission,
      requiresOsGrant: Util.isAndroid(),
    );
    return gate.decide(request);
  }

  Future<JsAlertResponse?> _handleJsAlert(JsAlertRequest request) {
    return const WebViewJsDialogHandler().onAlert(context, request);
  }

  Future<JsConfirmResponse?> _handleJsConfirm(JsConfirmRequest request) {
    return const WebViewJsDialogHandler().onConfirm(context, request);
  }

  Future<JsPromptResponse?> _handleJsPrompt(JsPromptRequest request) {
    return const WebViewJsDialogHandler().onPrompt(context, request);
  }

  Future<ShowFileChooserResponse?> _handleShowFileChooser(
    ShowFileChooserRequest request,
  ) {
    return const WebViewFileChooser().pick(request);
  }

  Future<HttpAuthResponse> _handleHttpAuthRequest(
    URLAuthenticationChallenge challenge,
  ) async {
    final action = await _createHttpAuthDialog(challenge);
    return HttpAuthResponse(
      username: _httpAuthUsernameController.text.trim(),
      password: _httpAuthPasswordController.text,
      action: action,
      permanentPersistence: true,
    );
  }

  JavaScriptConsoleLogLevel _consoleLogLevel(ConsoleMessageLevel? level) {
    return switch (level) {
      ConsoleMessageLevel.ERROR => JavaScriptConsoleLogLevel.error,
      ConsoleMessageLevel.TIP => JavaScriptConsoleLogLevel.tip,
      ConsoleMessageLevel.WARNING => JavaScriptConsoleLogLevel.warning,
      _ => JavaScriptConsoleLogLevel.log,
    };
  }

  Future<HttpAuthResponseAction> _createHttpAuthDialog(
    URLAuthenticationChallenge challenge,
  ) async {
    HttpAuthResponseAction action = HttpAuthResponseAction.CANCEL;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.login),
          content: _buildHttpAuthDialogContent(challenge, l10n),
          actions: _buildHttpAuthDialogActions(
            context,
            l10n,
            onSelected: (selected) {
              action = selected;
            },
          ),
        );
      },
    );

    return action;
  }

  Widget _buildHttpAuthDialogContent(
    URLAuthenticationChallenge challenge,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(challenge.protectionSpace.host),
        TextField(
          decoration: InputDecoration(labelText: l10n.username),
          controller: _httpAuthUsernameController,
        ),
        TextField(
          decoration: InputDecoration(labelText: l10n.password),
          controller: _httpAuthPasswordController,
          obscureText: true,
        ),
      ],
    );
  }

  List<Widget> _buildHttpAuthDialogActions(
    BuildContext context,
    AppLocalizations l10n, {
    required ValueChanged<HttpAuthResponseAction> onSelected,
  }) =>
      <Widget>[
        ElevatedButton(
          child: Text(l10n.cancel),
          onPressed: () {
            onSelected(HttpAuthResponseAction.CANCEL);
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: Text(l10n.ok),
          onPressed: () {
            onSelected(HttpAuthResponseAction.PROCEED);
            Navigator.of(context).pop();
          },
        ),
      ];
}
