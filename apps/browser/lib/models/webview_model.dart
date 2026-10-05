import 'package:collection/collection.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/models/javascript_console_log.dart';
import 'package:infocutter_app/models/webview_model_codec.dart';

class WebViewModel extends ChangeNotifier {
  int? _tabIndex;
  WebUri? _url;
  String? _title;
  Favicon? _favicon;
  late double _progress;
  late bool _loaded;
  late bool _isDesktopMode;
  late bool _isIncognitoMode;
  late List<JavaScriptConsoleLog> _javaScriptConsoleLogs;
  late List<String> _javaScriptConsoleHistory;
  late List<LoadedResource> _loadedResources;
  late bool _isSecure;
  int? windowId;
  InAppWebViewSettings? settings;
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  FindInteractionController? findInteractionController;
  Uint8List? screenshot;
  bool needsToCompleteInitialLoad;
  final DateTime _createdTime;
  DateTime _lastOpenedTime;

  final keepAlive = InAppWebViewKeepAlive();

  /// One-shot request, set by the app bar / overflow menu, asking this tab to
  /// open the Infocutter sidebar in a given mode. The tab consumes it and
  /// resets to null.
  /// Scoped to its own notifier so the tab can listen without rebuilding on
  /// every url/progress change.
  final ValueNotifier<InfocutterPanelMode?> infocutterPanelRequest =
      ValueNotifier<InfocutterPanelMode?>(null);

  /// Which Infocutter panel is currently open on this tab (null = closed).
  /// Reflected by the coordinator so automation/observability can read the
  /// open state from a snapshot. UI-only; not persisted.
  InfocutterPanelMode? infocutterOpenPanel;

  /// The picker's multi-select staging session for this tab (the cards the user
  /// / AI has toggled but not yet applied). Owned by Dart so the human picker
  /// and external automation share one source of truth; exposed in snapshots.
  final ValueNotifier<List<SelectionCard>> infocutterSelectionSession =
      ValueNotifier<List<SelectionCard>>(const []);

  /// The most recent keyword captured by the keyword-capture feature on this
  /// tab (null = none yet / cleared). Updated by the JS handler; consumed by
  /// the keyword panel. UI-only; not persisted.
  final ValueNotifier<String?> infocutterCapturedKeyword =
      ValueNotifier<String?>(null);

  /// Whether the keyword-capture mode is currently active on this tab.
  /// Toggled by [InfocutterWebViewCoordinator.startKeywordCapture] /
  /// [stopKeywordCapture] so the sidebar toggle reflects state reactively.
  /// UI-only; not persisted.
  final ValueNotifier<bool> infocutterKeywordCaptureActive =
      ValueNotifier<bool>(false);

  WebViewModel(
      {int? tabIndex,
      WebUri? url,
      String? title,
      Favicon? favicon,
      double progress = 0.0,
      bool loaded = false,
      bool isDesktopMode = false,
      bool isIncognitoMode = false,
      List<JavaScriptConsoleLog>? javaScriptConsoleLogs,
      List<String>? javaScriptConsoleHistory,
      List<LoadedResource>? loadedResources,
      bool isSecure = false,
      DateTime? createdTime,
      DateTime? lastOpenedTime,
      this.windowId,
      this.settings,
      this.webViewController,
      this.pullToRefreshController,
      this.findInteractionController,
      this.needsToCompleteInitialLoad = true})
      : _createdTime = createdTime ?? DateTime.now(),
        _lastOpenedTime = lastOpenedTime ?? DateTime.now(),
        _tabIndex = tabIndex,
        _url = url,
        _favicon = favicon,
        _progress = progress,
        _loaded = loaded,
        _isDesktopMode = isDesktopMode,
        _isIncognitoMode = isIncognitoMode,
        _javaScriptConsoleLogs =
            javaScriptConsoleLogs ?? <JavaScriptConsoleLog>[],
        _javaScriptConsoleHistory = javaScriptConsoleHistory ?? <String>[],
        _loadedResources = loadedResources ?? <LoadedResource>[],
        _isSecure = isSecure {
    settings = settings ?? InAppWebViewSettings();
  }

  int? get tabIndex => _tabIndex;

  set tabIndex(int? value) {
    if (value != _tabIndex) {
      _tabIndex = value;
      notifyListeners();
    }
  }

  WebUri? get url => _url;

  set url(WebUri? value) {
    if (value != _url) {
      _url = value;
      notifyListeners();
    }
  }

