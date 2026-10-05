import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/popup_menu_actions.dart';
import 'package:infocutter_app/tab_popup_menu_actions.dart';
import 'package:infocutter_app/tab_viewer_popup_menu_actions.dart';

extension LocalizedPopupMenuLabels on AppLocalizations {
  String popupMenuActionLabel(String action) {
    switch (action) {
      case PopupMenuActions.OPEN_NEW_WINDOW:
        return openNewWindow;
      case PopupMenuActions.SAVE_WINDOW:
        return saveWindow;
      case PopupMenuActions.SAVED_WINDOWS:
        return savedWindows;
      case PopupMenuActions.NEW_TAB:
        return newTab;
      case PopupMenuActions.NEW_INCOGNITO_TAB:
        return newIncognitoTab;
      case PopupMenuActions.FAVORITES:
        return favorites;
      case PopupMenuActions.HISTORY:
        return history;
      case PopupMenuActions.WEB_ARCHIVES:
        return webArchives;
      case PopupMenuActions.SHARE:
        return share;
      case PopupMenuActions.FIND_ON_PAGE:
        return findOnPage;
      case PopupMenuActions.READER_MODE:
        return menuReaderMode;
      case PopupMenuActions.DESKTOP_MODE:
        return desktopMode;
      case PopupMenuActions.SETTINGS:
        return settings;
      case PopupMenuActions.DEVELOPERS:
        return developers;
      case PopupMenuActions.INAPPWEBVIEW_PROJECT:
        return inAppWebViewProject;
      default:
        return action;
    }
  }

  String tabPopupMenuActionLabel(String action) {
    switch (action) {
      case TabPopupMenuActions.CLOSE_TABS:
        return closeTabs;
      case TabPopupMenuActions.NEW_TAB:
        return newTab;
      case TabPopupMenuActions.NEW_INCOGNITO_TAB:
        return newIncognitoTab;
      default:
        return action;
    }
  }

  String tabViewerPopupMenuActionLabel(String action) {
    switch (action) {
      case TabViewerPopupMenuActions.NEW_TAB:
        return newTab;
      case TabViewerPopupMenuActions.NEW_INCOGNITO_TAB:
        return newIncognitoTab;
      case TabViewerPopupMenuActions.CLOSE_ALL_TABS:
        return closeAllTabs;
      case TabViewerPopupMenuActions.SETTINGS:
        return settings;
      default:
        return action;
    }
  }
}
