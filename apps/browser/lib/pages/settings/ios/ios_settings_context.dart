import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/webview_model.dart';

import '../../../models/window_model.dart';

/// Shared state handed to every iOS settings section builder.
///
/// Bundles the models, the controller and the host [BuildContext] that each
/// setting tile needs, together with the "write a setting then push it to the
/// WebView" sequence that every tile repeated inline.
class IOSSettingsContext {
  const IOSSettingsContext({
    required this.windowModel,
    required this.webViewModel,
    required this.webViewController,
    required this.buildContext,
    required this.refresh,
  });

  final WindowModel windowModel;
  final WebViewModel webViewModel;
  final InAppWebViewController? webViewController;
  final BuildContext buildContext;
  final VoidCallback refresh;

  InAppWebViewSettings? get settings => webViewModel.settings;

  /// Pushes the current settings to the WebView, persists and rebuilds.
  void commit() {
    webViewController?.setSettings(
        settings: webViewModel.settings ?? InAppWebViewSettings());
    windowModel.saveInfo();
    refresh();
  }

  /// Applies [change] to the current settings (a no-op when they are null,
  /// matching the `settings?.field = value` form) and then commits.
  void apply(void Function(InAppWebViewSettings settings) change) {
    final current = webViewModel.settings;
    if (current != null) {
      change(current);
    }
    commit();
  }
}

/// A [SwitchListTile] bound to a boolean WebView setting.
Widget iosSwitchTile(
  IOSSettingsContext ctx, {
  required String title,
  required String subtitle,
  required bool value,
  required void Function(InAppWebViewSettings settings, bool value) write,
}) {
  return SwitchListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: (newValue) => ctx.apply((settings) => write(settings, newValue)),
  );
}

/// A [DropdownButton] entry rendered with the shared compact text style.
DropdownMenuItem<T> iosDropdownItem<T>(T value) {
  return DropdownMenuItem<T>(
    value: value,
    child: Text(
      value.toString(),
      style: const TextStyle(fontSize: 12.5),
    ),
  );
}
