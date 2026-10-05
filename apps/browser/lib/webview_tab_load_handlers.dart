part of 'webview_tab.dart';

extension _WebViewTabLoadHandlers on _WebViewTabState {
  Future<void> _handleWebViewCreated({
    required InAppWebViewController controller,
    required InAppWebViewSettings initialSettings,
    required InfocutterService infocutter,
    required WebViewModel currentWebViewModel,
  }) async {
    initialSettings.transparentBackground = false;
    await controller.setSettings(settings: initialSettings);

    _webViewController = controller;
    widget.webViewModel.webViewController = controller;
    widget.webViewModel.pullToRefreshController = _pullToRefreshController;
    widget.webViewModel.findInteractionController = _findInteractionController;

    attachInfocutterHandlers(
      controller,
      infocutter,
      onPickerResult: (result) {
        _handleInfocutterPickerResult(infocutter, result);
      },
      onWatchDetection: _handleInfocutterWatchDetection,
      onKeywordCapture: (text) =>
          _handleInfocutterKeywordCapture(infocutter, text),
    );

    if (Util.isAndroid()) {
      controller.startSafeBrowsing();
    }

    widget.webViewModel.settings = await controller.getSettings();

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
  }

  Future<void> _handleLoadStart({
    required InAppWebViewController controller,
    required WebUri? url,
    required InfocutterService infocutter,
    required WebViewModel currentWebViewModel,
    required WindowModel windowModel,
  }) async {
    widget.webViewModel.isSecure = Util.urlIsSecure(url!);
    unawaited(_infocutterCoordinator.handleHostChange(url));
    widget.webViewModel.url = url;
    widget.webViewModel.loaded = false;
    widget.webViewModel.setLoadedResources([]);
    widget.webViewModel.setJavaScriptConsoleLogs([]);
    _clearLoadError();
    _armLoadWatchdog(url: url.toString());
    await _applyInfocutterSettingsForUrl(controller, infocutter, url);

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    } else if (widget.webViewModel.needsToCompleteInitialLoad) {
      controller.stopLoading();
    }

    windowModel.notifyCurrentTabUpdated();
  }

  Future<void> _handleLoadStop({
    required InAppWebViewController controller,
    required WebUri? url,
    required _InfocutterRuntimeServices runtimeServices,
    required WebViewModel currentWebViewModel,
    required WindowModel windowModel,
  }) async {
    _pullToRefreshController?.endRefreshing();

    // 여기까지 왔으면 렌더러가 살아 있다 — 다음 죽음은 다시 첫 죽음으로 센다.
    _rendererCrashTracker.recordSuccessfulLoad();
    _setRendererCrashedUrl(null);
    _clearLoadError();

    widget.webViewModel.url = url;
    widget.webViewModel.favicon = null;
    widget.webViewModel.loaded = true;
    await _applyInfocutterRuntimeForUrl(
      controller,
      runtimeServices.infocutter,
      url,
    );
    await _applyInfocutterTextBlockRuntimeForUrl(
      controller,
      runtimeServices.textBlocks,
      url,
    );
    await _applyInfocutterWatchRuntime(controller, runtimeServices.watch);

    final sslCertificateFuture = controller.getCertificate();
    final titleFuture = controller.getTitle();
    final faviconsFuture = controller.getFavicons();

    final sslCertificate = await sslCertificateFuture;
    if (sslCertificate == null && !Util.isLocalizedContent(url!)) {
      widget.webViewModel.isSecure = false;
    }

    widget.webViewModel.title = await titleFuture;
    _setBestFavicon(await _loadFavicons(faviconsFuture));

    if (isCurrentTab(currentWebViewModel)) {
      widget.webViewModel.needsToCompleteInitialLoad = false;
      currentWebViewModel.updateWithValue(widget.webViewModel);
      widget.webViewModel.screenshot = await _capturePreview(controller);
    }

    windowModel.notifyCurrentTabUpdated();
  }

  Future<List<Favicon>?> _loadFavicons(
    Future<List<Favicon>> faviconsFuture,
  ) async {
    try {
      return await faviconsFuture;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  void _setBestFavicon(List<Favicon>? favicons) {
    if (favicons == null || favicons.isEmpty) {
      return;
    }

    for (final fav in favicons) {
      final current = widget.webViewModel.favicon;
      if (current == null) {
        widget.webViewModel.favicon = fav;
      } else if ((current.width == null &&
              !current.url.toString().endsWith("favicon.ico")) ||
          (fav.width != null &&
              current.width != null &&
              fav.width! > current.width!)) {
        widget.webViewModel.favicon = fav;
      }
    }
  }

  Future<Uint8List?> _capturePreview(InAppWebViewController controller) {
    return controller
        .takeScreenshot(
          screenshotConfiguration: ScreenshotConfiguration(
            compressFormat: CompressFormat.JPEG,
            quality: 20,
          ),
        )
        .timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => null,
        );
  }

  void _handleProgressChanged({
    required int progress,
    required WebViewModel currentWebViewModel,
  }) {
    if (progress == 100) {
      _pullToRefreshController?.endRefreshing();
    }

    widget.webViewModel.progress = progress / 100;

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
  }

  Future<void> _handleVisitedHistoryUpdated({
    required InAppWebViewController controller,
    required WebUri? url,
    required WebViewModel currentWebViewModel,
    required WindowModel windowModel,
  }) async {
    widget.webViewModel.url = url;
    widget.webViewModel.title = await controller.getTitle();

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
    windowModel.notifyCurrentTabUpdated();
  }

  Future<void> _handleTitleChanged({
    required String? title,
    required WebViewModel currentWebViewModel,
    required WindowModel windowModel,
  }) async {
    widget.webViewModel.title = title;

    if (isCurrentTab(currentWebViewModel)) {
      currentWebViewModel.updateWithValue(widget.webViewModel);
    }
    windowModel.notifyCurrentTabUpdated();
  }

  Future<void> _handleInfocutterKeywordCapture(
    InfocutterService infocutter,
    String text,
  ) async {
    await _infocutterCoordinator.handleKeywordCapture(text);
  }
}
