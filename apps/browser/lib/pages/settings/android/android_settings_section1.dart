import 'package:flutter/material.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection1(AndroidSettingsContext ctx) {
  return [
    const ListTile(
      title: Text("Current WebView Android Settings"),
      enabled: false,
    ),
    _textZoom(ctx),
    _clearSessionCache(ctx),
    _builtInZoomControls(ctx),
    _displayZoomControls(ctx),
    _databaseEnabled(ctx),
  ];
}

Widget _textZoom(AndroidSettingsContext ctx) {
  return androidNumberTile(
    title: "Text Zoom",
    subtitle: "Sets the text zoom of the page in percent.",
    initialValue: ctx.readOrNull<int>((s) => s.textZoom)?.toString(),
    onSubmitted: (value) => ctx.apply((s) => s.textZoom = int.parse(value)),
  );
}

Widget _clearSessionCache(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Clear Session Cache"),
    subtitle: const Text(
        "Sets whether the WebView should have the session cookie cache cleared before the new window is opened."),
    // ignore: deprecated_member_use
    value: ctx.read<bool>((s) => s.clearSessionCache, false),
    // ignore: deprecated_member_use
    onChanged: (value) => ctx.apply((s) => s.clearSessionCache = value),
  );
}

Widget _builtInZoomControls(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Built In Zoom Controls"),
    subtitle: const Text(
        "Sets whether the WebView should use its built-in zoom mechanisms."),
    value: ctx.read<bool>((s) => s.builtInZoomControls, false),
    onChanged: (value) => ctx.apply((s) => s.builtInZoomControls = value),
  );
}

Widget _displayZoomControls(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Display Zoom Controls"),
    subtitle: const Text(
        "Sets whether the WebView should display on-screen zoom controls when using the built-in zoom mechanisms."),
    value: ctx.read<bool>((s) => s.displayZoomControls, false),
    onChanged: (value) => ctx.apply((s) => s.displayZoomControls = value),
  );
}

Widget _databaseEnabled(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Database storage API"),
    subtitle:
        const Text("Sets whether the Database storage API should be enabled."),
    value: ctx.read<bool>((s) => s.databaseEnabled, true),
    onChanged: (value) => ctx.apply((s) => s.databaseEnabled = value),
  );
}
