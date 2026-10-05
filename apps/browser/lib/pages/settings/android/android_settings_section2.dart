import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection2(AndroidSettingsContext ctx) {
  return [
    _domStorageEnabled(ctx),
    _useWideViewPort(ctx),
    const ListTile(
      title: Text("Mixed Content Mode"),
      subtitle: Text(
          "Configures the WebView's behavior when a secure origin attempts to load a resource from an insecure origin."),
    ),
    _mixedContentMode(ctx),
    _allowContentAccess(ctx),
    _allowFileAccess(ctx),
  ];
}

Widget _domStorageEnabled(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("DOM storage API"),
    subtitle: const Text("Sets whether the DOM storage API should be enabled."),
    value: ctx.read<bool>((s) => s.domStorageEnabled, true),
    // 이 항목만 원본에서 setState 안에서 동기로 처리하고 getSettings 를 다시
    // 읽지 않는다. 동작 보존을 위해 그대로 둔다.
    onChanged: (value) {
      ctx.setStateWith(() {
        ctx.webViewModel.settings?.domStorageEnabled = value;
        ctx.webViewController?.setSettings(
            settings: ctx.webViewModel.settings ?? InAppWebViewSettings());
        ctx.saveInfo();
      });
    },
  );
}

Widget _useWideViewPort(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Use Wide View Port"),
    subtitle: const Text(
        "Sets whether the WebView should enable support for the \"viewport\" HTML meta tag or should use a wide viewport."),
    value: ctx.read<bool>((s) => s.useWideViewPort, true),
    onChanged: (value) => ctx.apply((s) => s.useWideViewPort = value),
  );
}

Widget _mixedContentMode(AndroidSettingsContext ctx) {
  return androidEnumDropdownRow<MixedContentMode>(
    hint: "Mixed Content Mode",
    values: MixedContentMode.values,
    value: ctx.readOrNull<MixedContentMode>((s) => s.mixedContentMode),
    onChanged: (value) => ctx.apply((s) => s.mixedContentMode = value),
  );
}

Widget _allowContentAccess(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Allow Content Access"),
    subtitle: const Text(
        "Enables or disables content URL access within WebView. Content URL access allows WebView to load content from a content provider installed in the system."),
    value: ctx.read<bool>((s) => s.allowContentAccess, true),
    onChanged: (value) => ctx.apply((s) => s.allowContentAccess = value),
  );
}

Widget _allowFileAccess(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Allow File Access"),
    subtitle: const Text(
        "Enables or disables file access within WebView. Note that this enables or disables file system access only."),
    value: ctx.read<bool>((s) => s.allowFileAccess, true),
    onChanged: (value) => ctx.apply((s) => s.allowFileAccess = value),
  );
}
