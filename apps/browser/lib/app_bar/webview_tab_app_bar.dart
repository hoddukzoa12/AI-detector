// import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:infocutter_app/app_bar/infocutter_desktop_toolbar.dart';
import 'package:infocutter_app/app_bar/webview_tab_address_field.dart';
import 'package:infocutter_app/app_bar/webview_tab_actions_menu.dart';
import 'package:infocutter_app/app_bar/webview_tab_app_bar_actions.dart';
import 'package:infocutter_app/app_bar/webview_tab_navigation_controls.dart';
import 'package:infocutter_app/app_bar/url_info_popup.dart';
import 'package:infocutter_app/custom_image.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/favorite_model.dart';
import 'package:infocutter_app/models/web_archive_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/pages/developers/main.dart';
import 'package:infocutter_app/pages/settings/main.dart';
import 'package:infocutter_app/reader/reader_mode.dart';
import 'package:infocutter_app/util.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../custom_popup_dialog.dart';
import '../models/window_model.dart';
import '../popup_menu_actions.dart';
import '../project_info_popup.dart';

part 'webview_tab_app_bar_dialogs.dart';

class WebViewTabAppBarController {
  VoidCallback? _focusAddressField;

  void focusAddressField() {
    _focusAddressField?.call();
  }
}

class WebViewTabAppBar extends StatefulWidget {
  final void Function()? showFindOnPage;
  final WebViewTabAppBarController? controller;

  const WebViewTabAppBar({super.key, this.showFindOnPage, this.controller});

  @override
  State<WebViewTabAppBar> createState() => _WebViewTabAppBarState();
}

