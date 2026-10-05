import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_settings_context.dart';
import 'android_settings_widgets.dart';

List<Widget> buildAndroidSettingsSection3(AndroidSettingsContext ctx) {
  return [
    const ListTile(
      title: Text("App Cache Path"),
      subtitle: Text(
          "Sets the path to the Application Caches files. In order for the Application Caches API to be enabled, this option must be set a path to which the application can write."),
    ),
    _appCachePath(ctx),
    _blockNetworkImage(ctx),
    _blockNetworkLoads(ctx),
    const ListTile(
      title: Text("Cache Mode"),
      subtitle: Text(
          "Overrides the way the cache is used. The way the cache is used is based on the navigation type."),
    ),
    _cacheMode(ctx),
  ];
}

Widget _appCachePath(AndroidSettingsContext ctx) {
  return Container(
    padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
    alignment: Alignment.center,
    child: TextFormField(
      initialValue: ctx.readOrNull<String>((s) => s.appCachePath),
      keyboardType: TextInputType.text,
      onFieldSubmitted: (value) =>
          ctx.apply((s) => s.appCachePath = value.trim()),
    ),
  );
}

Widget _blockNetworkImage(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Block Network Image"),
    subtitle: const Text(
        "Sets whether the WebView should not load image resources from the network (resources accessed via http and https URI schemes)."),
    value: ctx.read<bool>((s) => s.blockNetworkImage, false),
    onChanged: (value) => ctx.apply((s) => s.blockNetworkImage = value),
  );
}

Widget _blockNetworkLoads(AndroidSettingsContext ctx) {
  return SwitchListTile(
    title: const Text("Block Network Loads"),
    subtitle: const Text(
        "Sets whether the WebView should not load resources from the network."),
    value: ctx.read<bool>((s) => s.blockNetworkLoads, false),
    onChanged: (value) => ctx.apply((s) => s.blockNetworkLoads = value),
  );
}

Widget _cacheMode(AndroidSettingsContext ctx) {
  return androidEnumDropdownRow<CacheMode>(
    hint: "Cache Mode",
    values: CacheMode.values,
    value: ctx.readOrNull<CacheMode>((s) => s.cacheMode),
    onChanged: (value) => ctx.apply((s) => s.cacheMode = value),
  );
}
