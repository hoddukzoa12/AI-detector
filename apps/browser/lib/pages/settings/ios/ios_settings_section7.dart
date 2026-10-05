import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../models/window_model.dart';
import 'ios_settings_context.dart';

List<Widget> buildIOSSettingsSection7(IOSSettingsContext ctx) {
  return [
    _underPageBackgroundColorTile(ctx),
    _isTextInteractionEnabledTile(ctx),
    _isSiteSpecificQuirksModeEnabledTile(ctx),
    _upgradeKnownHostsToHTTPSTile(ctx),
  ];
}

Widget _underPageBackgroundColorTile(IOSSettingsContext ctx) {
  return ListTile(
    title: const Text("Under Page Background Color"),
    subtitle: const Text(
        "Sets the color the web view displays behind the active page, visible when the user scrolls beyond the bounds of the page."),
    trailing: SizedBox(
        width: 140.0,
        child: ElevatedButton(
          onPressed: () => _showUnderPageBackgroundColorPicker(ctx),
          child: Text(
            ctx.settings?.underPageBackgroundColor?.toString() ??
                'Pick a color!',
            style: const TextStyle(fontSize: 12.5),
          ),
        )),
  );
}

void _showUnderPageBackgroundColorPicker(IOSSettingsContext ctx) {
  showDialog(
    context: ctx.buildContext,
    builder: (context) {
      return AlertDialog(
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: const Color(0xffffffff),
            onColorChanged: (value) => _applyUnderPageBackgroundColor(
              ctx,
              value,
            ),
            pickerAreaHeightPercent: 0.8,
          ),
        ),
      );
    },
  );
}

Future<void> _applyUnderPageBackgroundColor(
  IOSSettingsContext ctx,
  Color value,
) async {
  ctx.settings?.underPageBackgroundColor = value;
  ctx.webViewController
      ?.setSettings(settings: ctx.settings ?? InAppWebViewSettings());
  ctx.webViewModel.settings = await ctx.webViewController?.getSettings();
  ctx.windowModel.saveInfo();
  ctx.refresh();
}

Widget _isTextInteractionEnabledTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Text Interaction Enabled",
    subtitle: "Indicates whether text interaction is enabled or not.",
    value: ctx.settings?.isTextInteractionEnabled ?? false,
    write: (settings, value) => settings.isTextInteractionEnabled = value,
  );
}

Widget _isSiteSpecificQuirksModeEnabledTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Site Specific Quirks Mode Enabled",
    subtitle:
        "Indicates whether WebKit will apply built-in workarounds (quirks) to improve compatibility with certain known websites. You can disable site-specific quirks to help test your website without these workarounds.",
    value: ctx.settings?.isSiteSpecificQuirksModeEnabled ?? false,
    write: (settings, value) =>
        settings.isSiteSpecificQuirksModeEnabled = value,
  );
}

Widget _upgradeKnownHostsToHTTPSTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Upgrade Known Hosts To HTTPS",
    subtitle:
        "Indicates whether HTTP requests to servers known to support HTTPS should be automatically upgraded to HTTPS requests.",
    value: ctx.settings?.upgradeKnownHostsToHTTPS ?? false,
    write: (settings, value) => settings.upgradeKnownHostsToHTTPS = value,
  );
}
