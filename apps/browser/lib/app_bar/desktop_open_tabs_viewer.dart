import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../custom_image.dart';
import '../models/webview_model.dart';
import '../models/window_model.dart';

class DesktopOpenTabsViewer extends StatefulWidget {
  final List<WebViewModel> webViewModels;

  const DesktopOpenTabsViewer({required this.webViewModels, super.key});

  @override
  State<DesktopOpenTabsViewer> createState() => _DesktopOpenTabsViewerState();
}

class _DesktopOpenTabsViewerState extends State<DesktopOpenTabsViewer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      child: MenuAnchor(
        builder: (context, controller, child) {
          return IconButton(
            tooltip: AppLocalizations.of(context).a11yTabCount,
            onPressed: () {
              controller.isOpen ? controller.close() : controller.open();
            },
            constraints: const BoxConstraints(
              maxWidth: 25,
              minWidth: 25,
              maxHeight: 25,
              minHeight: 25,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: Colors.white,
            ),
          );
        },
        menuChildren: [
          _SearchTabsField(controller: _controller, onChanged: _refresh),
          MenuItemButton(
            child: Text(
              widget.webViewModels.isEmpty ? 'No tabs open' : 'Tabs open',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          ..._filteredTabs().map(_buildTabMenuItem),
        ],
      ),
    );
  }

  Iterable<WebViewModel> _filteredTabs() {
    final search = _controller.text.toLowerCase().trim();
    if (search.isEmpty) {
      return widget.webViewModels;
    }
    return widget.webViewModels.where((element) {
      final containsInTitle =
          element.title?.toLowerCase().contains(search) ?? false;
      final containsInUrl =
          element.url?.toString().toLowerCase().contains(search) ?? false;
      return containsInTitle || containsInUrl;
    });
  }

  MenuItemButton _buildTabMenuItem(WebViewModel webViewModel) {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final index = windowModel.webViewModels.indexOf(webViewModel);

    return MenuItemButton(
      onPressed: index < 0 ? null : () => windowModel.showTab(index),
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        child: CustomImage(
          url: _faviconUrl(webViewModel),
          maxWidth: 15,
          height: 15,
        ),
      ),
      trailingIcon: IconButton(
        tooltip: AppLocalizations.of(context).closeTabs,
        onPressed: index < 0 ? null : () => windowModel.closeTab(index),
        constraints: const BoxConstraints(
          maxWidth: 25,
          minWidth: 25,
          maxHeight: 25,
          minHeight: 25,
        ),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.cancel, size: 15),
      ),
      child: _OpenTabMenuLabel(webViewModel: webViewModel),
    );
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

  void _refresh(String value) {
    setState(() {});
  }
}

class _SearchTabsField extends StatelessWidget {
  const _SearchTabsField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: TextFormField(
        controller: controller,
        style: Theme.of(context).textTheme.labelLarge,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search open tabs',
          contentPadding: EdgeInsets.only(top: 15),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _OpenTabMenuLabel extends StatelessWidget {
  const _OpenTabMenuLabel({required this.webViewModel});

  final WebViewModel webViewModel;

  @override
  Widget build(BuildContext context) {
    final url = webViewModel.url;
    final title =
        (webViewModel.title ?? '').isNotEmpty ? webViewModel.title! : 'New Tab';
    final subtitle = (url?.host ?? '').isEmpty ? url?.toString() : url?.host;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  subtitle ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Text(
                " - ${_openedAgo(webViewModel.lastOpenedTime)}",
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _openedAgo(DateTime lastOpenedTime) {
    final diffTime = DateTime.now().difference(lastOpenedTime);
    if (diffTime.inDays > 0) {
      return '${diffTime.inDays} ${diffTime.inDays == 1 ? 'day' : 'days'} ago';
    }
    if (diffTime.inMinutes > 0) {
      return '${diffTime.inMinutes} min ago';
    }
    if (diffTime.inSeconds > 0) {
      return '${diffTime.inSeconds} sec ago';
    }
    return 'now';
  }
}
