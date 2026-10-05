import 'package:flutter/material.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection4(AndroidSettingsContext ctx) {
  return [
    _cursiveFontFamily(ctx),
    _defaultFixedFontSize(ctx),
    _defaultFontSize(ctx),
    _defaultTextEncodingName(ctx),
  ];
}

Widget _cursiveFontFamily(AndroidSettingsContext ctx) {
  return androidTextTile(
    title: "Cursive Font Family",
    subtitle: "Sets the cursive font family name.",
    width: MediaQuery.of(ctx.context).size.width / 3,
    initialValue: ctx.readOrNull<String>((s) => s.cursiveFontFamily),
    onSubmitted: (value) => ctx.apply((s) => s.cursiveFontFamily = value),
  );
}

Widget _defaultFixedFontSize(AndroidSettingsContext ctx) {
  return androidNumberTile(
    title: "Default Fixed Font Size",
    subtitle: "Sets the default fixed font size.",
    initialValue:
        ctx.readOrNull<int>((s) => s.defaultFixedFontSize)?.toString(),
    onSubmitted: (value) =>
        ctx.apply((s) => s.defaultFixedFontSize = int.parse(value)),
  );
}

Widget _defaultFontSize(AndroidSettingsContext ctx) {
  return androidNumberTile(
    title: "Default Font Size",
    subtitle: "Sets the default font size.",
    initialValue: ctx.readOrNull<int>((s) => s.defaultFontSize)?.toString(),
    onSubmitted: (value) =>
        ctx.apply((s) => s.defaultFontSize = int.parse(value)),
  );
}

Widget _defaultTextEncodingName(AndroidSettingsContext ctx) {
  return androidTextTile(
    title: "Default Text Encoding Name",
    subtitle:
        "Sets the default text encoding name to use when decoding html pages.",
    width: MediaQuery.of(ctx.context).size.width / 3,
    initialValue: ctx.readOrNull<String>((s) => s.defaultTextEncodingName),
    onSubmitted: (value) => ctx.apply((s) => s.defaultTextEncodingName = value),
  );
}
