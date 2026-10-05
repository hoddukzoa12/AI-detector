import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../models/window_model.dart';
import '../../../util.dart';
import 'cross_platform_settings_context.dart';
import 'cross_platform_settings_widgets.dart';

List<Widget> buildCrossPlatformSettingsSection3(
  CrossPlatformSettingsContext ctx,
  CrossPlatformSettingsLoaders loaders,
) {
  return [
    _defaultUserAgentTile(ctx, loaders),
    _debuggingSwitch(ctx),
    _flutterPackageInfoTile(),
  ];
}

Widget _defaultUserAgentTile(
  CrossPlatformSettingsContext ctx,
  CrossPlatformSettingsLoaders loaders,
) {
  return FutureBuilder(
    future: (loaders.defaultUserAgentLoader ??
            InAppWebViewController.getDefaultUserAgent)
        .call(),
    builder: (context, snapshot) {
      final defaultUserAgent = snapshot.hasData ? snapshot.data as String : "";
      return copyableInfoTile(
        title: ctx.l10n.defaultUserAgent,
        value: defaultUserAgent,
      );
    },
  );
}

Widget _debuggingSwitch(CrossPlatformSettingsContext ctx) => SwitchListTile(
      title: Text(ctx.l10n.debuggingEnabled),
      subtitle: Text(ctx.l10n.debuggingEnabledDescription),
      value: ctx.settings.debuggingEnabled,
      onChanged: (value) => _setDebuggingEnabled(ctx, value),
    );

Widget _flutterPackageInfoTile() => FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        return copyableInfoTile(
          title: "Infocutter Package Info",
          value: _packageDescription(snapshot.data),
        );
      },
    );

String _packageDescription(Object? data) {
  if (data is! PackageInfo) return "";
  return "Package Name: ${data.packageName}\n"
      "Version: ${data.version}\n"
      "Build Number: ${data.buildNumber}";
}

void _setDebuggingEnabled(CrossPlatformSettingsContext ctx, bool value) {
  ctx.setStateWith(() {
    ctx.settings.debuggingEnabled = value;
    ctx.updateSettings();
    if (ctx.windowModel.webViewModels.isNotEmpty) {
      _applyDebuggingToCurrentWebView(ctx);
    }
  });
}

void _applyDebuggingToCurrentWebView(CrossPlatformSettingsContext ctx) {
  final webViewModel = ctx.windowModel.getCurrentWebViewModel();
  if (Util.isAndroid()) {
    InAppWebViewController.setWebContentsDebuggingEnabled(
      ctx.settings.debuggingEnabled,
    );
  }
  webViewModel?.settings?.isInspectable = ctx.settings.debuggingEnabled;
  webViewModel?.webViewController?.setSettings(
    settings: webViewModel.settings ?? InAppWebViewSettings(),
  );
  ctx.windowModel.saveInfo();
}
