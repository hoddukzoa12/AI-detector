import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/util.dart';
import 'package:provider/provider.dart';

class WebViewTabNavigationControls extends StatelessWidget {
  final VoidCallback onOpenNewTab;

  const WebViewTabNavigationControls({
    required this.onOpenNewTab,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final browserModel = Provider.of<BrowserModel>(context);
    final settings = browserModel.getSettings();
    final webViewModel = Provider.of<WebViewModel>(context);
    final l10n = AppLocalizations.of(context);
    final children = _buildNavigationButtons(settings, webViewModel, l10n);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: children,
      ),
    );
  }

  List<Widget> _buildNavigationButtons(
    BrowserSettings settings,
    WebViewModel webViewModel,
    AppLocalizations l10n,
  ) {
    final children = <Widget>[];
    if (Util.isDesktop()) {
      children.addAll(_buildDesktopNavigationButtons(webViewModel, l10n));
    }
    if (settings.homePageEnabled || Util.isDesktop()) {
      children.add(_buildHomeButton(settings, webViewModel, l10n));
    }
    return children;
  }

  List<Widget> _buildDesktopNavigationButtons(
    WebViewModel webViewModel,
    AppLocalizations l10n,
  ) =>
      [
        _NavigationButton(
          icon: Icons.arrow_back,
          tooltip: l10n.a11yBack,
          onPressed: () {
            webViewModel.webViewController?.goBack();
          },
        ),
        _NavigationButton(
          icon: Icons.arrow_forward,
          tooltip: l10n.a11yForward,
          onPressed: () {
            webViewModel.webViewController?.goForward();
          },
        ),
        _NavigationButton(
          icon: Icons.refresh,
          tooltip: l10n.a11yReload,
          onPressed: () {
            webViewModel.webViewController?.reload();
          },
        ),
      ];

  Widget _buildHomeButton(
    BrowserSettings settings,
    WebViewModel webViewModel,
    AppLocalizations l10n,
  ) =>
      _NavigationButton(
        icon: Icons.home,
        tooltip: l10n.homePage,
        onPressed: () {
          final controller = webViewModel.webViewController;
          if (controller != null) {
            final url = WebUri(settings.startPageUrl);
            controller.loadUrl(urlRequest: URLRequest(url: url));
          } else {
            onOpenNewTab();
          }
        },
      );
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: 20,
      ),
      constraints: const BoxConstraints(
        maxWidth: 30,
        minWidth: 30,
        maxHeight: 30,
        minHeight: 30,
      ),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
