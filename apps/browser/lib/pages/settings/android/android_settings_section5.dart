import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection5(AndroidSettingsContext ctx) {
  return [
    const ListTile(
      title: Text("Disabled Action Mode Menu Items"),
      subtitle: Text(
          "Disables the action mode menu items according to menuItems flag."),
    ),
    _disabledActionModeMenuItems(ctx),
    _fantasyFontFamily(ctx),
    _fixedFontFamily(ctx),
  ];
}

Widget _disabledActionModeMenuItems(AndroidSettingsContext ctx) {
  return androidEnumDropdownRow<ActionModeMenuItem>(
    hint: "Action Mode Menu Items",
    values: ActionModeMenuItem.values,
    value: ctx
        .readOrNull<ActionModeMenuItem>((s) => s.disabledActionModeMenuItems),
    onChanged: (value) =>
        ctx.apply((s) => s.disabledActionModeMenuItems = value),
  );
}

Widget _fantasyFontFamily(AndroidSettingsContext ctx) {
  return androidTextTile(
    title: "Fantasy Font Family",
    subtitle: "Sets the fantasy font family name.",
    width: MediaQuery.of(ctx.context).size.width / 3,
    initialValue: ctx.readOrNull<String>((s) => s.fantasyFontFamily),
    onSubmitted: (value) => ctx.apply((s) => s.fantasyFontFamily = value),
  );
}

Widget _fixedFontFamily(AndroidSettingsContext ctx) {
  return androidTextTile(
    title: "Fixed Font Family",
    subtitle: "Sets the fixed font family name.",
    width: MediaQuery.of(ctx.context).size.width / 3,
    initialValue: ctx.readOrNull<String>((s) => s.fixedFontFamily),
    onSubmitted: (value) => ctx.apply((s) => s.fixedFontFamily = value),
  );
}
