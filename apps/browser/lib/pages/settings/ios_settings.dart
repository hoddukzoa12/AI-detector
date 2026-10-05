import 'package:flutter/material.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/pages/settings/cross_platform_webview_settings.dart';
import 'package:provider/provider.dart';

import '../../models/window_model.dart';
import 'ios/ios_settings_context.dart';
import 'ios/ios_settings_section1.dart';
import 'ios/ios_settings_section2.dart';
import 'ios/ios_settings_section3.dart';
import 'ios/ios_settings_section4.dart';
import 'ios/ios_settings_section5.dart';
import 'ios/ios_settings_section6.dart';
import 'ios/ios_settings_section7.dart';

class IOSSettings extends StatefulWidget {
  const IOSSettings({super.key});

  @override
  State<IOSSettings> createState() => _IOSSettingsState();
}

class _IOSSettingsState extends State<IOSSettings> {
  @override
  Widget build(BuildContext context) {
    final settings = _buildIOSWebViewSettings();

    // 이 탭은 전부 WebView 원시 설정이다. 기본은 접어 두고 필요한 사람만 편다.
    return ListView(
      children: settings.isEmpty
          ? const []
          : [AdvancedSettingsGroup(children: settings)],
    );
  }

  List<Widget> _buildIOSWebViewSettings() {
    final windowModel = Provider.of<WindowModel>(context);
    if (windowModel.webViewModels.isEmpty) {
      return [];
    }
    var currentWebViewModel = Provider.of<WebViewModel>(context);
    var webViewController = currentWebViewModel.webViewController;

    final ctx = IOSSettingsContext(
      windowModel: windowModel,
      webViewModel: currentWebViewModel,
      webViewController: webViewController,
      buildContext: context,
      refresh: () => setState(() {}),
    );

    return [
      ...buildIOSSettingsSection1(ctx),
      ...buildIOSSettingsSection2(ctx),
      ...buildIOSSettingsSection3(ctx),
      ...buildIOSSettingsSection4(ctx),
      ...buildIOSSettingsSection5(ctx),
      ...buildIOSSettingsSection6(ctx),
      ...buildIOSSettingsSection7(ctx),
      ..._buildIOSSettingsSection8(
        windowModel,
        currentWebViewModel,
        webViewController,
      ),
    ];
  }

  List<Widget> _buildIOSSettingsSection8(
    WindowModel windowModel,
    WebViewModel currentWebViewModel,
    InAppWebViewController? webViewController,
  ) {
    return [
      SwitchListTile(
        title: const Text("Element Fullscreen Enabled"),
        subtitle:
            const Text("Indicates whether fullscreen API is enabled or not."),
        value:
            currentWebViewModel.settings?.isElementFullscreenEnabled ?? false,
        onChanged: (value) {
          currentWebViewModel.settings?.isElementFullscreenEnabled = value;
          webViewController?.setSettings(
              settings: currentWebViewModel.settings ?? InAppWebViewSettings());
          windowModel.saveInfo();
          setState(() {});
        },
      ),
      SwitchListTile(
        title: const Text("Find Interaction Enabled"),
        subtitle: const Text(
            "Indicates whether the web view's built-in find interaction native UI is enabled or not."),
        value: currentWebViewModel.settings?.isFindInteractionEnabled ?? false,
        onChanged: (value) {
          currentWebViewModel.settings?.isFindInteractionEnabled = value;
          webViewController?.setSettings(
              settings: currentWebViewModel.settings ?? InAppWebViewSettings());
          windowModel.saveInfo();
          setState(() {});
        },
      ),
    ];
  }
}
