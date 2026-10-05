import 'package:flutter/material.dart';

import 'ios_settings_context.dart';

List<Widget> buildIOSSettingsSection6(IOSSettingsContext ctx) {
  return [
    _mediaTypeTile(ctx),
    _pageZoomTile(ctx),
    _applePayAPIEnabledTile(ctx),
  ];
}

Widget _mediaTypeTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Media Type"),
    subtitle: const Text("The media type for the contents of the web view."),
    trailing: SizedBox(
      width: 100.0,
      child: TextFormField(
        initialValue: ctx.settings?.mediaType?.toString(),
        onFieldSubmitted: (value) => ctx.apply(
            (settings) => settings.mediaType = value.isNotEmpty ? value : null),
      ),
    ),
  );
}

Widget _pageZoomTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Page Zoom"),
    subtitle: const Text(
        "The scale factor by which the web view scales content relative to its bounds."),
    trailing: SizedBox(
      width: 50.0,
      child: TextFormField(
        initialValue: ctx.settings?.pageZoom.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onFieldSubmitted: (value) =>
            ctx.apply((settings) => settings.pageZoom = double.parse(value)),
      ),
    ),
  );
}

Widget _applePayAPIEnabledTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Apple Pay API Enabled",
    subtitle:
        "Indicates if Apple Pay API should be enabled on the next page load (JavaScript won't work).",
    value: ctx.settings?.applePayAPIEnabled ?? false,
    write: (settings, value) => settings.applePayAPIEnabled = value,
  );
}
