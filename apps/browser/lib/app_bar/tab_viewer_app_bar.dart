import 'package:flutter/material.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/l10n/localized_menu_labels.dart';
import 'package:infocutter_app/pages/settings/main.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../custom_popup_menu_item.dart';
import '../models/window_model.dart';
import '../tab_viewer_popup_menu_actions.dart';

class TabViewerAppBar extends StatefulWidget implements PreferredSizeWidget {
  const TabViewerAppBar({super.key})
      : preferredSize = const Size.fromHeight(kToolbarHeight);

  @override
  State<TabViewerAppBar> createState() => _TabViewerAppBarState();

  @override
  final Size preferredSize;
}

class _TabViewerAppBarState extends State<TabViewerAppBar> {
  GlobalKey tabInkWellKey = GlobalKey();

  Widget _buildPopupMenuLabel(String text) {
    return Expanded(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 10.0,
      leading: _buildAddTabButton(),
      actions: _buildActionsMenu(),
    );
  }

  Widget _buildAddTabButton() {
    return IconButton(
      tooltip: AppLocalizations.of(context).newTab,
      icon: const Icon(Icons.add),
      onPressed: () {
        addNewTab();
      },
    );
  }

  List<Widget> _buildActionsMenu() {
    final l10n = AppLocalizations.of(context);
    final browserModel = Provider.of<BrowserModel>(context);
    final windowModel = Provider.of<WindowModel>(context);
    final settings = browserModel.getSettings();

    return <Widget>[
      _buildTabCountButton(
        browserModel: browserModel,
        homePageEnabled: settings.homePageEnabled,
        windowModel: windowModel,
      ),
      _buildPopupMenuButton(l10n, windowModel),
    ];
  }

  Widget _buildTabCountButton({
    required BrowserModel browserModel,
    required bool homePageEnabled,
    required WindowModel windowModel,
  }) {
    return InkWell(
      key: tabInkWellKey,
      onTap: () => _toggleTabScroller(browserModel, windowModel),
      child: Padding(
        padding: homePageEnabled
            ? const EdgeInsets.only(
                left: 20.0,
                top: 15.0,
                right: 10.0,
                bottom: 15.0,
              )
            : const EdgeInsets.only(
                left: 10.0,
                top: 15.0,
                right: 10.0,
                bottom: 15.0,
              ),
        child: _buildTabCountBadge(windowModel.webViewModels.length),
      ),
    );
  }

  Widget _buildTabCountBadge(int count) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 2.0),
        borderRadius: BorderRadius.circular(5.0),
      ),
      constraints: const BoxConstraints(minWidth: 25.0),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
        ),
      ),
    );
  }

  Widget _buildPopupMenuButton(
    AppLocalizations l10n,
    WindowModel windowModel,
  ) {
    return PopupMenuButton<String>(
      onSelected: _popupMenuChoiceAction,
      itemBuilder: (popupMenuContext) => TabViewerPopupMenuActions.choices
          .map((choice) => _buildPopupMenuItem(choice, windowModel, l10n))
          .toList(),
    );
  }

  PopupMenuEntry<String> _buildPopupMenuItem(
    String choice,
    WindowModel windowModel,
    AppLocalizations l10n,
  ) {
    final icon = _popupMenuIcon(choice);
    if (icon == null) {
      return CustomPopupMenuItem<String>(
        value: choice,
        child: Text(l10n.tabViewerPopupMenuActionLabel(choice)),
      );
    }

    return CustomPopupMenuItem<String>(
      enabled: choice != TabViewerPopupMenuActions.CLOSE_ALL_TABS ||
          windowModel.webViewModels.isNotEmpty,
      value: choice,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPopupMenuLabel(l10n.tabViewerPopupMenuActionLabel(choice)),
          icon,
        ],
      ),
    );
  }

  Widget? _popupMenuIcon(String choice) => switch (choice) {
        TabViewerPopupMenuActions.NEW_TAB =>
          const Icon(Icons.add, color: Colors.black),
        TabViewerPopupMenuActions.NEW_INCOGNITO_TAB =>
          const Icon(Icons.visibility_off, color: Colors.black),
        TabViewerPopupMenuActions.CLOSE_ALL_TABS =>
          const Icon(Icons.close, color: Colors.black),
        TabViewerPopupMenuActions.SETTINGS =>
          const Icon(Icons.settings, color: Colors.grey),
        _ => null,
      };

  void _toggleTabScroller(
    BrowserModel browserModel,
    WindowModel windowModel,
  ) {
    if (windowModel.webViewModels.isNotEmpty) {
      browserModel.showTabScroller = !browserModel.showTabScroller;
      return;
    }
    browserModel.showTabScroller = false;
  }

  void _popupMenuChoiceAction(String choice) async {
    switch (choice) {
      case TabViewerPopupMenuActions.NEW_TAB:
        Future.delayed(const Duration(milliseconds: 300), () {
          addNewTab();
        });
        break;
      case TabViewerPopupMenuActions.NEW_INCOGNITO_TAB:
        Future.delayed(const Duration(milliseconds: 300), () {
          addNewIncognitoTab();
        });
        break;
      case TabViewerPopupMenuActions.CLOSE_ALL_TABS:
        Future.delayed(const Duration(milliseconds: 300), () {
          closeAllTabs();
        });
        break;
      case TabViewerPopupMenuActions.SETTINGS:
        Future.delayed(const Duration(milliseconds: 300), () {
          goToSettingsPage();
        });
        break;
    }
  }

  void addNewTab({WebUri? url}) {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final settings = browserModel.getSettings();

    url ??= WebUri(settings.startPageUrl);

    browserModel.showTabScroller = false;

    windowModel.addTab(WebViewModel(url: url));
  }

  void addNewIncognitoTab({WebUri? url}) {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final settings = browserModel.getSettings();

    url ??= WebUri(settings.startPageUrl);

    browserModel.showTabScroller = false;

    windowModel.addTab(WebViewModel(url: url, isIncognitoMode: true));
  }

  void closeAllTabs() {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);

    browserModel.showTabScroller = false;

    windowModel.closeAllTabs();
  }

  void goToSettingsPage() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const SettingsPage()));
  }
}
