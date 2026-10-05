import 'package:flutter/material.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection8(AndroidSettingsContext ctx) {
  return [
    _sansSerifFontFamily(ctx),
    _serifFontFamily(ctx),
    _standardFontFamily(ctx),
    _saveFormData(ctx),
  ];
}

Widget _sansSerifFontFamily(AndroidSettingsContext ctx) {
  return androidTextTile(
    title: "Sans-Serif Font Family",
    subtitle: "Sets the sans-serif font family name.",
    width: MediaQuery.of(ctx.context).size.width / 3,
    initialValue: ctx.readOrNull<String>((s) => s.sansSerifFontFamily),
    onSubmitted: (value) => ctx.apply((s) => s.sansSerifFontFamily = value),
  );
}

Widget _serifFontFamily(AndroidSettingsContext ctx) {
  return androidTextTile(
    title: "Serif Font Family",
    subtitle: "Sets the serif font family name.",
    width: MediaQuery.of(ctx.context).size.width / 3,
    initialValue: ctx.readOrNull<String>((s) => s.serifFontFamily),
    onSubmitted: (value) => ctx.apply((s) => s.serifFontFamily = value),
  );
}

Widget _standardFontFamily(AndroidSettingsContext ctx) {
  return androidTextTile(
    title: "Standard Font Family",
    subtitle: "Sets the standard font family name.",
    width: MediaQuery.of(ctx.context).size.width / 3,
    initialValue: ctx.readOrNull<String>((s) => s.standardFontFamily),
    onSubmitted: (value) => ctx.apply((s) => s.standardFontFamily = value),
  );
}

Widget _saveFormData(AndroidSettingsContext ctx) {
  // saveFormData is deprecated in flutter_inappwebview; platform Autofill
  // replaces it. Keep the toggle for older Android builds only.
  // ignore: deprecated_member_use
  final current = ctx.read<bool>((s) => s.saveFormData, true);
  return SwitchListTile(
    title: const Text("Save Form Data"),
    subtitle: const Text(
        "Sets whether the WebView should save form data. In Android O, the platform has implemented a fully functional Autofill feature to store form data."),
    value: current,
    onChanged: (value) => ctx.apply((s) {
      // ignore: deprecated_member_use
      s.saveFormData = value;
    }),
  );
}
