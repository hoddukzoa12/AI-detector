import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection10(AndroidSettingsContext ctx) {
  return [
    const ListTile(
      title: Text("Scroll Bar Style"),
      subtitle: Text("Specify the style of the scrollbars."),
    ),
    _scrollBarStyle(ctx),
    const ListTile(
      title: Text("Vertical Scrollbar Position"),
      subtitle: Text("Set the position of the vertical scroll bar."),
    ),
    _verticalScrollbarPosition(ctx),
  ];
}

Widget _scrollBarStyle(AndroidSettingsContext ctx) {
  return androidEnumDropdownRow<ScrollBarStyle>(
    hint: "Scroll Bar Style",
    values: ScrollBarStyle.values,
    value: ctx.readOrNull<ScrollBarStyle>((s) => s.scrollBarStyle),
    onChanged: (value) => ctx.apply((s) => s.scrollBarStyle = value),
  );
}

Widget _verticalScrollbarPosition(AndroidSettingsContext ctx) {
  return androidEnumDropdownRow<VerticalScrollbarPosition>(
    hint: "Vertical Scrollbar Position",
    values: VerticalScrollbarPosition.values,
    value: ctx.readOrNull<VerticalScrollbarPosition>(
        (s) => s.verticalScrollbarPosition),
    onChanged: (value) => ctx.apply((s) => s.verticalScrollbarPosition = value),
  );
}