  String? get title => _title;

  set title(String? value) {
    if (value != _title) {
      _title = value;
      notifyListeners();
    }
  }

  Favicon? get favicon => _favicon;

  set favicon(Favicon? value) {
    if (value != _favicon) {
      _favicon = value;
      notifyListeners();
    }
  }

  double get progress => _progress;

  set progress(double value) {
    if (value != _progress) {
      _progress = value;
      notifyListeners();
    }
  }

  bool get loaded => _loaded;

  set loaded(bool value) {
    if (value != _loaded) {
      _loaded = value;
      notifyListeners();
    }
  }

  bool get isDesktopMode => _isDesktopMode;

  set isDesktopMode(bool value) {
    if (value != _isDesktopMode) {
      _isDesktopMode = value;
      notifyListeners();
    }
  }

  bool get isIncognitoMode => _isIncognitoMode;

  set isIncognitoMode(bool value) {
    if (value != _isIncognitoMode) {
      _isIncognitoMode = value;
      notifyListeners();
    }
  }

  DateTime get createdTime => _createdTime;

  DateTime get lastOpenedTime => _lastOpenedTime;

  set lastOpenedTime(DateTime value) {
    if (value != _lastOpenedTime) {
      _lastOpenedTime = value;
      notifyListeners();
    }
  }

  UnmodifiableListView<JavaScriptConsoleLog> get javaScriptConsoleLogs =>
      UnmodifiableListView(_javaScriptConsoleLogs);

  void setJavaScriptConsoleLogs(List<JavaScriptConsoleLog> value) {
    if (!const IterableEquality().equals(value, _javaScriptConsoleLogs)) {
      _javaScriptConsoleLogs = value;
      notifyListeners();
    }
  }

  void addJavaScriptConsoleLog(JavaScriptConsoleLog value) {
    _javaScriptConsoleLogs.add(value);
    notifyListeners();
  }

  UnmodifiableListView<String> get javaScriptConsoleHistory =>
      UnmodifiableListView(_javaScriptConsoleHistory);

  void setJavaScriptConsoleHistory(List<String> value) {
    if (!const IterableEquality().equals(value, _javaScriptConsoleHistory)) {
      _javaScriptConsoleHistory = value;
      notifyListeners();
    }
  }

  void addJavaScriptConsoleHistory(String value) {
    _javaScriptConsoleHistory.add(value);
    notifyListeners();
  }

  UnmodifiableListView<LoadedResource> get loadedResources =>
      UnmodifiableListView(_loadedResources);

  void setLoadedResources(List<LoadedResource> value) {
    if (!const IterableEquality().equals(value, _loadedResources)) {
      _loadedResources = value;
      notifyListeners();
    }
  }

  void addLoadedResources(LoadedResource value) {
    _loadedResources.add(value);
    notifyListeners();
  }

  bool get isSecure => _isSecure;

  set isSecure(bool value) {
    if (value != _isSecure) {
      _isSecure = value;
      notifyListeners();
    }
  }

  void updateWithValue(WebViewModel webViewModel) {
    tabIndex = webViewModel.tabIndex;
    url = webViewModel.url;
    title = webViewModel.title;
    favicon = webViewModel.favicon;
    progress = webViewModel.progress;
    loaded = webViewModel.loaded;
    isDesktopMode = webViewModel.isDesktopMode;
    isIncognitoMode = webViewModel.isIncognitoMode;
    setJavaScriptConsoleLogs(webViewModel._javaScriptConsoleLogs.toList());
    setJavaScriptConsoleHistory(
        webViewModel._javaScriptConsoleHistory.toList());
    setLoadedResources(webViewModel._loadedResources.toList());
    isSecure = webViewModel.isSecure;
    settings = webViewModel.settings;
    webViewController = webViewModel.webViewController;
    pullToRefreshController = webViewModel.pullToRefreshController;
    findInteractionController = webViewModel.findInteractionController;
  }

  static WebViewModel? fromMap(Map<String, dynamic>? map) {
    return WebViewModelCodec.fromMap(map);
  }

  Map<String, dynamic> toMap() {
    return WebViewModelCodec.toMap(this);
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return toMap().toString();
  }

  @override
  void dispose() {
    infocutterPanelRequest.dispose();
    infocutterSelectionSession.dispose();
    infocutterCapturedKeyword.dispose();
    infocutterKeywordCaptureActive.dispose();
    super.dispose();
  }
}
