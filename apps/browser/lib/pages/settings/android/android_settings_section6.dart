import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection6(AndroidSettingsContext ctx) {
  return [
    _forceDark(ctx),
    _geolocationEnabled(ctx),
    _layoutAlgorithm(ctx),
    _loadWithOverviewMode(ctx),
  ];
}

Widget _forceDark(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Algorithmic Darkening"),
    subtitle: const Text(
      "Allow the WebView to darken page content algorithmically.",
    ),
    value: ctx.read<bool>((s) => s.algorithmicDarkeningAllowed, false),
    onChanged: (value) =>
        ctx.apply((s) => s.algorithmicDarkeningAllowed = value),
  );
}

Widget _geolocationEnabled(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Geolocation Enabled"),
    subtitle: const Text("Sets whether Geolocation API is enabled."),
    value: ctx.read<bool>((s) => s.geolocationEnabled, true),
    onChanged: (value) => ctx.apply((s) => s.geolocationEnabled = value),
  );
}

Widget _layoutAlgorithm(AndroidSettingsContext ctx) {
  return ListTile(
    title: const Text("Layout Algorithm"),
    subtitle: const Text(
        "Sets the underlying layout algorithm. This will cause a re-layout of the WebView."),
    trailing: androidEnumDropdown<LayoutAlgorithm>(
      hint: "Layout Algorithm",
      values: LayoutAlgorithm.values,
      value: ctx.readOrNull<LayoutAlgorithm>((s) => s.layoutAlgorithm),
      onChanged: (value) => ctx.apply((s) => s.layoutAlgorithm = value),
    ),
  );
}

Widget _loadWithOverviewMode(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Load With Overview Mode"),
    subtitle: const Text(
        "Sets whether the WebView loads pages in overview mode, that is, zooms out the content to fit on screen by width."),
    value: ctx.read<bool>((s) => s.loadWithOverviewMode, false),
    onChanged: (value) => ctx.apply((s) => s.loadWithOverviewMode = value),
  );
}
