import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'InfoCutter'**
  String get appTitle;

  /// No description provided for @searchOrTypeWebAddress.
  ///
  /// In en, this message translates to:
  /// **'Search or type a web address'**
  String get searchOrTypeWebAddress;

  /// No description provided for @findOnPageHint.
  ///
  /// In en, this message translates to:
  /// **'Find on page...'**
  String get findOnPageHint;

  /// No description provided for @openWebPageFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a web page first'**
  String get openWebPageFirst;

  /// No description provided for @pickerActiveOnHost.
  ///
  /// In en, this message translates to:
  /// **'Picker active on {host}'**
  String pickerActiveOnHost(String host);

  /// No description provided for @hiddenSelectorOnHost.
  ///
  /// In en, this message translates to:
  /// **'Hidden {selector} on {host}'**
  String hiddenSelectorOnHost(String selector, String host);

  /// No description provided for @savedOffline.
  ///
  /// In en, this message translates to:
  /// **'{url} saved offline.'**
  String savedOffline(String url);

  /// No description provided for @unableToSave.
  ///
  /// In en, this message translates to:
  /// **'Unable to save.'**
  String get unableToSave;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @openNewWindow.
  ///
  /// In en, this message translates to:
  /// **'Open New Window'**
  String get openNewWindow;

  /// No description provided for @saveWindow.
  ///
  /// In en, this message translates to:
  /// **'Save Window'**
  String get saveWindow;

  /// No description provided for @savedWindows.
  ///
  /// In en, this message translates to:
  /// **'Saved Windows'**
  String get savedWindows;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @newIncognitoTab.
  ///
  /// In en, this message translates to:
  /// **'New incognito tab'**
  String get newIncognitoTab;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @webArchives.
  ///
  /// In en, this message translates to:
  /// **'Web Archives'**
  String get webArchives;

  /// No description provided for @findOnPage.
  ///
  /// In en, this message translates to:
  /// **'Find on page'**
  String get findOnPage;

  /// No description provided for @desktopMode.
  ///
  /// In en, this message translates to:
  /// **'Desktop mode'**
  String get desktopMode;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @developers.
  ///
  /// In en, this message translates to:
  /// **'Developers'**
  String get developers;

  /// No description provided for @inAppWebViewProject.
  ///
  /// In en, this message translates to:
  /// **'InAppWebView Project'**
  String get inAppWebViewProject;

  /// No description provided for @closeTabs.
  ///
  /// In en, this message translates to:
  /// **'Close tabs'**
  String get closeTabs;

  /// No description provided for @closeAllTabs.
  ///
  /// In en, this message translates to:
  /// **'Close all tabs'**
  String get closeAllTabs;

  /// No description provided for @linkPreview.
  ///
  /// In en, this message translates to:
  /// **'Link Preview'**
  String get linkPreview;

  /// No description provided for @openInNewTab.
  ///
  /// In en, this message translates to:
  /// **'Open in a new tab'**
  String get openInNewTab;

  /// No description provided for @openInNewIncognitoTab.
  ///
  /// In en, this message translates to:
  /// **'Open in a new incognito tab'**
  String get openInNewIncognitoTab;

  /// No description provided for @copyAddressLink.
  ///
  /// In en, this message translates to:
  /// **'Copy address link'**
  String get copyAddressLink;

  /// No description provided for @shareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get shareLink;

  /// No description provided for @downloadImage.
  ///
  /// In en, this message translates to:
  /// **'Download image'**
  String get downloadImage;

  /// No description provided for @shareImage.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get shareImage;

  /// No description provided for @imageInNewTab.
  ///
  /// In en, this message translates to:
  /// **'Image in a new tab'**
  String get imageInNewTab;

  /// No description provided for @searchImageOnGoogle.
  ///
  /// In en, this message translates to:
  /// **'Search this image on Google'**
  String get searchImageOnGoogle;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Use system setting'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @searchEngine.
  ///
  /// In en, this message translates to:
  /// **'Search Engine'**
  String get searchEngine;

  /// No description provided for @defaultSite.
  ///
  /// In en, this message translates to:
  /// **'Default site'**
  String get defaultSite;

  /// No description provided for @homePage.
  ///
  /// In en, this message translates to:
  /// **'Home page'**
  String get homePage;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// No description provided for @customUrlHomePage.
  ///
  /// In en, this message translates to:
  /// **'Custom URL Home Page'**
  String get customUrlHomePage;

  /// No description provided for @defaultUserAgent.
  ///
  /// In en, this message translates to:
  /// **'Default User Agent'**
  String get defaultUserAgent;

  /// No description provided for @debuggingEnabled.
  ///
  /// In en, this message translates to:
  /// **'Debugging Enabled'**
  String get debuggingEnabled;

  /// No description provided for @debuggingEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Enables debugging of web contents loaded into any WebViews of this application. On iOS < 16.4, the debugging mode is always enabled.'**
  String get debuggingEnabledDescription;

  /// No description provided for @infocutterCutPage.
  ///
  /// In en, this message translates to:
  /// **'Hide page blocks'**
  String get infocutterCutPage;

  /// No description provided for @infocutterReviewSelection.
  ///
  /// In en, this message translates to:
  /// **'Block hiding settings'**
  String get infocutterReviewSelection;

  /// No description provided for @infocutterReviewSelectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm the block and saved name to hide on {host}.'**
  String infocutterReviewSelectionDescription(String host);

  /// No description provided for @infocutterCardName.
  ///
  /// In en, this message translates to:
  /// **'Block name'**
  String get infocutterCardName;

  /// No description provided for @infocutterSelector.
  ///
  /// In en, this message translates to:
  /// **'Selector'**
  String get infocutterSelector;

  /// No description provided for @infocutterSelectorCandidates.
  ///
  /// In en, this message translates to:
  /// **'Block candidates'**
  String get infocutterSelectorCandidates;

  /// No description provided for @infocutterPointerCandidates.
  ///
  /// In en, this message translates to:
  /// **'Pointer candidates'**
  String get infocutterPointerCandidates;

  /// No description provided for @infocutterTargetRange.
  ///
  /// In en, this message translates to:
  /// **'Target range'**
  String get infocutterTargetRange;

  /// No description provided for @infocutterSelectorDetails.
  ///
  /// In en, this message translates to:
  /// **'Selector details'**
  String get infocutterSelectorDetails;

  /// No description provided for @infocutterNarrowTarget.
  ///
  /// In en, this message translates to:
  /// **'Narrow target'**
  String get infocutterNarrowTarget;

  /// No description provided for @infocutterWidenTarget.
  ///
  /// In en, this message translates to:
  /// **'Widen target'**
  String get infocutterWidenTarget;

  /// No description provided for @infocutterNextSelector.
  ///
  /// In en, this message translates to:
  /// **'Next selector'**
  String get infocutterNextSelector;

  /// No description provided for @infocutterSelectedTarget.
  ///
  /// In en, this message translates to:
  /// **'Selected target'**
  String get infocutterSelectedTarget;

  /// No description provided for @infocutterSelectedBadge.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get infocutterSelectedBadge;

  /// No description provided for @infocutterApplyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This selector cannot be applied'**
  String get infocutterApplyBlocked;

  /// No description provided for @infocutterCutSettingsTab.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get infocutterCutSettingsTab;

  /// No description provided for @infocutterCurrentSiteTab.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get infocutterCurrentSiteTab;

  /// No description provided for @infocutterWatchTab.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get infocutterWatchTab;

  /// No description provided for @infocutterEvidenceTab.
  ///
  /// In en, this message translates to:
  /// **'Captures'**
  String get infocutterEvidenceTab;

  /// No description provided for @infocutterSettingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get infocutterSettingsTab;

  /// No description provided for @infocutterBlockShortTab.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get infocutterBlockShortTab;

  /// No description provided for @infocutterTextShortTab.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get infocutterTextShortTab;

  /// No description provided for @infocutterAiShortTab.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get infocutterAiShortTab;

  /// No description provided for @infocutterTemplatesShortTab.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get infocutterTemplatesShortTab;

  /// No description provided for @infocutterDirectRemoveCategory.
  ///
  /// In en, this message translates to:
  /// **'Remove manually'**
  String get infocutterDirectRemoveCategory;

  /// No description provided for @infocutterAutoRemoveCategory.
  ///
  /// In en, this message translates to:
  /// **'Remove automatically'**
  String get infocutterAutoRemoveCategory;

  /// No description provided for @infocutterManageRemovedCategory.
  ///
  /// In en, this message translates to:
  /// **'Manage removed items'**
  String get infocutterManageRemovedCategory;

  /// No description provided for @infocutterAppSettingsCategory.
  ///
  /// In en, this message translates to:
  /// **'Configure app'**
  String get infocutterAppSettingsCategory;

  /// No description provided for @infocutterPickBlockRemoveTab.
  ///
  /// In en, this message translates to:
  /// **'Pick a block on screen to remove'**
  String get infocutterPickBlockRemoveTab;

  /// No description provided for @infocutterKeywordBlockRemoveTab.
  ///
  /// In en, this message translates to:
  /// **'Remove blocks that contain text'**
  String get infocutterKeywordBlockRemoveTab;

  /// No description provided for @infocutterNetworkRequestBlockTab.
  ///
  /// In en, this message translates to:
  /// **'Block ad/tracker requests'**
  String get infocutterNetworkRequestBlockTab;

  /// No description provided for @infocutterWatchAutoRemoveTab.
  ///
  /// In en, this message translates to:
  /// **'Hide when watch terms appear'**
  String get infocutterWatchAutoRemoveTab;

  /// No description provided for @infocutterAiRecommendRemoveTab.
  ///
  /// In en, this message translates to:
  /// **'Let AI recommend items to remove'**
  String get infocutterAiRecommendRemoveTab;

  /// No description provided for @infocutterCurrentSiteRulesTab.
  ///
  /// In en, this message translates to:
  /// **'Manage current site rules'**
  String get infocutterCurrentSiteRulesTab;

  /// No description provided for @infocutterImportRecommendedRulesTab.
  ///
  /// In en, this message translates to:
  /// **'Import recommended rules'**
  String get infocutterImportRecommendedRulesTab;

  /// No description provided for @infocutterEvidenceRecordsViewTab.
  ///
  /// In en, this message translates to:
  /// **'View capture records'**
  String get infocutterEvidenceRecordsViewTab;

  /// No description provided for @infocutterGlobalSettingsTab.
  ///
  /// In en, this message translates to:
  /// **'Turn Infocutter on/off'**
  String get infocutterGlobalSettingsTab;

  /// No description provided for @infocutterClosePanel.
  ///
  /// In en, this message translates to:
  /// **'Close Infocutter panel'**
  String get infocutterClosePanel;

  /// No description provided for @infocutterActiveProfile.
  ///
  /// In en, this message translates to:
  /// **'Active profile'**
  String get infocutterActiveProfile;

  /// No description provided for @infocutterNoActiveProfile.
  ///
  /// In en, this message translates to:
  /// **'No active profile'**
  String get infocutterNoActiveProfile;

  /// No description provided for @infocutterNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get infocutterNoItemsYet;

  /// No description provided for @infocutterWatchTargets.
  ///
  /// In en, this message translates to:
  /// **'Watch targets'**
  String get infocutterWatchTargets;

  /// No description provided for @infocutterEvidenceRecords.
  ///
  /// In en, this message translates to:
  /// **'Capture records'**
  String get infocutterEvidenceRecords;

  /// No description provided for @infocutterImportAndSettings.
  ///
  /// In en, this message translates to:
  /// **'Import and settings'**
  String get infocutterImportAndSettings;

  /// No description provided for @infocutterGlobalEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Infocutter globally'**
  String get infocutterGlobalEnabled;

  /// No description provided for @infocutterProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get infocutterProfiles;

  /// No description provided for @infocutterProfilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles'**
  String infocutterProfilesCount(int count);

  /// No description provided for @infocutterCreateProfile.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get infocutterCreateProfile;

  /// No description provided for @infocutterProfileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get infocutterProfileName;

  /// No description provided for @infocutterMatchers.
  ///
  /// In en, this message translates to:
  /// **'Matchers'**
  String get infocutterMatchers;

  /// No description provided for @infocutterEditMatchers.
  ///
  /// In en, this message translates to:
  /// **'Edit matchers'**
  String get infocutterEditMatchers;

  /// No description provided for @infocutterRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get infocutterRename;

  /// No description provided for @infocutterDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get infocutterDelete;

  /// No description provided for @infocutterConfirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this item? This cannot be undone.'**
  String get infocutterConfirmDeleteMessage;

  /// No description provided for @infocutterImportJson.
  ///
  /// In en, this message translates to:
  /// **'Import Chrome JSON'**
  String get infocutterImportJson;

  /// No description provided for @infocutterExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export Chrome JSON'**
  String get infocutterExportJson;

  /// No description provided for @infocutterExportCopied.
  ///
  /// In en, this message translates to:
  /// **'Export JSON copied to clipboard'**
  String get infocutterExportCopied;

  /// No description provided for @infocutterSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get infocutterSave;

  /// No description provided for @infocutterRuleActions.
  ///
  /// In en, this message translates to:
  /// **'Rule actions'**
  String get infocutterRuleActions;

  /// No description provided for @infocutterEditSelector.
  ///
  /// In en, this message translates to:
  /// **'Edit selector'**
  String get infocutterEditSelector;

  /// No description provided for @infocutterToggleRuleMode.
  ///
  /// In en, this message translates to:
  /// **'Toggle hide/exception'**
  String get infocutterToggleRuleMode;

  /// No description provided for @infocutterFrameScope.
  ///
  /// In en, this message translates to:
  /// **'Frame scope'**
  String get infocutterFrameScope;

  /// No description provided for @infocutterMainFrame.
  ///
  /// In en, this message translates to:
  /// **'Main frame'**
  String get infocutterMainFrame;

  /// No description provided for @infocutterRuleModeHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get infocutterRuleModeHide;

  /// No description provided for @infocutterRuleModeUnhide.
  ///
  /// In en, this message translates to:
  /// **'Exception'**
  String get infocutterRuleModeUnhide;

  /// No description provided for @infocutterTemplates.
  ///
  /// In en, this message translates to:
  /// **'Rule templates'**
  String get infocutterTemplates;

  /// No description provided for @infocutterImportTemplate.
  ///
  /// In en, this message translates to:
  /// **'Import template'**
  String get infocutterImportTemplate;

  /// No description provided for @infocutterTemplateImported.
  ///
  /// In en, this message translates to:
  /// **'{name} template imported'**
  String infocutterTemplateImported(String name);

  /// No description provided for @infocutterWatchGlobalEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable watch'**
  String get infocutterWatchGlobalEnabled;

  /// No description provided for @infocutterWatchAutoMask.
  ///
  /// In en, this message translates to:
  /// **'Auto-mask when detected'**
  String get infocutterWatchAutoMask;

  /// No description provided for @infocutterWatchTargetName.
  ///
  /// In en, this message translates to:
  /// **'Watch target name'**
  String get infocutterWatchTargetName;

  /// No description provided for @infocutterWatchAliases.
  ///
  /// In en, this message translates to:
  /// **'Aliases (comma-separated)'**
  String get infocutterWatchAliases;

  /// No description provided for @infocutterAddWatchTarget.
  ///
  /// In en, this message translates to:
  /// **'Add watch target'**
  String get infocutterAddWatchTarget;

  /// No description provided for @infocutterWatchDetections.
  ///
  /// In en, this message translates to:
  /// **'Recent detections'**
  String get infocutterWatchDetections;

  /// No description provided for @infocutterCaptureEvidence.
  ///
  /// In en, this message translates to:
  /// **'Save current page capture'**
  String get infocutterCaptureEvidence;

  /// No description provided for @infocutterNoEvidenceRecords.
  ///
  /// In en, this message translates to:
  /// **'No capture records saved'**
  String get infocutterNoEvidenceRecords;

  /// No description provided for @infocutterEvidenceCaptured.
  ///
  /// In en, this message translates to:
  /// **'Saved capture record #{sequence}'**
  String infocutterEvidenceCaptured(int sequence);

  /// No description provided for @infocutterAiAutoMasking.
  ///
  /// In en, this message translates to:
  /// **'AI auto masking'**
  String get infocutterAiAutoMasking;

  /// No description provided for @infocutterAiPendingDecision.
  ///
  /// In en, this message translates to:
  /// **'App inclusion, privacy, and cost policy still need a product decision.'**
  String get infocutterAiPendingDecision;

  /// No description provided for @infocutterAiConfigured.
  ///
  /// In en, this message translates to:
  /// **'{model} configured'**
  String infocutterAiConfigured(String model);

  /// No description provided for @infocutterAiEndpoint.
  ///
  /// In en, this message translates to:
  /// **'AI endpoint'**
  String get infocutterAiEndpoint;

  /// No description provided for @infocutterAiModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get infocutterAiModel;

  /// No description provided for @infocutterAiApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get infocutterAiApiKey;

  /// No description provided for @infocutterAiSaveConfig.
  ///
  /// In en, this message translates to:
  /// **'Save AI config'**
  String get infocutterAiSaveConfig;

  /// No description provided for @infocutterAiConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'AI config saved'**
  String get infocutterAiConfigSaved;

  /// No description provided for @infocutterAiResetHosts.
  ///
  /// In en, this message translates to:
  /// **'Reset analyzed hosts'**
  String get infocutterAiResetHosts;

  /// No description provided for @infocutterAiAnalyzedHosts.
  ///
  /// In en, this message translates to:
  /// **'{count} analyzed hosts'**
  String infocutterAiAnalyzedHosts(int count);

  /// No description provided for @infocutterAiAnalyzeCurrentPage.
  ///
  /// In en, this message translates to:
  /// **'Analyze current page with AI'**
  String get infocutterAiAnalyzeCurrentPage;

  /// No description provided for @infocutterAiAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing'**
  String get infocutterAiAnalyzing;

  /// No description provided for @infocutterAiAnalyzeFailed.
  ///
  /// In en, this message translates to:
  /// **'AI analysis failed'**
  String get infocutterAiAnalyzeFailed;

  /// No description provided for @infocutterAiApplySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Apply suggestion'**
  String get infocutterAiApplySuggestion;

  /// No description provided for @infocutterAiSuggestions.
  ///
  /// In en, this message translates to:
  /// **'{count} AI suggestions'**
  String infocutterAiSuggestions(int count);

  /// No description provided for @infocutterTextBlocks.
  ///
  /// In en, this message translates to:
  /// **'Text blocks'**
  String get infocutterTextBlocks;

  /// No description provided for @infocutterTextBlockGlobalEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable text block hiding'**
  String get infocutterTextBlockGlobalEnabled;

  /// No description provided for @infocutterTextBlockKeyword.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get infocutterTextBlockKeyword;

  /// No description provided for @infocutterTextBlockObjectName.
  ///
  /// In en, this message translates to:
  /// **'Object name'**
  String get infocutterTextBlockObjectName;

  /// No description provided for @infocutterTextBlockMinMatchCount.
  ///
  /// In en, this message translates to:
  /// **'Minimum repeats'**
  String get infocutterTextBlockMinMatchCount;

  /// No description provided for @infocutterTextBlockAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add text block rule'**
  String get infocutterTextBlockAddRule;

  /// No description provided for @infocutterTextBlockProfileEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable text rules for this site'**
  String get infocutterTextBlockProfileEnabled;

  /// No description provided for @infocutterCaptureKeyword.
  ///
  /// In en, this message translates to:
  /// **'Grab keyword'**
  String get infocutterCaptureKeyword;

  /// No description provided for @infocutterNetworkFilters.
  ///
  /// In en, this message translates to:
  /// **'Network filters'**
  String get infocutterNetworkFilters;

  /// No description provided for @infocutterNetworkFilterGlobalEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable network filters'**
  String get infocutterNetworkFilterGlobalEnabled;

  /// No description provided for @infocutterNetworkFilterPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste ABP/uBlock network filters'**
  String get infocutterNetworkFilterPaste;

  /// No description provided for @infocutterNetworkFilterImport.
  ///
  /// In en, this message translates to:
  /// **'Import filters'**
  String get infocutterNetworkFilterImport;

  /// No description provided for @infocutterNetworkFilterImportResult.
  ///
  /// In en, this message translates to:
  /// **'{imported} imported · {skipped} skipped'**
  String infocutterNetworkFilterImportResult(int imported, int skipped);

  /// No description provided for @infocutterNetworkFilterAllowRule.
  ///
  /// In en, this message translates to:
  /// **'Allow rule'**
  String get infocutterNetworkFilterAllowRule;

  /// No description provided for @infocutterNetworkFilterBlockRule.
  ///
  /// In en, this message translates to:
  /// **'Block rule'**
  String get infocutterNetworkFilterBlockRule;

  /// No description provided for @infocutterRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get infocutterRemove;

  /// No description provided for @infocutterSavedCards.
  ///
  /// In en, this message translates to:
  /// **'{count} blocks'**
  String infocutterSavedCards(int count);

  /// No description provided for @infocutterSavedRules.
  ///
  /// In en, this message translates to:
  /// **'{count} rules'**
  String infocutterSavedRules(int count);

  /// No description provided for @infocutterEnabledRules.
  ///
  /// In en, this message translates to:
  /// **'{count} active hides'**
  String infocutterEnabledRules(int count);

  /// No description provided for @infocutterMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String infocutterMatchCount(int count);

  /// No description provided for @infocutterInvalidSelector.
  ///
  /// In en, this message translates to:
  /// **'Invalid selector'**
  String get infocutterInvalidSelector;

  /// No description provided for @infocutterSaveRule.
  ///
  /// In en, this message translates to:
  /// **'Hide block'**
  String get infocutterSaveRule;

  /// No description provided for @infocutterSessionPickHint.
  ///
  /// In en, this message translates to:
  /// **'Click elements on the page to stage them'**
  String get infocutterSessionPickHint;

  /// No description provided for @infocutterStagedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} staged'**
  String infocutterStagedCount(int count);

  /// No description provided for @infocutterSessionApplyAll.
  ///
  /// In en, this message translates to:
  /// **'Apply all ({count})'**
  String infocutterSessionApplyAll(int count);

  /// No description provided for @infocutterPickTab.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get infocutterPickTab;

  /// No description provided for @infocutterHiddenListTab.
  ///
  /// In en, this message translates to:
  /// **'Hidden list'**
  String get infocutterHiddenListTab;

  /// No description provided for @infocutterTooBroadSelector.
  ///
  /// In en, this message translates to:
  /// **'Hides the whole page'**
  String get infocutterTooBroadSelector;

  /// No description provided for @infocutterFixSelectorsToApply.
  ///
  /// In en, this message translates to:
  /// **'Fix invalid selectors to apply'**
  String get infocutterFixSelectorsToApply;

  /// No description provided for @infocutterModulesTab.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get infocutterModulesTab;

  /// No description provided for @infocutterModulesHint.
  ///
  /// In en, this message translates to:
  /// **'Turning a module off stops it on every site'**
  String get infocutterModulesHint;

  /// No description provided for @infocutterBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup / restore'**
  String get infocutterBackupRestore;

  /// No description provided for @infocutterExportRules.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get infocutterExportRules;

  /// No description provided for @infocutterImportRules.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get infocutterImportRules;

  /// No description provided for @infocutterRulesExported.
  ///
  /// In en, this message translates to:
  /// **'Block rules copied to clipboard'**
  String get infocutterRulesExported;

  /// No description provided for @infocutterRulesImported.
  ///
  /// In en, this message translates to:
  /// **'Rules imported'**
  String get infocutterRulesImported;

  /// No description provided for @infocutterImportPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste exported JSON'**
  String get infocutterImportPasteHint;

  /// No description provided for @infocutterUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get infocutterUndo;

  /// No description provided for @infocutterEvidenceCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save page capture'**
  String get infocutterEvidenceCaptureFailed;

  /// No description provided for @infocutterImportReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: importing replaces your saved rules'**
  String get infocutterImportReplaceWarning;

  /// No description provided for @infocutterImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid config bundle'**
  String get infocutterImportInvalid;

  /// No description provided for @infocutterAiPrompt.
  ///
  /// In en, this message translates to:
  /// **'AI prompt'**
  String get infocutterAiPrompt;

  /// No description provided for @infocutterAiPromptHelp.
  ///
  /// In en, this message translates to:
  /// **'Describe what to hide (the output format is handled automatically)'**
  String get infocutterAiPromptHelp;

  /// No description provided for @infocutterAlreadyHiddenSection.
  ///
  /// In en, this message translates to:
  /// **'Already hidden ({count})'**
  String infocutterAlreadyHiddenSection(int count);

  /// No description provided for @infocutterPickingNowSection.
  ///
  /// In en, this message translates to:
  /// **'Picking now ({count})'**
  String infocutterPickingNowSection(int count);

  /// No description provided for @infocutterAppliedEditsLiveHint.
  ///
  /// In en, this message translates to:
  /// **'Edits here apply to the page immediately'**
  String get infocutterAppliedEditsLiveHint;

  /// No description provided for @infocutterDeleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get infocutterDeleteRule;

  /// No description provided for @infocutterCardsManagedInPickTab.
  ///
  /// In en, this message translates to:
  /// **'Edit this profile\'s cards in the 고르기 (Pick) tab'**
  String get infocutterCardsManagedInPickTab;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed WebView options. Most people never need these.'**
  String get settingsAdvancedSubtitle;

  /// No description provided for @settingsDeveloperTools.
  ///
  /// In en, this message translates to:
  /// **'Developer tools'**
  String get settingsDeveloperTools;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep only what you want to see'**
  String get onboardingTitle;

  /// No description provided for @onboardingPickBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the scissors next to the address bar, then pick what to hide. It stays hidden the next time you visit.'**
  String get onboardingPickBody;

  /// No description provided for @onboardingPeekBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on peek to reveal hidden parts for a moment. Rules are saved per site.'**
  String get onboardingPeekBody;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @authUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is not available in this browser'**
  String get authUnsupportedTitle;

  /// No description provided for @authUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'Google and some other services block sign-in from in-app browsers by policy. This is not an app error.'**
  String get authUnsupportedBody;

  /// No description provided for @authOpenExternally.
  ///
  /// In en, this message translates to:
  /// **'Open in default browser'**
  String get authOpenExternally;

  /// No description provided for @a11yBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get a11yBack;

  /// No description provided for @a11yForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get a11yForward;

  /// No description provided for @a11yReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get a11yReload;

  /// No description provided for @a11yMoreMenu.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get a11yMoreMenu;

  /// No description provided for @a11yTabCount.
  ///
  /// In en, this message translates to:
  /// **'Open tabs'**
  String get a11yTabCount;

  /// No description provided for @a11yInfocutterPick.
  ///
  /// In en, this message translates to:
  /// **'Pick element to hide'**
  String get a11yInfocutterPick;

  /// No description provided for @a11yActionBar.
  ///
  /// In en, this message translates to:
  /// **'Browser toolbar'**
  String get a11yActionBar;

  /// No description provided for @a11ySiteInfo.
  ///
  /// In en, this message translates to:
  /// **'View site info'**
  String get a11ySiteInfo;

  /// No description provided for @rendererCrashTitle.
  ///
  /// In en, this message translates to:
  /// **'The page process stopped'**
  String get rendererCrashTitle;

  /// No description provided for @rendererCrashBody.
  ///
  /// In en, this message translates to:
  /// **'When the device runs low on memory, the system reclaims web page processes first. Close other apps and try again.'**
  String get rendererCrashBody;

  /// No description provided for @rendererCrashRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get rendererCrashRetry;

  /// No description provided for @loadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load this page'**
  String get loadErrorTitle;

  /// No description provided for @loadErrorBodyGeneric.
  ///
  /// In en, this message translates to:
  /// **'A network error occurred, or the site could not be reached.'**
  String get loadErrorBodyGeneric;

  /// No description provided for @loadErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'No response in time. Check the connection and try again.'**
  String get loadErrorTimeout;

  /// No description provided for @loadErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get loadErrorRetry;

  /// No description provided for @siteProtectionBypassTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off protection on this site'**
  String get siteProtectionBypassTitle;

  /// No description provided for @siteProtectionBypassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Temporarily disable hide, filters, and watch if they break the page'**
  String get siteProtectionBypassSubtitle;

  /// No description provided for @siteProtectionBypassActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Infocutter protection is off for this host.'**
  String get siteProtectionBypassActiveHint;

  /// No description provided for @networkFilterSubscribeUrl.
  ///
  /// In en, this message translates to:
  /// **'Filter list URL'**
  String get networkFilterSubscribeUrl;

  /// No description provided for @networkFilterSubscribeAction.
  ///
  /// In en, this message translates to:
  /// **'Fetch from URL'**
  String get networkFilterSubscribeAction;

  /// No description provided for @networkFilterSubscribeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch filter list: {error}'**
  String networkFilterSubscribeFailed(String error);

  /// No description provided for @jsDialogDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Page message'**
  String get jsDialogDefaultTitle;

  /// No description provided for @readerModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader mode'**
  String get readerModeTitle;

  /// No description provided for @readerModeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Could not find readable text on this page.'**
  String get readerModeEmpty;

  /// No description provided for @readerModeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open reader mode.'**
  String get readerModeFailed;

  /// No description provided for @menuReaderMode.
  ///
  /// In en, this message translates to:
  /// **'Reader mode'**
  String get menuReaderMode;

  /// No description provided for @pickerStopped.
  ///
  /// In en, this message translates to:
  /// **'Selection mode ended'**
  String get pickerStopped;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
