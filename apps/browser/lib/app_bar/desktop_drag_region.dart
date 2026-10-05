import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/window_model.dart';
import '../services/window_service.dart';
import '../util.dart';

class DesktopDragRegion extends StatelessWidget {
  const DesktopDragRegion({
    required this.showTabs,
    required this.onAddNewTab,
    super.key,
  });

  final bool showTabs;
  final VoidCallback onAddNewTab;

  @override
  Widget build(BuildContext context) {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final windowControls = Provider.of<WindowControls>(
      context,
      listen: false,
    );

    return Flexible(
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.opaque,
        onEnter: (details) {
          if (!Util.isWindows()) {
            windowControls.setMovable(true);
          }
        },
        onExit: (details) {
          if (!Util.isWindows()) {
            windowControls.setMovable(false);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: windowControls.maximize,
          child: showTabs
              ? _ContextMenuDragArea(
                  onAddNewTab: onAddNewTab,
                  onCloseAllTabs: windowModel.closeAllTabs,
                )
              : const SizedBox(
                  height: 30,
                  width: double.infinity,
                ),
        ),
      ),
    );
  }
}

class _ContextMenuDragArea extends StatelessWidget {
  const _ContextMenuDragArea({
    required this.onAddNewTab,
    required this.onCloseAllTabs,
  });

  final VoidCallback onAddNewTab;
  final VoidCallback onCloseAllTabs;

  @override
  Widget build(BuildContext context) {
    return ContextMenuRegion(
      behavior: const [ContextMenuShowBehavior.secondaryTap],
      contextMenu: GenericContextMenu(
        buttonConfigs: [
          ContextMenuButtonConfig("New Tab", onPressed: onAddNewTab),
          ContextMenuButtonConfig("Close All", onPressed: onCloseAllTabs),
        ],
      ),
      child: const SizedBox(
        height: 30,
        width: double.infinity,
      ),
    );
  }
}
