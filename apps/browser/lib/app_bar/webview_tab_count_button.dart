import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/l10n/localized_menu_labels.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/tab_popup_menu_actions.dart';
import 'package:infocutter_app/theme/infocutter_tokens.g.dart';
import 'package:provider/provider.dart';

class WebViewTabCountButton extends StatefulWidget {
  final VoidCallback onAddNewTab;
  final VoidCallback onAddNewIncognitoTab;

  const WebViewTabCountButton({
    required this.onAddNewTab,
    required this.onAddNewIncognitoTab,
    super.key,
  });

  @override
  State<WebViewTabCountButton> createState() => _WebViewTabCountButtonState();
}

class _WebViewTabCountButtonState extends State<WebViewTabCountButton> {
  final GlobalKey _tabInkWellKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final browserModel = Provider.of<BrowserModel>(context);
    final windowModel = Provider.of<WindowModel>(context);
    final l10n = AppLocalizations.of(context);
    final tokens = InfocutterTokens(Theme.of(context).brightness);

    return Tooltip(
      message: l10n.a11yTabCount,
      child: InkWell(
        key: _tabInkWellKey,
        onLongPress: () {
          _showTabMenu(context, windowModel);
        },
        onTap: () async {
          await _openTabScroller(context, browserModel, windowModel);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: InfocutterTokens.spaceSm,
            vertical: 15.0,
          ),
          decoration: BoxDecoration(
            border: Border.all(width: 2.0, color: tokens.text),
            borderRadius: BorderRadius.circular(InfocutterTokens.radiusSm),
          ),
          constraints: const BoxConstraints(minWidth: 25.0),
          child: Center(
            child: Text(
              windowModel.webViewModels.length.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
                color: tokens.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTabMenu(BuildContext context, WindowModel windowModel) {
    final box = _tabInkWellKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final position = box.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + box.size.height,
        box.size.width,
        0,
      ),
      items: _buildTabMenuItems(l10n),
    ).then((value) {
      _handleTabMenuSelection(value, windowModel);
    });
  }

  Brightness get _brightness => Theme.of(context).brightness;

  List<PopupMenuItem<String>> _buildTabMenuItems(AppLocalizations l10n) =>
      TabPopupMenuActions.choices
          .map((action) => _buildTabMenuItem(action, l10n))
          .toList();

  PopupMenuItem<String> _buildTabMenuItem(
    String action,
    AppLocalizations l10n,
  ) {
    final iconData = switch (action) {
      TabPopupMenuActions.CLOSE_TABS => Icons.cancel,
      TabPopupMenuActions.NEW_TAB => Icons.add,
      TabPopupMenuActions.NEW_INCOGNITO_TAB => Icons.visibility_off,
      _ => null,
    };

    return PopupMenuItem<String>(
      value: action,
      child: Row(
        children: [
          Icon(iconData, color: InfocutterTokens(_brightness).text),
          Container(
            padding: const EdgeInsets.only(left: 10.0),
            child: Text(l10n.tabPopupMenuActionLabel(action)),
          ),
        ],
      ),
    );
  }

  void _handleTabMenuSelection(String? value, WindowModel windowModel) {
    switch (value) {
      case TabPopupMenuActions.CLOSE_TABS:
        windowModel.closeAllTabs();
        break;
      case TabPopupMenuActions.NEW_TAB:
        widget.onAddNewTab();
        break;
      case TabPopupMenuActions.NEW_INCOGNITO_TAB:
        widget.onAddNewIncognitoTab();
        break;
    }
  }

  Future<void> _openTabScroller(
    BuildContext context,
    BrowserModel browserModel,
    WindowModel windowModel,
  ) async {
    if (windowModel.webViewModels.isEmpty) {
      return;
    }

    final webViewModel = windowModel.getCurrentWebViewModel();
    final webViewController = webViewModel?.webViewController;

    if (View.of(context).viewInsets.bottom > 0.0) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      FocusManager.instance.primaryFocus?.unfocus();
      if (webViewController != null) {
        await webViewController.evaluateJavascript(
          source: "document.activeElement.blur();",
        );
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (webViewModel != null && webViewController != null) {
      webViewModel.screenshot = await webViewController
          .takeScreenshot(
            screenshotConfiguration: ScreenshotConfiguration(
              compressFormat: CompressFormat.JPEG,
              quality: 20,
            ),
          )
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => null,
          );
    }

    browserModel.showTabScroller = true;
  }
}
