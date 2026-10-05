import 'package:flutter/material.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/pages/settings/cross_platform_webview_settings.dart';
import 'package:provider/provider.dart';

import '../../models/window_model.dart';
import 'android/android_settings_context.dart';
import 'android/android_settings_section1.dart';
import 'android/android_settings_section2.dart';
import 'android/android_settings_section3.dart';
import 'android/android_settings_section4.dart';
import 'android/android_settings_section5.dart';
import 'android/android_settings_section6.dart';
import 'android/android_settings_section7.dart';
import 'android/android_settings_section8.dart';
import 'android/android_settings_section9.dart';
import 'android/android_settings_section10.dart';
import 'android/android_settings_section11.dart';
import 'android/android_settings_section12.dart';
import 'android/android_settings_section13.dart';

class AndroidSettings extends StatefulWidget {
  const AndroidSettings({super.key});

  @override
  State<AndroidSettings> createState() => _AndroidSettingsState();
}

class _AndroidSettingsState extends State<AndroidSettings> {
  @override
  Widget build(BuildContext context) {
    final settings = _buildAndroidWebViewTabSettings();

    // 이 탭은 전부 WebView 원시 설정이다. 기본은 접어 두고 필요한 사람만 편다.
    return ListView(
      children: settings.isEmpty
          ? const []
          : [AdvancedSettingsGroup(children: settings)],
    );
  }

  List<Widget> _buildAndroidWebViewTabSettings() {
    final windowModel = Provider.of<WindowModel>(context);
    if (windowModel.webViewModels.isEmpty) {
      return [];
    }
    var currentWebViewModel = Provider.of<WebViewModel>(context);
    var ctx = AndroidSettingsContext(
      context: context,
      windowModel: windowModel,
      webViewModel: currentWebViewModel,
      webViewController: currentWebViewModel.webViewController,
      setStateWith: setState,
    );

    return [
      ...buildAndroidSettingsSection1(ctx),
      ...buildAndroidSettingsSection2(ctx),
      ...buildAndroidSettingsSection3(ctx),
      ...buildAndroidSettingsSection4(ctx),
      ...buildAndroidSettingsSection5(ctx),
      ...buildAndroidSettingsSection6(ctx),
      ...buildAndroidSettingsSection7(ctx),
      ...buildAndroidSettingsSection8(ctx),
      ...buildAndroidSettingsSection9(ctx),
      ...buildAndroidSettingsSection10(ctx),
      ...buildAndroidSettingsSection11(ctx),
      ...buildAndroidSettingsSection12(ctx),
      ...buildAndroidSettingsSection13(ctx),
    ];
  }
}
