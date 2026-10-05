import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../custom_image.dart';
import '../models/webview_model.dart';
import '../models/window_model.dart';
import 'desktop_window_buttons.dart';

class DesktopTabStrip extends StatelessWidget {
  const DesktopTabStrip({
    required this.showTabs,
    required this.onAddNewTab,
    super.key,
  });

  final bool showTabs;
  final VoidCallback onAddNewTab;

  @override
  Widget build(BuildContext context) {
    final windowModel = Provider.of<WindowModel>(context);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 100,
      ),
      child: IntrinsicWidth(
        child: Row(
          children: [
            const DesktopWindowButtons(),
            Flexible(
              child: Container(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _tabSelectors(context, windowModel),
                ),
              ),
            ),
            const SizedBox(width: 5),
            if (showTabs)
              IconButton(
                tooltip: AppLocalizations.of(context).newTab,
                onPressed: onAddNewTab,
                constraints: const BoxConstraints(
                  maxWidth: 25,
                  minWidth: 25,
                  maxHeight: 25,
                  minHeight: 25,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.add,
                  size: 15,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tabSelectors(BuildContext context, WindowModel windowModel) {
    if (!showTabs) {
      return [const SizedBox(height: 30)];
    }

    return windowModel.webViewModels.map((webViewModel) {
      final index = windowModel.webViewModels.indexOf(webViewModel);
      final currentIndex = windowModel.getCurrentTabIndex();

      return Flexible(
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: WebViewTabSelector(
                  webViewModel: webViewModel,
                  index: index,
                ),
              ),
              SizedBox(
                height: 15,
                child: VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: index == currentIndex - 1 || index == currentIndex
                      ? Colors.transparent
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class WebViewTabSelector extends StatelessWidget {
  final WebViewModel webViewModel;
  final int index;

  const WebViewTabSelector({
    required this.webViewModel,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final windowModel = Provider.of<WindowModel>(context);
    final isCurrentTab = windowModel.getCurrentTabIndex() == index;
    final url = webViewModel.url;
    var tabName = webViewModel.title ?? url?.toString() ?? '';
    if (tabName.isEmpty) {
      tabName = 'New Tab';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        windowModel.showTab(index);
      },
      child: ContextMenuRegion(
        contextMenu: _buildContextMenu(webViewModel, windowModel),
        child: _TabSelectorBody(
          faviconUrl: _faviconUrl(webViewModel),
          isCurrentTab: isCurrentTab,
          tabName: tabName,
          tooltipText: _tooltipText(tabName, url),
          onClose: () {
            windowModel.closeTab(index);
          },
        ),
      ),
    );
  }

  GenericContextMenu _buildContextMenu(
    WebViewModel webViewModel,
    WindowModel windowModel,
  ) {
    return GenericContextMenu(
      buttonConfigs: [
        ContextMenuButtonConfig(
          "Reload",
          onPressed: () {
            webViewModel.webViewController?.reload();
          },
        ),
        ContextMenuButtonConfig(
          "Duplicate",
          onPressed: () {
            if (webViewModel.url != null) {
              windowModel.addTab(WebViewModel(url: webViewModel.url));
            }
          },
        ),
        ContextMenuButtonConfig(
          "Close",
          onPressed: () {
            windowModel.closeTab(index);
          },
        ),
      ],
    );
  }

  String _tooltipText(String tabName, Uri? url) {
    return '$tabName\n${(url?.host ?? '').isEmpty ? url?.toString() : url?.host}'
        .trim();
  }

  Uri? _faviconUrl(WebViewModel webViewModel) {
    final url = webViewModel.url;
    if (webViewModel.favicon != null) {
      return webViewModel.favicon!.url;
    }
    if (url != null && ["http", "https"].contains(url.scheme)) {
      return Uri.parse("${url.origin}/favicon.ico");
    }
    return null;
  }
}

class _TabSelectorBody extends StatelessWidget {
  const _TabSelectorBody({
    required this.faviconUrl,
    required this.isCurrentTab,
    required this.onClose,
    required this.tabName,
    required this.tooltipText,
  });

  final Uri? faviconUrl;
  final bool isCurrentTab;
  final VoidCallback onClose;
  final String tabName;
  final String tooltipText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.only(right: 5.0),
      decoration: !isCurrentTab
          ? null
          : BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
      child: Tooltip(
        decoration: _tooltipDecoration,
        richMessage: _buildTooltipMessage(),
        waitDuration: const Duration(milliseconds: 500),
        child: _buildContent(context),
      ),
    );
  }

  BoxDecoration get _tooltipDecoration {
    return const BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.all(Radius.circular(5)),
    );
  }

  WidgetSpan _buildTooltipMessage() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Text(
          tooltipText,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _buildTabLabel(context)),
        _buildCloseButton(context),
      ],
    );
  }

  Widget _buildTabLabel(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          child: CustomImage(
            url: faviconUrl,
            maxWidth: 20.0,
            height: 20.0,
          ),
        ),
        Flexible(
          child: Text(
            tabName,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              color: !isCurrentTab
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).closeTabs,
      onPressed: onClose,
      constraints: const BoxConstraints(
        maxWidth: 20,
        minWidth: 20,
        maxHeight: 20,
        minHeight: 20,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.cancel,
        color: !isCurrentTab
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.primary,
        size: 15,
      ),
    );
  }
}
