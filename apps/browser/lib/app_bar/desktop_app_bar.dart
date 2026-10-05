import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../models/browser_model.dart';
import '../models/webview_model.dart';
import '../models/window_model.dart';
import 'desktop_drag_region.dart';
import 'desktop_open_tabs_viewer.dart';
import 'desktop_tab_strip.dart';

class DesktopAppBar extends StatefulWidget {
  final bool showTabs;

  const DesktopAppBar({super.key, this.showTabs = true});

  @override
  State<DesktopAppBar> createState() => _DesktopAppBarState();
}

class _DesktopAppBarState extends State<DesktopAppBar> {
  @override
  Widget build(BuildContext context) {
    final windowModel = Provider.of<WindowModel>(context);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopTabStrip(
            showTabs: widget.showTabs,
            onAddNewTab: _addNewTab,
          ),
          DesktopDragRegion(
            showTabs: widget.showTabs,
            onAddNewTab: _addNewTab,
          ),
          if (widget.showTabs)
            DesktopOpenTabsViewer(webViewModels: windowModel.webViewModels),
        ],
      ),
    );
  }

  void _addNewTab() {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final settings = browserModel.getSettings();
    windowModel.addTab(WebViewModel(url: WebUri(settings.startPageUrl)));
  }
}
