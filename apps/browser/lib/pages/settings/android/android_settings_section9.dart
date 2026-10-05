import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection9(AndroidSettingsContext ctx) {
  return [
    _thirdPartyCookiesEnabled(ctx),
    _hardwareAcceleration(ctx),
    _supportMultipleWindows(ctx),
    const ListTile(
      title: Text("Over Scroll Mode"),
      subtitle: Text("Sets the WebView's over-scroll mode."),
    ),
    _overScrollMode(ctx),
    _networkAvailable(ctx),
  ];
}

Widget _thirdPartyCookiesEnabled(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Third Party Cookies Enabled"),
    subtitle: const Text(
        "Sets whether the Webview should enable third party cookies."),
    value: ctx.read<bool>((s) => s.thirdPartyCookiesEnabled, true),
    onChanged: (value) => ctx.apply((s) => s.thirdPartyCookiesEnabled = value),
  );
}

Widget _hardwareAcceleration(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Hardware Acceleration"),
    subtitle: const Text(
        "Sets whether the Webview should enable Hardware Acceleration."),
    value: ctx.read<bool>((s) => s.hardwareAcceleration, true),
    onChanged: (value) => ctx.apply((s) => s.hardwareAcceleration = value),
  );
}

Widget _supportMultipleWindows(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Support Multiple Windows"),
    subtitle: const Text(
        "Sets whether the WebView whether supports multiple windows."),
    value: ctx.read<bool>((s) => s.supportMultipleWindows, false),
    onChanged: (value) => ctx.apply((s) => s.supportMultipleWindows = value),
  );
}

Widget _overScrollMode(AndroidSettingsContext ctx) {
  return androidEnumDropdownRow<OverScrollMode>(
    hint: "Over Scroll Mode",
    values: OverScrollMode.values,
    value: ctx.readOrNull<OverScrollMode>((s) => s.overScrollMode),
    onChanged: (value) => ctx.apply((s) => s.overScrollMode = value),
  );
}

Widget _networkAvailable(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Network Available"),
    subtitle: const Text("Informs WebView of the network state."),
    value: ctx.read<bool>((s) => s.networkAvailable, true),
    onChanged: (value) => ctx.apply((s) => s.networkAvailable = value),
  );
}
