import 'package:flutter/material.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection13(AndroidSettingsContext ctx) {
  return [
    _horizontalScrollbarThumbColor(ctx),
    _horizontalScrollbarTrackColor(ctx),
  ];
}

Widget _horizontalScrollbarThumbColor(AndroidSettingsContext ctx) {
  return androidColorTile(
    context: ctx.context,
    title: "Horizontal Scrollbar Thumb Color",
    subtitle: "Sets the horizontal scrollbar thumb color.",
    currentColor: ctx
        .readOrNull<Color>((s) => s.horizontalScrollbarThumbColor)
        ?.toString(),
    onColorChanged: (value) =>
        ctx.apply((s) => s.horizontalScrollbarThumbColor = value),
  );
}

Widget _horizontalScrollbarTrackColor(AndroidSettingsContext ctx) {
  return androidColorTile(
    context: ctx.context,
    title: "Horizontal Scrollbar Track Color",
    subtitle: "Sets the horizontal scrollbar track color.",
    currentColor: ctx
        .readOrNull<Color>((s) => s.horizontalScrollbarTrackColor)
        ?.toString(),
    onColorChanged: (value) =>
        ctx.apply((s) => s.horizontalScrollbarTrackColor = value),
  );
}
