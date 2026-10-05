import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/pages/settings/cross_platform/cross_platform_settings_context.dart';
import 'package:infocutter_app/pages/settings/cross_platform/cross_platform_settings_home_page.dart';
import 'package:infocutter_app/pages/settings/cross_platform/cross_platform_settings_section1.dart';
import 'package:infocutter_app/pages/settings/cross_platform/cross_platform_settings_section3.dart';
import 'package:infocutter_app/pages/settings/cross_platform/cross_platform_settings_widgets.dart';
import 'package:infocutter_app/pages/settings/cross_platform_webview_settings.dart';
import 'package:infocutter_app/util.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../models/window_model.dart';

class CrossPlatformSettings extends StatefulWidget {
  final Future<String> Function()? defaultUserAgentLoader;
  final Future<WebViewPackageInfo?> Function()? currentWebViewPackageLoader;

  const CrossPlatformSettings({
    super.key,
    this.defaultUserAgentLoader,
    this.currentWebViewPackageLoader,
  });

  @override
  State<CrossPlatformSettings> createState() => _CrossPlatformSettingsState();
}

class _CrossPlatformSettingsState extends State<CrossPlatformSettings> {
  final TextEditingController _customHomePageController =
      TextEditingController();

  @override
  void dispose() {
    _customHomePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowModel = Provider.of<WindowModel>(context);
    final children = _buildBaseSettings();
    if (windowModel.webViewModels.isNotEmpty) {
      children.add(const AdvancedSettingsGroup(
        children: [CrossPlatformWebViewSettings()],
      ));
    }

    return ListView(
      children: children,
    );
  }

  List<Widget> _buildBaseSettings() {
    final browserModel = Provider.of<BrowserModel>(context);
    final windowModel = Provider.of<WindowModel>(context);
    final settingsContext = CrossPlatformSettingsContext(
      context: context,
      browserModel: browserModel,
      settings: browserModel.getSettings(),
      windowModel: windowModel,
      l10n: AppLocalizations.of(context),
      setStateWith: setState,
      customHomePageController: _customHomePageController,
    );
    final loaders = CrossPlatformSettingsLoaders(
      defaultUserAgentLoader: widget.defaultUserAgentLoader,
      currentWebViewPackageLoader: widget.currentWebViewPackageLoader,
    );

    var widgets = <Widget>[
      ...buildCrossPlatformSettingsSection1(settingsContext),
      ...buildCrossPlatformSettingsSection2(settingsContext),
      ...buildCrossPlatformSettingsSection3(settingsContext, loaders),
      ...buildCrossPlatformSettingsSection4(settingsContext),
    ];

    if (Util.isAndroid()) {
      widgets.add(buildWebViewPackageInfo(loaders));
    }

    return widgets;
  }
}
