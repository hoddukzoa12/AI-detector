import 'package:flutter/material.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection12(AndroidSettingsContext ctx) {
  return [
    _verticalScrollbarThumbColor(ctx),
    _verticalScrollbarTrackColor(ctx),
  ];
}

Widget _verticalScrollbarThumbColor(AndroidSettingsContext ctx) {
  return androidColorTile(
    context: ctx.context,
    title: "Vertical Scrollbar Thumb Color",
    subtitle: "Sets the vertical scrollbar thumb color.",
    currentColor:
        ctx.readOrNull<Color>((s) => s.verticalScrollbarThumbColor)?.toString(),
    onColorChanged: (value) =>
        ctx.apply((s) => s.verticalScrollbarThumbColor = value),
  );
}

Widget _verticalScrollbarTrackColor(AndroidSettingsContext ctx) {
  return androidColorTile(
    context: ctx.context,
    title: "Vertical Scrollbar Track Color",
    subtitle: "Sets the vertical scrollbar track color.",
    currentColor:
        ctx.readOrNull<Color>((s) => s.verticalScrollbarTrackColor)?.toString(),
    onColorChanged: (value) =>
        ctx.apply((s) => s.verticalScrollbarTrackColor = value),
  );
}
