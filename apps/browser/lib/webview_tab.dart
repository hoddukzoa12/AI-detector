import 'dart:collection';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/infocutter/auth_origin_policy.dart';
import 'package:infocutter_app/infocutter/auth_unsupported_banner.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/infocutter_webview_coordinator.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/site_protection_bypass.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/javascript_console_log.dart';
import 'package:infocutter_app/load_error_panel.dart';
import 'package:infocutter_app/renderer_crash_panel.dart';
import 'package:infocutter_app/services/load_error_state.dart';
import 'package:infocutter_app/services/load_watchdog.dart';
import 'package:infocutter_app/services/renderer_crash_tracker.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/services/app_runtime.dart';
import 'package:infocutter_app/services/download_service.dart';
import 'package:infocutter_app/services/webview_file_chooser.dart';
import 'package:infocutter_app/services/webview_js_dialog_handler.dart';
import 'package:infocutter_app/services/webview_permission_gate.dart';
import 'package:infocutter_app/services/webview_settings_factory.dart';
import 'package:infocutter_app/util.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'long_press_alert_dialog.dart';
import 'models/browser_model.dart';
import 'models/window_model.dart';

part 'webview_tab_load_handlers.dart';
part 'webview_tab_request_handlers.dart';
part 'webview_tab_sidebar.dart';
part 'webview_tab_webview.dart';
part 'webview_tab_infocutter.dart';

final webViewTabStateKey = GlobalKey<_WebViewTabState>();

class _InfocutterRuntimeServices {
  const _InfocutterRuntimeServices({
    required this.infocutter,
    required this.textBlocks,
    required this.watch,
  });

  final InfocutterService infocutter;
  final TextBlockService textBlocks;
  final WatchService watch;
}

class WebViewTab extends StatefulWidget {
  const WebViewTab({required this.webViewModel, super.key});

  final WebViewModel webViewModel;

  @override
  State<WebViewTab> createState() => _WebViewTabState();
}

