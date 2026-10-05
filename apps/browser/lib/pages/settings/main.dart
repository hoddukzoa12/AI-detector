import 'package:flutter/material.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/pages/settings/android_settings.dart';
import 'package:infocutter_app/pages/settings/cross_platform_settings.dart';
import 'package:infocutter_app/pages/settings/ios_settings.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../app_bar/custom_app_bar_wrapper.dart';
import '../../custom_popup_menu_item.dart';

class PopupSettingsMenuActions {
  // ignore: constant_identifier_names
  static const String RESET_BROWSER_SETTINGS = "Reset Browser Settings";

  // ignore: constant_identifier_names
  static const String RESET_WEBVIEW_SETTINGS = "Reset WebView Settings";

  static const List<String> choices = <String>[
    RESET_BROWSER_SETTINGS,
    RESET_WEBVIEW_SETTINGS,
  ];
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: CustomAppBarWrapper(appBar: _buildAppBar(context)),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            CrossPlatformSettings(),
            AndroidSettings(),
            IOSSettings(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) => AppBar(
        bottom: _buildTabBar(context),
        title: const Text("Settings"),
        actions: <Widget>[_buildActionsMenu()],
      );

  TabBar _buildTabBar(BuildContext context) => TabBar(
        onTap: (value) => FocusScope.of(context).unfocus(),
        tabs: const [
          Tab(
            text: "Cross-Platform",
            icon: SizedBox(
              width: 25,
              height: 25,
              child: CircleAvatar(
                backgroundImage: AssetImage("assets/icon/icon.png"),
              ),
            ),
          ),
          Tab(
            text: "Android",
            icon: Icon(Icons.android, color: Colors.green),
          ),
          Tab(
            text: "iOS",
            icon: Icon(Icons.phone_iphone),
          ),
        ],
      );

  PopupMenuButton<String> _buildActionsMenu() => PopupMenuButton<String>(
        onSelected: _popupMenuChoiceAction,
        itemBuilder: (context) => const [
          CustomPopupMenuItem<String>(
            value: PopupSettingsMenuActions.RESET_BROWSER_SETTINGS,
            child: _SettingsMenuItem(
              label: PopupSettingsMenuActions.RESET_BROWSER_SETTINGS,
              icon: Icons.public,
            ),
          ),
          CustomPopupMenuItem<String>(
            value: PopupSettingsMenuActions.RESET_WEBVIEW_SETTINGS,
            child: _SettingsMenuItem(
              label: PopupSettingsMenuActions.RESET_WEBVIEW_SETTINGS,
              icon: Icons.web,
            ),
          ),
        ],
      );

  void _popupMenuChoiceAction(String choice) async {
    switch (choice) {
      case PopupSettingsMenuActions.RESET_BROWSER_SETTINGS:
        var browserModel = Provider.of<BrowserModel>(context, listen: false);
        setState(() {
          browserModel.updateSettings(BrowserSettings());
          browserModel.save();
        });
        break;
      case PopupSettingsMenuActions.RESET_WEBVIEW_SETTINGS:
        var browserModel = Provider.of<BrowserModel>(context, listen: false);
        browserModel.getSettings();
        var currentWebViewModel =
            Provider.of<WebViewModel>(context, listen: false);
        var webViewController = currentWebViewModel.webViewController;
        await webViewController?.setSettings(
            settings: InAppWebViewSettings(
                incognito: currentWebViewModel.isIncognitoMode,
                useOnDownloadStart: true,
                useOnLoadResource: true,
                allowsLinkPreview: false));
        currentWebViewModel.settings = await webViewController?.getSettings();
        browserModel.save();
        setState(() {});
        break;
    }
  }
}

class _SettingsMenuItem extends StatelessWidget {
  const _SettingsMenuItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Icon(icon, color: Colors.black),
        ],
      );
}
