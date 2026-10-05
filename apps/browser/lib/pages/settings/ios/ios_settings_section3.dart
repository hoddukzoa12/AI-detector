import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/multiselect_dialog.dart';

import 'ios_settings_context.dart';

List<Widget> buildIOSSettingsSection3(IOSSettingsContext ctx) {
  return [
    _dataDetectorTypesTile(ctx),
    _sharedCookiesEnabledTile(ctx),
    _automaticallyAdjustsScrollIndicatorInsetsTile(ctx),
    _accessibilityIgnoresInvertColorsTile(ctx),
  ];
}

Widget _dataDetectorTypesTile(IOSSettingsContext ctx) {
  final context = ctx.buildContext;
  return ListTile(
    title: const Text("Data Detector Types"),
    subtitle: const Text(
        "Specifying a dataDetectoryTypes value adds interactivity to web content that matches the value."),
    trailing: Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 2),
      child: Text(ctx.settings?.dataDetectorTypes
              ?.map((e) => e.toString())
              .join(", ") ??
          ""),
    ),
    onTap: () => _pickDataDetectorTypes(ctx),
  );
}

Future<void> _pickDataDetectorTypes(IOSSettingsContext ctx) async {
  final dataDetectoryTypesSelected = await showDialog<Set<DataDetectorTypes>>(
    context: ctx.buildContext,
    builder: (BuildContext context) {
      return MultiSelectDialog(
        title: const Text("Data Detector Types"),
        items: DataDetectorTypes.values.map((dataDetectorType) {
          return MultiSelectDialogItem<DataDetectorTypes>(
              value: dataDetectorType, label: dataDetectorType.toString());
        }).toList(),
        initialSelectedValues: ctx.settings?.dataDetectorTypes?.toSet(),
      );
    },
  );
  if (dataDetectoryTypesSelected != null) {
    ctx.apply((settings) =>
        settings.dataDetectorTypes = dataDetectoryTypesSelected.toList());
  }
}

Widget _sharedCookiesEnabledTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Shared Cookies Enabled",
    subtitle:
        "Sets if shared cookies from \"HTTPCookieStorage.shared\" should used for every load request in the WebView.",
    value: ctx.settings?.sharedCookiesEnabled ?? false,
    write: (settings, value) => settings.sharedCookiesEnabled = value,
  );
}

Widget _automaticallyAdjustsScrollIndicatorInsetsTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Automatically Adjusts Scroll Indicator Insets",
    subtitle:
        "Configures whether the scroll indicator insets are automatically adjusted by the system.",
    value: ctx.settings?.automaticallyAdjustsScrollIndicatorInsets ?? false,
    write: (settings, value) =>
        settings.automaticallyAdjustsScrollIndicatorInsets = value,
  );
}

Widget _accessibilityIgnoresInvertColorsTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Accessibility Ignores Invert Colors",
    subtitle:
        "Sets whether the WebView ignores an accessibility request to invert its colors.",
    value: ctx.settings?.accessibilityIgnoresInvertColors ?? false,
    write: (settings, value) =>
        settings.accessibilityIgnoresInvertColors = value,
  );
}