class _WebViewTabState extends State<WebViewTab> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  FindInteractionController? _findInteractionController;
  bool _isWindowClosed = false;
  final RendererCrashTracker _rendererCrashTracker = RendererCrashTracker();
  final LoadWatchdog _loadWatchdog = LoadWatchdog();
  String? _rendererCrashedUrl;
  LoadErrorState? _loadError;

  /// `setState` 는 State 안에서만 부를 수 있어서, part 로 나뉜 핸들러들이
  /// 렌더러 크래시 화면을 켜고 끌 때 쓰는 통로다.
  void _setRendererCrashedUrl(String? url) {
    if (!mounted || _rendererCrashedUrl == url) {
      return;
    }
    setState(() {
      _rendererCrashedUrl = url;
    });
  }

  void _setLoadError(LoadErrorState? error) {
    if (!mounted) {
      return;
    }
    if (_loadError?.url == error?.url &&
        _loadError?.reason == error?.reason) {
      return;
    }
    setState(() {
      _loadError = error;
    });
  }

  void _clearLoadError() {
    _loadWatchdog.cancel();
    if (_loadError == null) {
      return;
    }
    _setLoadError(null);
  }

  void _armLoadWatchdog({String? url}) {
    _loadWatchdog.arm(() {
      if (!mounted || widget.webViewModel.loaded) {
        return;
      }
      _setLoadError(
        LoadErrorState(
          url: url ?? widget.webViewModel.url?.toString(),
          reason: AppLocalizations.of(context).loadErrorTimeout,
        ),
      );
    });
  }

  final FocusNode _focusNode = FocusNode();
  final WebViewSettingsFactory _settingsFactory =
      const WebViewSettingsFactory();

  final TextEditingController _httpAuthUsernameController =
      TextEditingController();
  final TextEditingController _httpAuthPasswordController =
      TextEditingController();
  late final InfocutterWebViewCoordinator _infocutterCoordinator;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _infocutterCoordinator = InfocutterWebViewCoordinator(
      context: () => context,
      controller: () => _webViewController,
      isMounted: () => mounted,
      onEvidenceCaptured: _showInfocutterEvidenceCaptured,
      onRuleSaved: _showInfocutterRuleSaved,
      onSidebarChanged: () {
        if (mounted) setState(() {});
      },
      webViewModel: widget.webViewModel,
    );
    widget.webViewModel.infocutterPanelRequest
        .addListener(_onInfocutterPanelRequested);

    if (Util.isIOS() || Util.isAndroid()) {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: Colors.blue),
        onRefresh: () async {
          if ([TargetPlatform.iOS].contains(defaultTargetPlatform)) {
            _webViewController?.loadUrl(
                urlRequest:
                    URLRequest(url: await _webViewController?.getUrl()));
          } else {
            _webViewController?.reload();
          }
        },
      );
    }

    if (Util.isIOS() || Util.isAndroid() || Util.isMacOS()) {
      _findInteractionController = FindInteractionController();
    }
  }

  @override
  void dispose() {
    widget.webViewModel.infocutterPanelRequest
        .removeListener(_onInfocutterPanelRequested);
    _loadWatchdog.cancel();
    _webViewController = null;
    widget.webViewModel.webViewController = null;
    widget.webViewModel.pullToRefreshController = null;
    widget.webViewModel.findInteractionController = null;

    _httpAuthUsernameController.dispose();
    _httpAuthPasswordController.dispose();

    _focusNode.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_webViewController != null && (Util.isAndroid() || Util.isWindows())) {
      if (state == AppLifecycleState.paused) {
        pauseAll();
      } else {
        resumeAll();
      }
    }
  }

  void pauseAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
    pauseTimers();
  }

  void resumeAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
    resumeTimers();
  }

  void pause() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
  }

  void resume() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
  }

  void pauseTimers() {
    if (!Util.isWindows()) {
      _webViewController?.pauseTimers();
    }
  }

  void resumeTimers() {
    if (!Util.isWindows()) {
      _webViewController?.resumeTimers();
    }
  }

  void _showInfocutterRuleSaved(String selector, String host) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.hiddenSelectorOnHost(selector, host)),
        action: SnackBarAction(
          label: l10n.infocutterUndo,
          onPressed: () => unawaited(_infocutterCoordinator.undoLastApply()),
        ),
      ),
    );
  }

  void _showInfocutterEvidenceCaptured(int sequence) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.infocutterEvidenceCaptured(sequence))),
    );
  }

  void _onInfocutterPanelRequested() {
    final mode = widget.webViewModel.infocutterPanelRequest.value;
    if (mode == null) return;
    widget.webViewModel.infocutterPanelRequest.value = null;
    // Block mode starts the on-page element picker directly (the approved
    // "tap scissors -> pick" flow); every other mode opens its panel.
    if (mode == InfocutterPanelMode.block) {
      unawaited(_infocutterCoordinator.startBlockPicker());
    } else {
      unawaited(_infocutterCoordinator.openPanel(mode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final infocutterSidebar = _infocutterCoordinator.sidebar;
    final showAuthNotice = isAuthOrigin(widget.webViewModel.url);
    return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR): () {
            _webViewController?.reload();
          }
        },
        child: Focus(
            autofocus: true,
            focusNode: _focusNode,
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned.fill(child: _buildWebView()),
                  if (showAuthNotice)
                    AuthUnsupportedBanner(
                      onOpenExternally: () =>
                          unawaited(_openCurrentUrlExternally()),
                    ),
                  if (infocutterSidebar != null)
                    _buildInfocutterSidebar(
                      infocutterSidebar.mode,
                      infocutterSidebar.url,
                    ),
                  if (_rendererCrashedUrl != null)
                    RendererCrashPanel(
                      url: _rendererCrashedUrl,
                      onRetry: _retryAfterRendererCrash,
                    ),
                  if (_loadError != null && _rendererCrashedUrl == null)
                    LoadErrorPanel(
                      url: _loadError!.url,
                      reason: _loadError!.reason,
                      onRetry: _retryAfterLoadError,
                    ),
                ],
              ),
            )));
  }

  void _retryAfterLoadError() {
    final urlString = _loadError?.url ?? widget.webViewModel.url?.toString();
    _clearLoadError();
    final parsed =
        urlString == null || urlString.isEmpty ? null : WebUri(urlString);
    if (parsed == null) {
      unawaited(_webViewController?.reload() ?? Future<void>.value());
      return;
    }
    _armLoadWatchdog(url: urlString);
    unawaited(
      _webViewController?.loadUrl(urlRequest: URLRequest(url: parsed)) ??
          Future<void>.value(),
    );
  }

  void onShowTab() async {
    resume();
    if (widget.webViewModel.needsToCompleteInitialLoad) {
      widget.webViewModel.needsToCompleteInitialLoad = false;
      await widget.webViewModel.webViewController
          ?.loadUrl(urlRequest: URLRequest(url: widget.webViewModel.url));
    }
  }

  void onHideTab() async {
    pause();
  }
}
