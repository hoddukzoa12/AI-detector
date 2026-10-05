import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:infocutter_app/animated_flutter_browser_logo.dart';
import 'package:infocutter_app/app_bar/webview_tab_count_button.dart';
import 'package:infocutter_app/app_bar/webview_tab_quick_actions.dart';
import 'package:infocutter_app/custom_popup_menu_item.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/l10n/localized_menu_labels.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/popup_menu_actions.dart';
import 'package:infocutter_app/theme/infocutter_tokens.g.dart';
import 'package:infocutter_app/util.dart';
import 'package:provider/provider.dart';

class WebViewTabActionsMenu extends StatefulWidget {
  final void Function(String choice) onPopupMenuChoiceSelected;
  final VoidCallback onAddNewTab;
  final VoidCallback onAddNewIncognitoTab;
  final Future<void> Function() onShowUrlInfoAfterPopup;
  final Future<void> Function() onTakeScreenshotAfterPopup;

  const WebViewTabActionsMenu({
    required this.onPopupMenuChoiceSelected,
    required this.onAddNewTab,
    required this.onAddNewIncognitoTab,
    required this.onShowUrlInfoAfterPopup,
    required this.onTakeScreenshotAfterPopup,
    super.key,
  });

  @override
  State<WebViewTabActionsMenu> createState() => _WebViewTabActionsMenuState();
}

class _WebViewTabActionsMenuState extends State<WebViewTabActionsMenu> {
  /// 메뉴 아이콘의 기본색. `Colors.black` 고정이면 다크 테마에서 사라진다.
  InfocutterTokens get _tokens =>
      InfocutterTokens(Theme.of(context).brightness);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final browserModel = Provider.of<BrowserModel>(context);
    final l10n = AppLocalizations.of(context);
    final windowModel = Provider.of<WindowModel>(context);
    final settings = browserModel.getSettings();

