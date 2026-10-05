import 'package:flutter/material.dart';

import 'ios_settings_context.dart';

List<Widget> buildIOSSettingsSection1(IOSSettingsContext ctx) {
  return [
    const ListTile(
      title: Text("Current WebView iOS Settings"),
      enabled: false,
    ),
    _disallowOverScrollTile(ctx),
    _enableViewportScaleTile(ctx),
    _suppressesIncrementalRenderingTile(ctx),
    _allowsAirPlayForMediaPlaybackTile(ctx),
    _allowsBackForwardNavigationGesturesTile(ctx),
    _ignoresViewportScaleLimitsTile(ctx),
  ];
}

Widget _disallowOverScrollTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Disallow Over Scroll",
    subtitle:
        "Sets whether the WebView should bounce when the scrolling has reached an edge of the content",
    value: ctx.settings?.disallowOverScroll ?? false,
    write: (settings, value) => settings.disallowOverScroll = value,
  );
}

Widget _enableViewportScaleTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Enable Viewport Scale",
    subtitle:
        "Enable to allow a viewport meta tag to either disable or restrict the range of user scaling.",
    value: ctx.settings?.enableViewportScale ?? false,
    write: (settings, value) => settings.enableViewportScale = value,
  );
}

Widget _suppressesIncrementalRenderingTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Suppresses Incremental Rendering",
    subtitle:
        "Sets wheter the WebView should suppresses content rendering until it is fully loaded into memory.",
    value: ctx.settings?.suppressesIncrementalRendering ?? false,
    write: (settings, value) => settings.suppressesIncrementalRendering = value,
  );
}

Widget _allowsAirPlayForMediaPlaybackTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Allows Air Play For Media Playback",
    subtitle: "Enable AirPlay.",
    value: ctx.settings?.allowsAirPlayForMediaPlayback ?? true,
    write: (settings, value) => settings.allowsAirPlayForMediaPlayback = value,
  );
}

Widget _allowsBackForwardNavigationGesturesTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Allows Back Forward Navigation Gestures",
    subtitle:
        "Enable to allow the horizontal swipe gestures trigger back-forward list navigations.",
    value: ctx.settings?.allowsBackForwardNavigationGestures ?? true,
    write: (settings, value) =>
        settings.allowsBackForwardNavigationGestures = value,
  );
}

Widget _ignoresViewportScaleLimitsTile(IOSSettingsContext ctx) {
  return iosSwitchTile(
    ctx,
    title: "Ignores Viewport Scale Limits",
    subtitle:
        "Sets whether the WebView should always allow scaling of the webpage, regardless of the author's intent.",
    value: ctx.settings?.ignoresViewportScaleLimits ?? false,
    write: (settings, value) => settings.ignoresViewportScaleLimits = value,
  );
}
