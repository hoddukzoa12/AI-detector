part of 'webview_tab.dart';

extension _WebViewTabInfocutter on _WebViewTabState {
  Future<void> startInfocutterBlockPicker() async {
    await _infocutterCoordinator.startBlockPicker();
  }

  Future<void> _handleInfocutterPickerResult(
    InfocutterService infocutter,
    PickerResult result,
  ) async {
    await _infocutterCoordinator.handlePickerResult(infocutter, result);
  }

  void _handleInfocutterWatchDetection(WatchDetection detection) {
    _infocutterCoordinator.handleWatchDetection(detection);
  }

  void _removeInfocutterSessionCard(String id) {
    unawaited(_infocutterCoordinator.removeSessionCard(id));
  }

  void _refineInfocutterSessionCard(String id, String selector) {
    unawaited(_infocutterCoordinator.refineSessionCard(id, selector));
  }

  void _renameInfocutterSessionCard(String id, String name) {
    _infocutterCoordinator.renameSessionCard(id, name);
  }

  void _setInfocutterSessionCardDepth(String id, int index) {
    _infocutterCoordinator.setSessionCardDepth(id, index);
  }

  void _applyInfocutterSession() {
    unawaited(_infocutterCoordinator.applySession());
  }

  void _cancelInfocutterSession() {
    unawaited(_infocutterCoordinator.cancelSession());
  }

  Future<void> _pauseInfocutterPicker() async {
    await _infocutterCoordinator.pausePicker();
  }

  Future<void> _resumeInfocutterPicker() async {
    await _infocutterCoordinator.resumePicker();
  }

  Future<void> _applyInfocutterSettingsForUrl(
    InAppWebViewController controller,
    InfocutterService infocutter,
    Uri? url,
  ) async {
    await _infocutterCoordinator.applySettingsForUrl(
      controller,
      infocutter,
      url,
    );
  }

  Future<void> _applyInfocutterRuntimeForUrl(
    InAppWebViewController controller,
    InfocutterService infocutter,
    Uri? url,
  ) async {
    await _infocutterCoordinator.applyRuntimeForUrl(
      controller,
      infocutter,
      url,
    );
  }

  Future<void> _applyInfocutterWatchRuntime(
    InAppWebViewController controller,
    WatchService watch,
  ) async {
    await _infocutterCoordinator.applyWatchRuntime(controller, watch);
  }

  Future<void> _applyInfocutterTextBlockRuntimeForUrl(
    InAppWebViewController controller,
    TextBlockService textBlocks,
    Uri? url,
  ) async {
    await _infocutterCoordinator.applyTextBlockRuntimeForUrl(
      controller,
      textBlocks,
      url,
    );
  }

  Future<void> _refreshInfocutterForCurrentUrl() async {
    await _infocutterCoordinator.refreshForCurrentUrl();
  }

  Future<void> _refreshInfocutterNetworkFiltersForCurrentUrl() async {
    await _infocutterCoordinator.refreshForCurrentUrl(reload: true);
  }

  Future<void> _captureInfocutterEvidence({WatchDetection? detection}) async {
    await _infocutterCoordinator.captureEvidence(detection: detection);
  }

  Future<void> _openCurrentUrlExternally() async {
    final url = widget.webViewModel.url;
    if (url == null) return;
    final target = Uri.parse(url.toString());
    if (await canLaunchUrl(target)) {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    }
  }
}
