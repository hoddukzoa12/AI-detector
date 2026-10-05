import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'ios_settings_context.dart';

List<Widget> buildIOSSettingsSection4(IOSSettingsContext ctx) {
  return [
    _decelerationRateTile(ctx),
    _alwaysBounceVerticalTile(ctx),
    _alwaysBounceHorizontalTile(ctx),
    _scrollsToTopTile(ctx),
    _isPagingEnabledTile(ctx),
  ];
}

Widget _decelerationRateTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Deceleration Rate"),
    subtitle: const Text(
        "Determines the rate of deceleration after the user lifts their finger."),
    trailing: DropdownButton<ScrollViewDecelerationRate>(
      hint: const Text("Deceleration"),
      onChanged: (value) =>
          ctx.apply((settings) => settings.decelerationRate = value!),
      value: ctx.settings?.decelerationRate,
      items: ScrollViewDecelerationRate.values.map(iosDropdownItem).toList(),
    ),
  );
}

Widget _alwaysBounceVerticalTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Always Bounce Vertical",
    subtitle:
        "Determines whether bouncing always occurs when vertical scrolling reaches the end of the content.",
    value: ctx.settings?.alwaysBounceVertical ?? false,
    write: (settings, value) => settings.alwaysBounceVertical = value,
  );
}

Widget _alwaysBounceHorizontalTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Always Bounce Horizontal",
    subtitle:
        "Determines whether bouncing always occurs when horizontal scrolling reaches the end of the content view.",
    value: ctx.settings?.alwaysBounceHorizontal ?? false,
    write: (settings, value) => settings.alwaysBounceHorizontal = value,
  );
}

Widget _scrollsToTopTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Scrolls To Top",
    subtitle: "Sets whether the scroll-to-top gesture is enabled.",
    value: ctx.settings?.scrollsToTop ?? true,
    write: (settings, value) => settings.scrollsToTop = value,
  );
}

Widget _isPagingEnabledTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Is Paging Enabled",
    subtitle: "Determines whether paging is enabled for the scroll view.",
    value: ctx.settings?.isPagingEnabled ?? false,
    write: (settings, value) => settings.isPagingEnabled = value,
  );
}
