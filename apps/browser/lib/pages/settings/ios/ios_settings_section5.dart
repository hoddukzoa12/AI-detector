import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'ios_settings_context.dart';

List<Widget> buildIOSSettingsSection5(IOSSettingsContext ctx) {
  return [
    _maximumZoomScaleTile(ctx),
    _minimumZoomScaleTile(ctx),
    _contentInsetAdjustmentBehaviorTile(ctx),
    _isDirectionalLockEnabledTile(ctx),
  ];
}

Widget _maximumZoomScaleTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Maximum Zoom Scale"),
    subtitle: const Text(
        "A floating-point value that specifies the maximum scale factor that can be applied to the scroll view's content."),
    trailing: SizedBox(
      width: 50.0,
      child: TextFormField(
        initialValue: ctx.settings?.maximumZoomScale.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onFieldSubmitted: (value) => ctx.apply(
            (settings) => settings.maximumZoomScale = double.parse(value)),
      ),
    ),
  );
}

Widget _minimumZoomScaleTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Minimum Zoom Scale"),
    subtitle: const Text(
        "A floating-point value that specifies the minimum scale factor that can be applied to the scroll view's content."),
    trailing: SizedBox(
      width: 50.0,
      child: TextFormField(
        initialValue: ctx.settings?.minimumZoomScale.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onFieldSubmitted: (value) => ctx.apply(
            (settings) => settings.minimumZoomScale = double.parse(value)),
      ),
    ),
  );
}

Widget _contentInsetAdjustmentBehaviorTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Content Inset Adjustment Behavior"),
    subtitle: const Text(
        "Configures how safe area insets are added to the adjusted content inset."),
    trailing: DropdownButton<ScrollViewContentInsetAdjustmentBehavior>(
      onChanged: (value) => ctx.apply(
          (settings) => settings.contentInsetAdjustmentBehavior = value!),
      value: ctx.settings?.contentInsetAdjustmentBehavior,
      items: ScrollViewContentInsetAdjustmentBehavior.values
          .map(iosDropdownItem)
          .toList(),
    ),
  );
}

Widget _isDirectionalLockEnabledTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Is Directional Lock Enabled",
    subtitle:
        "A Boolean value that determines whether scrolling is disabled in a particular direction.",
    value: ctx.settings?.isDirectionalLockEnabled ?? false,
    write: (settings, value) => settings.isDirectionalLockEnabled = value,
  );
}