class _WebViewTabAppBarState extends State<WebViewTabAppBar>
    with SingleTickerProviderStateMixin {
  TextEditingController? _searchController = TextEditingController();
  FocusNode? _focusNode;

  Duration customPopupDialogTransitionDuration =
      const Duration(milliseconds: 300);
  CustomPopupDialogPageRoute? route;

  @override
  void initState() {
    super.initState();
    widget.controller?._focusAddressField = _focusAddressField;
    _focusNode = FocusNode();
    _focusNode?.addListener(() async {
      if (_focusNode != null &&
          !_focusNode!.hasFocus &&
          _searchController != null &&
          _searchController!.text.isEmpty) {
        final windowModel = Provider.of<WindowModel>(context, listen: false);
        final webViewModel = windowModel.getCurrentWebViewModel();
        var webViewController = webViewModel?.webViewController;
        _searchController!.text =
            (await webViewController?.getUrl())?.toString() ?? "";
      }
    });
  }

  @override
  void didUpdateWidget(covariant WebViewTabAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    if (oldWidget.controller?._focusAddressField == _focusAddressField) {
      oldWidget.controller?._focusAddressField = null;
    }
    widget.controller?._focusAddressField = _focusAddressField;
  }

  @override
  void dispose() {
    if (widget.controller?._focusAddressField == _focusAddressField) {
      widget.controller?._focusAddressField = null;
    }
    _focusNode?.dispose();
    _focusNode = null;
    _searchController?.dispose();
    _searchController = null;
    super.dispose();
  }

  int _prevTabIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Selector<WebViewModel, ({WebUri? item1, int? item2})>(
        selector: (context, webViewModel) =>
            (item1: webViewModel.url, item2: webViewModel.tabIndex),
        builder: (context, record, child) {
          _syncSearchController(record);

          final Widget? leading = _buildAppBarHomePageWidget();

          return Selector<WebViewModel, bool>(
              selector: (context, webViewModel) => webViewModel.isIncognitoMode,
              builder: (context, isIncognitoMode, child) {
                // AppBar 는 primary 가 기본 true 라 상태바 인셋을 스스로
                // 먹는다(SafeArea(bottom:false)). 여기에 SafeArea 를 덧대면
                // 인셋이 두 번 들어가므로 감싸지 않는다.
                return AppBar(
                  backgroundColor: isIncognitoMode
                      ? Colors.black38
                      : Theme.of(context).colorScheme.surface,
                  leading: leading,
                  leadingWidth: leading == null ? null : _leadingWidth(),
                  titleSpacing: leading == null ? 10.0 : 0.0,
                  title: _buildSearchTextField(),
                  actions: _buildActionsMenu(),
                );
              });
        });
  }

  void _syncSearchController(({WebUri? item1, int? item2}) record) {
    if (_prevTabIndex != record.item2) {
      _searchController?.text = record.item1?.toString() ?? '';
      _prevTabIndex = record.item2 ?? _prevTabIndex;
      _focusNode?.unfocus();
      return;
    }

    final url = record.item1;
    if (url == null) {
      _searchController?.text = "";
      return;
    }

    if (!(_focusNode?.hasFocus ?? false)) {
      _searchController?.text = url.toString();
    }
  }

  void _focusAddressField() {
    final focusNode = _focusNode;
    final searchController = _searchController;
    if (focusNode == null || searchController == null) {
      return;
    }

    focusNode.requestFocus();
    searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: searchController.text.length,
    );
  }

  void _refreshAppBar(VoidCallback update) {
    setState(update);
  }

  /// `WebViewTabNavigationControls` 의 Row 를 감싸는 좌우 margin(5+5).
  static const double _navRowMargin = 10.0;

  /// leading 슬롯에 실제로 필요한 폭.
  ///
  /// `WebViewTabNavigationControls` 는 margin 안에 `IconButton` 을 늘어놓는다.
  /// 그 버튼은 `constraints` 를 30 으로 줘도 Material 최소 터치 타깃
  /// ([kMinInteractiveDimension] = 48)까지 벌어진다 — 실측 1개당 58.
  /// 그래서 버튼 수 × 48 + margin 으로 잡는다. 기존 하드코딩 130 은
  /// 모바일(홈 1개)에서 72 를 낭비했고, 데스크탑(4개 = 202 필요)에서는
  /// 오히려 모자라 잘렸다.
  double _leadingWidth() {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final settings = browserModel.getSettings();
    final buttonCount = (Util.isDesktop() ? 3 : 0) +
        (settings.homePageEnabled || Util.isDesktop() ? 1 : 0);
    return buttonCount * kMinInteractiveDimension + _navRowMargin;
  }

  Widget? _buildAppBarHomePageWidget() {
    var browserModel = Provider.of<BrowserModel>(context);
    var settings = browserModel.getSettings();

    if (Util.isMobile() && !settings.homePageEnabled) {
      return null;
    }

    return WebViewTabNavigationControls(
      onOpenNewTab: addNewTab,
    );
  }

  Widget _buildSearchTextField() {
    return WebViewTabAddressField(
      searchController: _searchController,
      focusNode: _focusNode,
      onShowUrlInfo: showUrlInfo,
      onOpenUrlInNewTab: (url) {
        addNewTab(url: url);
      },
    );
  }

  List<Widget> _buildActionsMenu() {
    return [
      if (Util.isDesktop()) const InfocutterDesktopToolbar(),
      WebViewTabActionsMenu(
        onPopupMenuChoiceSelected: _popupMenuChoiceAction,
        onAddNewTab: addNewTab,
        onAddNewIncognitoTab: addNewIncognitoTab,
        onShowUrlInfoAfterPopup: _showUrlInfoAfterPopup,
        onTakeScreenshotAfterPopup: _takeScreenshotAfterPopup,
      ),
    ];
  }

  Future<void> _showUrlInfoAfterPopup() async {
    await route?.completed;
    showUrlInfo();
  }

  Future<void> _takeScreenshotAfterPopup() async {
    await route?.completed;
    takeScreenshotAndShow();
  }

  void _popupMenuChoiceAction(String choice) async {
    switch (choice) {
      case PopupMenuActions.OPEN_NEW_WINDOW:
        openNewWindow();
        break;
      case PopupMenuActions.SAVE_WINDOW:
        setShouldSave();
        break;
      case PopupMenuActions.SAVED_WINDOWS:
        showSavedWindows();
        break;
      case PopupMenuActions.NEW_TAB:
        addNewTab();
        break;
      case PopupMenuActions.NEW_INCOGNITO_TAB:
        addNewIncognitoTab();
        break;
      case PopupMenuActions.FAVORITES:
        showFavorites();
        break;
      case PopupMenuActions.HISTORY:
        showHistory();
        break;
      case PopupMenuActions.WEB_ARCHIVES:
        showWebArchives();
        break;
      case PopupMenuActions.FIND_ON_PAGE:
        await _handleFindOnPageAction();
        break;
      case PopupMenuActions.READER_MODE:
        await _handleReaderModeAction();
        break;
      case PopupMenuActions.SHARE:
        share();
        break;
      case PopupMenuActions.DESKTOP_MODE:
        toggleDesktopMode();
        break;
      case PopupMenuActions.DEVELOPERS:
        _runAfterMenuClose(goToDevelopersPage);
        break;
      case PopupMenuActions.SETTINGS:
        _runAfterMenuClose(goToSettingsPage);
        break;
      case PopupMenuActions.INAPPWEBVIEW_PROJECT:
        _runAfterMenuClose(openProjectPopup);
        break;
    }
  }

  Future<void> _handleFindOnPageAction() async {
    final currentWebViewModel =
        Provider.of<WebViewModel>(context, listen: false);
    final isFindInteractionEnabled =
        currentWebViewModel.settings?.isFindInteractionEnabled ?? false;
    final findInteractionController =
        currentWebViewModel.findInteractionController;

    if ((Util.isIOS() || Util.isMacOS()) &&
        isFindInteractionEnabled &&
        findInteractionController != null) {
      await findInteractionController.presentFindNavigator();
      return;
    }

    widget.showFindOnPage?.call();
  }

  Future<void> _handleReaderModeAction() async {
    final currentWebViewModel =
        Provider.of<WebViewModel>(context, listen: false);
    await const ReaderMode().openFromController(
      context,
      currentWebViewModel.webViewController,
    );
  }

  void _runAfterMenuClose(VoidCallback action) {
    Future.delayed(const Duration(milliseconds: 300), action);
  }

  void addNewTab({WebUri? url}) {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final settings = browserModel.getSettings();

    url ??= WebUri(settings.startPageUrl);

    windowModel.addTab(WebViewModel(url: url));
  }

  void addNewIncognitoTab({WebUri? url}) {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final settings = browserModel.getSettings();

    url ??= WebUri(settings.startPageUrl);

    windowModel.addTab(WebViewModel(url: url, isIncognitoMode: true));
  }

  void share() {
    shareCurrentWebViewTab(context);
  }

  void openNewWindow() {
    openNewBrowserWindow(context);
  }

  void setShouldSave() {
    toggleShouldSaveWindow(context);
  }

  void toggleDesktopMode() async {
    await toggleWebViewTabDesktopMode(context);
  }

  void showUrlInfo() {
    var webViewModel = Provider.of<WebViewModel>(context, listen: false);
    var url = webViewModel.url;
    if (url == null || url.toString().isEmpty) {
      return;
    }

    route = CustomPopupDialog.show(
      context: context,
      transitionDuration: customPopupDialogTransitionDuration,
      builder: (context) {
        return UrlInfoPopup(
          route: route!,
          transitionDuration: customPopupDialogTransitionDuration,
          onWebViewTabSettingsClicked: () {
            goToSettingsPage();
          },
        );
      },
    );
  }

  void goToDevelopersPage() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const DevelopersPage()));
  }

  void goToSettingsPage() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  void openProjectPopup() {
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return const ProjectInfoPopup();
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void takeScreenshotAndShow() async {
    await takeWebViewTabScreenshotAndShow(context);
  }
}
