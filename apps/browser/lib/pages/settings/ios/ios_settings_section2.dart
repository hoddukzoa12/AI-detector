import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'ios_settings_context.dart';

List<Widget> buildIOSSettingsSection2(IOSSettingsContext ctx) {
  return [
    _allowsInlineMediaPlaybackTile(ctx),
    _allowsPictureInPictureMediaPlaybackTile(ctx),
    _selectionGranularityTile(ctx),
  ];
}

Widget _allowsInlineMediaPlaybackTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Allows Inline Media Playback",
    subtitle:
        "Enable to allow HTML5 media playback to appear inline within the screen layout, using browser-supplied controls rather than native controls.",
    value: ctx.settings?.allowsInlineMediaPlayback ?? false,
    write: (settings, value) => settings.allowsInlineMediaPlayback = value,
  );
}

Widget _allowsPictureInPictureMediaPlaybackTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Allows Picture In Picture Media Playback",
    subtitle: "Enable to allow HTML5 videos play picture-in-picture.",
    value: ctx.settings?.allowsPictureInPictureMediaPlayback ?? true,
    write: (settings, value) =>
        settings.allowsPictureInPictureMediaPlayback = value,
  );
}

Widget _selectionGranularityTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Selection Granularity"),
    subtitle: const Text(
        "Sets the level of granularity with which the user can interactively select content in the web view."),
    trailing: DropdownButton<SelectionGranularity>(
      hint: const Text("Granularity"),
      onChanged: (value) =>
          ctx.apply((settings) => settings.selectionGranularity = value!),
      value: ctx.settings?.selectionGranularity,
      items: SelectionGranularity.values.map(iosDropdownItem).toList(),
    ),
  );
}
