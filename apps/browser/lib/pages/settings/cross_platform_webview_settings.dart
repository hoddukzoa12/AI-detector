import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:provider/provider.dart';

import '../../models/window_model.dart';

export 'package:infocutter_app/pages/settings/cross_platform/advanced_settings_group.dart';

class CrossPlatformWebViewSettings extends StatefulWidget {
  const CrossPlatformWebViewSettings({super.key});

  @override
  State<CrossPlatformWebViewSettings> createState() =>
      _CrossPlatformWebViewSettingsState();
}

class _CrossPlatformWebViewSettingsState
    extends State<CrossPlatformWebViewSettings> {
  final TextEditingController _customUserAgentController =
      TextEditingController();

  @override
  void dispose() {
    _customUserAgentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowModel = Provider.of<WindowModel>(context);
    final currentWebViewModel = Provider.of<WebViewModel>(context);

    return Column(
      children: <Widget>[
        const ListTile(
          title: Text("Current WebView Settings"),
          enabled: false,
        ),
        ..._buildCoreTiles(currentWebViewModel, windowModel),
        _buildCustomUserAgentTile(currentWebViewModel, windowModel),
        ..._buildInteractionTiles(currentWebViewModel, windowModel),
        _buildMinimumFontSizeTile(currentWebViewModel, windowModel),
        ..._buildFileAccessTiles(currentWebViewModel, windowModel),
      ],
    );
  }

  List<Widget> _buildCoreTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      _switchTile(
        _SwitchTileConfig(
          title: "JavaScript Enabled",
          subtitle: "Sets whether the WebView should enable JavaScript.",
          value: currentWebViewModel.settings?.javaScriptEnabled ?? true,
          onChanged: (settings, value) => settings.javaScriptEnabled = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
      _switchTile(
        _SwitchTileConfig(
          title: "Cache Enabled",
          subtitle: "Sets whether the WebView should use browser caching.",
          value: currentWebViewModel.settings?.cacheEnabled ?? true,
          onChanged: (settings, value) => settings.cacheEnabled = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
    ];
  }

  List<Widget> _buildInteractionTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      ..._buildPlaybackTiles(currentWebViewModel, windowModel),
      ..._buildScrollTiles(currentWebViewModel, windowModel),
      ..._buildContextMenuTiles(currentWebViewModel, windowModel),
    ];
  }

  List<Widget> _buildPlaybackTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      _switchTile(
        _SwitchTileConfig(
          title: "Support Zoom",
          subtitle:
              "Sets whether the WebView should not support zooming using its on-screen zoom controls and gestures.",
          value: currentWebViewModel.settings?.supportZoom ?? true,
          onChanged: (settings, value) => settings.supportZoom = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
      _switchTile(
        _SwitchTileConfig(
          title: "Media Playback Requires User Gesture",
          subtitle:
              "Sets whether the WebView should prevent HTML5 audio or video from autoplaying.",
          value:
              currentWebViewModel.settings?.mediaPlaybackRequiresUserGesture ??
                  true,
          onChanged: (settings, value) =>
              settings.mediaPlaybackRequiresUserGesture = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
    ];
  }

  List<Widget> _buildScrollTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      ..._buildScrollbarVisibilityTiles(currentWebViewModel, windowModel),
      ..._buildScrollDisableTiles(currentWebViewModel, windowModel),
    ];
  }

  List<Widget> _buildScrollbarVisibilityTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      _switchTile(
        _SwitchTileConfig(
          title: "Vertical ScrollBar Enabled",
          subtitle:
              "Sets whether the vertical scrollbar should be drawn or not.",
          value: currentWebViewModel.settings?.verticalScrollBarEnabled ?? true,
          onChanged: (settings, value) =>
              settings.verticalScrollBarEnabled = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
      _switchTile(
        _SwitchTileConfig(
          title: "Horizontal ScrollBar Enabled",
          subtitle:
              "Sets whether the horizontal scrollbar should be drawn or not.",
          value:
              currentWebViewModel.settings?.horizontalScrollBarEnabled ?? true,
          onChanged: (settings, value) =>
              settings.horizontalScrollBarEnabled = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
    ];
  }

  List<Widget> _buildScrollDisableTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      _switchTile(
        _SwitchTileConfig(
          title: "Disable Vertical Scroll",
          subtitle: "Sets whether vertical scroll should be enabled or not.",
          value: currentWebViewModel.settings?.disableVerticalScroll ?? false,
          onChanged: (settings, value) =>
              settings.disableVerticalScroll = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
      _switchTile(
        _SwitchTileConfig(
          title: "Disable Horizontal Scroll",
          subtitle: "Sets whether horizontal scroll should be enabled or not.",
          value: currentWebViewModel.settings?.disableHorizontalScroll ?? false,
          onChanged: (settings, value) =>
              settings.disableHorizontalScroll = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
    ];
  }

  List<Widget> _buildContextMenuTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      _switchTile(
        _SwitchTileConfig(
          title: "Disable Context Menu",
          subtitle: "Sets whether context menu should be enabled or not.",
          value: currentWebViewModel.settings?.disableContextMenu ?? false,
          onChanged: (settings, value) => settings.disableContextMenu = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
    ];
  }

  List<Widget> _buildFileAccessTiles(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return [
      _switchTile(
        _SwitchTileConfig(
          title: "Allow File Access From File URLs",
          subtitle:
              "Sets whether JavaScript running in the context of a file scheme URL should be allowed to access content from other file scheme URLs.",
          value: currentWebViewModel.settings?.allowFileAccessFromFileURLs ??
              false,
          onChanged: (settings, value) =>
              settings.allowFileAccessFromFileURLs = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
      _switchTile(
        _SwitchTileConfig(
          title: "Allow Universal Access From File URLs",
          subtitle:
              "Sets whether JavaScript running in the context of a file scheme URL should be allowed to access content from any origin.",
          value:
              currentWebViewModel.settings?.allowUniversalAccessFromFileURLs ??
                  false,
          onChanged: (settings, value) =>
              settings.allowUniversalAccessFromFileURLs = value,
        ),
        currentWebViewModel,
        windowModel,
      ),
    ];
  }

  Widget _switchTile(
    _SwitchTileConfig config,
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return SwitchListTile(
      title: Text(config.title),
      subtitle: Text(config.subtitle),
      value: config.value,
      onChanged: (value) async {
        config.onChanged(_settingsFor(currentWebViewModel), value);
        await _applySettings(currentWebViewModel, windowModel);
      },
    );
  }

  Widget _buildCustomUserAgentTile(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return ListTile(
      title: const Text("Custom User Agent"),
      subtitle: Text(
          currentWebViewModel.settings?.userAgent?.isNotEmpty ?? false
              ? currentWebViewModel.settings!.userAgent!
              : "Set a custom user agent ..."),
      onTap: () {
        _customUserAgentController.text =
            currentWebViewModel.settings?.userAgent ?? "";
        showDialog(
          context: context,
          builder: (dialogContext) => _buildCustomUserAgentDialog(
            dialogContext,
            currentWebViewModel,
            windowModel,
          ),
        );
      },
    );
  }

  Widget _buildCustomUserAgentDialog(
    BuildContext dialogContext,
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(0.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: _buildCustomUserAgentField(
                    dialogContext,
                    currentWebViewModel,
                    windowModel,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCustomUserAgentField(
    BuildContext dialogContext,
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return TextField(
      onSubmitted: (value) async {
        _settingsFor(currentWebViewModel).userAgent = value;
        await _applySettings(currentWebViewModel, windowModel);
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }
      },
      decoration: const InputDecoration(
        hintText: 'Custom User Agent',
      ),
      controller: _customUserAgentController,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.go,
      maxLines: null,
    );
  }

  Widget _buildMinimumFontSizeTile(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) {
    return ListTile(
      title: const Text("Minimum Font Size"),
      subtitle: const Text("Sets the minimum font size."),
      trailing: SizedBox(
        width: 50.0,
        child: TextFormField(
          initialValue:
              currentWebViewModel.settings?.minimumFontSize.toString(),
          keyboardType: const TextInputType.numberWithOptions(),
          onFieldSubmitted: (value) async {
            _settingsFor(currentWebViewModel).minimumFontSize =
                int.parse(value);
            await _applySettings(currentWebViewModel, windowModel);
          },
        ),
      ),
    );
  }

  InAppWebViewSettings _settingsFor(WebViewModel currentWebViewModel) {
    currentWebViewModel.settings ??= InAppWebViewSettings();
    return currentWebViewModel.settings!;
  }

  Future<void> _applySettings(
    WebViewModel currentWebViewModel,
    WindowModel windowModel,
  ) async {
    final webViewController = currentWebViewModel.webViewController;
    currentWebViewModel.settings = _settingsFor(currentWebViewModel);
    await webViewController?.setSettings(
        settings: currentWebViewModel.settings!);
    currentWebViewModel.settings = await webViewController?.getSettings();
    windowModel.saveInfo();
    if (mounted) {
      setState(() {});
    }
  }
}

class _SwitchTileConfig {
  const _SwitchTileConfig({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final void Function(InAppWebViewSettings settings, bool value) onChanged;
}
