import 'package:flutter/material.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection11(AndroidSettingsContext ctx) {
  return [
    _scrollBarDefaultDelayBeforeFade(ctx),
    _scrollbarFadingEnabled(ctx),
    _scrollBarFadeDuration(ctx),
  ];
}

Widget _scrollBarDefaultDelayBeforeFade(AndroidSettingsContext ctx) {
  return androidNumberTile(
    title: "Scroll Bar Default Delay Before Fade",
    subtitle:
        "Defines the delay in milliseconds that a scrollbar waits before fade out.",
    initialValue: ctx
            .readOrNull<int>((s) => s.scrollBarDefaultDelayBeforeFade)
            ?.toString() ??
        "0",
    onSubmitted: (value) =>
        ctx.apply((s) => s.scrollBarDefaultDelayBeforeFade = int.parse(value)),
  );
}

Widget _scrollbarFadingEnabled(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Scrollbar Fading Enabled"),
    subtitle: const Text(
        "Define whether scrollbars will fade when the view is not scrolling."),
    value: ctx.read<bool>((s) => s.scrollbarFadingEnabled, true),
    onChanged: (value) => ctx.apply((s) => s.scrollbarFadingEnabled = value),
  );
}

Widget _scrollBarFadeDuration(AndroidSettingsContext ctx) {
  return androidNumberTile(
    title: "Scroll Bar Fade Duration",
    subtitle: "Define the scrollbar fade duration in milliseconds.",
    initialValue:
        ctx.readOrNull<int>((s) => s.scrollBarFadeDuration)?.toString() ?? "0",
    onSubmitted: (value) =>
        ctx.apply((s) => s.scrollBarFadeDuration = int.parse(value)),
  );
}
