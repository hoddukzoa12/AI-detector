import 'package:flutter/material.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection7(AndroidSettingsContext ctx) {
  return [
    _loadsImagesAutomatically(ctx),
    _minimumLogicalFontSize(ctx),
    _initialScale(ctx),
    _needInitialFocus(ctx),
    _offscreenPreRaster(ctx),
  ];
}

Widget _loadsImagesAutomatically(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Loads Images Automatically"),
    subtitle: const Text(
        "Sets whether the WebView should load image resources. Note that this method controls loading of all images, including those embedded using the data URI scheme."),
    value: ctx.read<bool>((s) => s.loadsImagesAutomatically, true),
    onChanged: (value) => ctx.apply((s) => s.loadsImagesAutomatically = value),
  );
}

Widget _minimumLogicalFontSize(AndroidSettingsContext ctx) {
  return androidNumberTile(
    title: "Minimum Logical Font Size",
    subtitle: "Sets the minimum logical font size.",
    initialValue:
        ctx.readOrNull<int>((s) => s.minimumLogicalFontSize)?.toString(),
    onSubmitted: (value) =>
        ctx.apply((s) => s.minimumLogicalFontSize = int.parse(value)),
  );
}

Widget _initialScale(AndroidSettingsContext ctx) {
  return androidNumberTile(
    title: "Initial Scale",
    subtitle: "Sets the initial scale for this WebView. 0 means default.",
    initialValue: ctx.readOrNull<int>((s) => s.initialScale)?.toString(),
    onSubmitted: (value) => ctx.apply((s) => s.initialScale = int.parse(value)),
  );
}

Widget _needInitialFocus(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Need Initial Focus"),
    subtitle: const Text("Tells the WebView whether it needs to set a node."),
    value: ctx.read<bool>((s) => s.needInitialFocus, true),
    onChanged: (value) => ctx.apply((s) => s.needInitialFocus = value),
  );
}

Widget _offscreenPreRaster(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Offscreen Pre Raster"),
    subtitle: const Text(
        "Sets whether this WebView should raster tiles when it is offscreen but attached to a window."),
    value: ctx.read<bool>((s) => s.offscreenPreRaster, false),
    onChanged: (value) => ctx.apply((s) => s.offscreenPreRaster = value),
  );
}