    return [
      settings.homePageEnabled ? const SizedBox(width: 10.0) : Container(),
      Util.isDesktop()
          ? null
          : WebViewTabCountButton(
              onAddNewTab: widget.onAddNewTab,
              onAddNewIncognitoTab: widget.onAddNewIncognitoTab,
            ),
      const SizedBox.square(dimension: 5),
      // 앱바 오른쪽 끝의 `⋮` 는 **브라우저 전체** 메뉴다. 주소창 안에 있던
      // 같은 아이콘과 구분되도록 접근 가능한 이름(tooltip)을 붙인다.
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: l10n.a11yMoreMenu,
        position: PopupMenuPosition.under,
        onSelected: widget.onPopupMenuChoiceSelected,
        itemBuilder: (popupMenuContext) {
          return _buildPopupMenuItems(
              context, popupMenuContext, windowModel, l10n);
        },
      ),
    ].nonNulls.toList();
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems(
    BuildContext context,
    BuildContext popupMenuContext,
    WindowModel windowModel,
    AppLocalizations l10n,
  ) =>
      [
        _quickActionsItem(context, popupMenuContext),
        ..._visibleChoices().map(
          (choice) => _choiceMenuItem(choice, windowModel, l10n),
        ),
      ];

  /// 개발자 도구(스토리지 관리자·JS 콘솔·네트워크 정보)는 upstream 브라우저에서
  /// 온 디버그 표면이다. 일반 사용자 메뉴에 둘 것이 아니므로 릴리스 빌드에서 감춘다.
  Iterable<String> _visibleChoices() => PopupMenuActions.choices.where(
        (choice) => kDebugMode || choice != PopupMenuActions.DEVELOPERS,
      );

  CustomPopupMenuItem<String> _quickActionsItem(
    BuildContext context,
    BuildContext popupMenuContext,
  ) =>
      CustomPopupMenuItem<String>(
        isIconButtonRow: true,
        child: WebViewTabQuickActions(
          popupMenuContext: popupMenuContext,
          scaffoldContext: context,
          onShowUrlInfoAfterPopup: widget.onShowUrlInfoAfterPopup,
          onTakeScreenshotAfterPopup: widget.onTakeScreenshotAfterPopup,
        ),
      );

  PopupMenuEntry<String> _choiceMenuItem(
    String choice,
    WindowModel windowModel,
    AppLocalizations l10n,
  ) {
    final icon = _choiceIcon(choice);
    if (icon == null) {
      return CustomPopupMenuItem<String>(
        value: choice,
        child: Text(l10n.popupMenuActionLabel(choice)),
      );
    }

    return _menuItem(
      choice: choice,
      enabled: _choiceEnabled(choice, windowModel),
      label: l10n.popupMenuActionLabel(choice),
      icon: icon,
    );
  }

  bool _choiceEnabled(String choice, WindowModel windowModel) {
    final requiresCurrentTab = {
      PopupMenuActions.DESKTOP_MODE,
      PopupMenuActions.HISTORY,
      PopupMenuActions.SHARE,
      PopupMenuActions.DEVELOPERS,
      PopupMenuActions.FIND_ON_PAGE,
      PopupMenuActions.READER_MODE,
    };
    return !requiresCurrentTab.contains(choice) ||
        windowModel.getCurrentWebViewModel() != null;
  }

  Widget? _choiceIcon(String choice) => switch (choice) {
        PopupMenuActions.OPEN_NEW_WINDOW => const Icon(Icons.open_in_new),
        PopupMenuActions.SAVE_WINDOW => _saveWindowIcon(),
        PopupMenuActions.SAVED_WINDOWS => const Icon(Icons.window),
        PopupMenuActions.NEW_TAB => Icon(Icons.add, color: _tokens.text),
        PopupMenuActions.NEW_INCOGNITO_TAB =>
          Icon(Icons.visibility_off, color: _tokens.text),
        PopupMenuActions.FAVORITES =>
          const Icon(Icons.star, color: Colors.yellow),
        PopupMenuActions.WEB_ARCHIVES =>
          const Icon(Icons.offline_pin, color: Colors.blue),
        PopupMenuActions.DESKTOP_MODE => _desktopModeIcon(),
        PopupMenuActions.HISTORY => Icon(Icons.history, color: _tokens.text),
        PopupMenuActions.SHARE => const Icon(Icons.share, color: Colors.green),
        PopupMenuActions.SETTINGS =>
          const Icon(Icons.settings, color: Colors.grey),
        PopupMenuActions.DEVELOPERS =>
          Icon(Icons.developer_mode, color: _tokens.text),
        PopupMenuActions.FIND_ON_PAGE =>
          Icon(Icons.search, color: _tokens.text),
        PopupMenuActions.READER_MODE =>
          Icon(Icons.chrome_reader_mode_outlined, color: _tokens.text),
        PopupMenuActions.INAPPWEBVIEW_PROJECT => Container(
            padding: const EdgeInsets.only(right: 6),
            child: const AnimatedFlutterBrowserLogo(size: 12.5),
          ),
        _ => null,
      };

  Widget _saveWindowIcon() => Selector<WindowModel, bool>(
        selector: (context, windowModel) => windowModel.shouldSave,
        builder: (context, value, child) {
          return Icon(
            value ? Icons.check_box : Icons.check_box_outline_blank,
            color: _tokens.text,
          );
        },
      );

  Widget _desktopModeIcon() => Selector<WebViewModel, bool>(
        selector: (context, webViewModel) => webViewModel.isDesktopMode,
        builder: (context, value, child) {
          return Icon(
            value ? Icons.check_box : Icons.check_box_outline_blank,
            color: _tokens.text,
          );
        },
      );

  CustomPopupMenuItem<String> _menuItem({
    required String choice,
    required String label,
    required Widget icon,
    bool enabled = true,
  }) {
    return CustomPopupMenuItem<String>(
      enabled: enabled,
      value: choice,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          icon,
        ],
      ),
    );
  }
}
