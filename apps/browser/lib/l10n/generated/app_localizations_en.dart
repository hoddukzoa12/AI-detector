// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'InfoCutter';

  @override
  String get searchOrTypeWebAddress => 'Search or type a web address';

  @override
  String get findOnPageHint => 'Find on page...';

  @override
  String get openWebPageFirst => 'Open a web page first';

  @override
  String pickerActiveOnHost(String host) {
    return 'Picker active on $host';
  }

  @override
  String hiddenSelectorOnHost(String selector, String host) {
    return 'Hidden $selector on $host';
  }

  @override
  String savedOffline(String url) {
    return '$url saved offline.';
  }

  @override
  String get unableToSave => 'Unable to save.';

  @override
  String get share => 'Share';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get openNewWindow => 'Open New Window';

  @override
  String get saveWindow => 'Save Window';

  @override
  String get savedWindows => 'Saved Windows';

  @override
  String get newTab => 'New tab';

  @override
  String get newIncognitoTab => 'New incognito tab';

  @override
  String get favorites => 'Favorites';

  @override
  String get history => 'History';

  @override
  String get webArchives => 'Web Archives';

  @override
  String get findOnPage => 'Find on page';

  @override
  String get desktopMode => 'Desktop mode';

  @override
  String get settings => 'Settings';

  @override
  String get developers => 'Developers';

  @override
  String get inAppWebViewProject => 'InAppWebView Project';

  @override
  String get closeTabs => 'Close tabs';

  @override
  String get closeAllTabs => 'Close all tabs';

  @override
  String get linkPreview => 'Link Preview';

  @override
  String get openInNewTab => 'Open in a new tab';

  @override
  String get openInNewIncognitoTab => 'Open in a new incognito tab';

  @override
  String get copyAddressLink => 'Copy address link';

  @override
  String get shareLink => 'Share link';

  @override
  String get downloadImage => 'Download image';

  @override
  String get shareImage => 'Share image';

  @override
  String get imageInNewTab => 'Image in a new tab';

  @override
  String get searchImageOnGoogle => 'Search this image on Google';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get themeModeSystem => 'Use system setting';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get searchEngine => 'Search Engine';

  @override
  String get defaultSite => 'Default site';

  @override
  String get homePage => 'Home page';

  @override
  String get on => 'ON';

  @override
  String get off => 'OFF';

  @override
  String get customUrlHomePage => 'Custom URL Home Page';

  @override
  String get defaultUserAgent => 'Default User Agent';

  @override
  String get debuggingEnabled => 'Debugging Enabled';

  @override
  String get debuggingEnabledDescription =>
      'Enables debugging of web contents loaded into any WebViews of this application. On iOS < 16.4, the debugging mode is always enabled.';

  @override
  String get infocutterCutPage => 'Hide page blocks';

  @override
  String get infocutterReviewSelection => 'Block hiding settings';

  @override
  String infocutterReviewSelectionDescription(String host) {
    return 'Confirm the block and saved name to hide on $host.';
  }

  @override
  String get infocutterCardName => 'Block name';

  @override
  String get infocutterSelector => 'Selector';

  @override
  String get infocutterSelectorCandidates => 'Block candidates';

  @override
  String get infocutterPointerCandidates => 'Pointer candidates';

  @override
  String get infocutterTargetRange => 'Target range';

  @override
  String get infocutterSelectorDetails => 'Selector details';

  @override
  String get infocutterNarrowTarget => 'Narrow target';

  @override
  String get infocutterWidenTarget => 'Widen target';

  @override
  String get infocutterNextSelector => 'Next selector';

  @override
  String get infocutterSelectedTarget => 'Selected target';

  @override
  String get infocutterSelectedBadge => 'Selected';

  @override
  String get infocutterApplyBlocked => 'This selector cannot be applied';

  @override
  String get infocutterCutSettingsTab => 'Blocks';

  @override
  String get infocutterCurrentSiteTab => 'Site';

  @override
  String get infocutterWatchTab => 'Watch';

  @override
  String get infocutterEvidenceTab => 'Captures';

  @override
  String get infocutterSettingsTab => 'Settings';

  @override
  String get infocutterBlockShortTab => 'Block';

  @override
  String get infocutterTextShortTab => 'Text';

  @override
  String get infocutterAiShortTab => 'AI';

  @override
  String get infocutterTemplatesShortTab => 'Templates';

  @override
  String get infocutterDirectRemoveCategory => 'Remove manually';

  @override
  String get infocutterAutoRemoveCategory => 'Remove automatically';

  @override
  String get infocutterManageRemovedCategory => 'Manage removed items';

  @override
  String get infocutterAppSettingsCategory => 'Configure app';

  @override
  String get infocutterPickBlockRemoveTab => 'Pick a block on screen to remove';

  @override
  String get infocutterKeywordBlockRemoveTab =>
      'Remove blocks that contain text';

  @override
  String get infocutterNetworkRequestBlockTab => 'Block ad/tracker requests';

  @override
  String get infocutterWatchAutoRemoveTab => 'Hide when watch terms appear';

  @override
  String get infocutterAiRecommendRemoveTab =>
      'Let AI recommend items to remove';

  @override
  String get infocutterCurrentSiteRulesTab => 'Manage current site rules';

  @override
  String get infocutterImportRecommendedRulesTab => 'Import recommended rules';

  @override
  String get infocutterEvidenceRecordsViewTab => 'View capture records';

  @override
  String get infocutterGlobalSettingsTab => 'Turn Infocutter on/off';

  @override
  String get infocutterClosePanel => 'Close Infocutter panel';

  @override
  String get infocutterActiveProfile => 'Active profile';

  @override
  String get infocutterNoActiveProfile => 'No active profile';

  @override
  String get infocutterNoItemsYet => 'No items yet';

  @override
  String get infocutterWatchTargets => 'Watch targets';

  @override
  String get infocutterEvidenceRecords => 'Capture records';

  @override
  String get infocutterImportAndSettings => 'Import and settings';

  @override
  String get infocutterGlobalEnabled => 'Enable Infocutter globally';

  @override
  String get infocutterProfiles => 'Profiles';

  @override
  String infocutterProfilesCount(int count) {
    return '$count profiles';
  }

  @override
  String get infocutterCreateProfile => 'Create profile';

  @override
  String get infocutterProfileName => 'Profile name';

  @override
  String get infocutterMatchers => 'Matchers';

  @override
  String get infocutterEditMatchers => 'Edit matchers';

  @override
  String get infocutterRename => 'Rename';

  @override
  String get infocutterDelete => 'Delete';

  @override
  String get infocutterConfirmDeleteMessage =>
      'Delete this item? This cannot be undone.';

  @override
  String get infocutterImportJson => 'Import Chrome JSON';

  @override
  String get infocutterExportJson => 'Export Chrome JSON';

  @override
  String get infocutterExportCopied => 'Export JSON copied to clipboard';

  @override
  String get infocutterSave => 'Save';

  @override
  String get infocutterRuleActions => 'Rule actions';

  @override
  String get infocutterEditSelector => 'Edit selector';

  @override
  String get infocutterToggleRuleMode => 'Toggle hide/exception';

  @override
  String get infocutterFrameScope => 'Frame scope';

  @override
  String get infocutterMainFrame => 'Main frame';

  @override
  String get infocutterRuleModeHide => 'Hide';

  @override
  String get infocutterRuleModeUnhide => 'Exception';

  @override
  String get infocutterTemplates => 'Rule templates';

  @override
  String get infocutterImportTemplate => 'Import template';

  @override
  String infocutterTemplateImported(String name) {
    return '$name template imported';
  }

  @override
  String get infocutterWatchGlobalEnabled => 'Enable watch';

  @override
  String get infocutterWatchAutoMask => 'Auto-mask when detected';

  @override
  String get infocutterWatchTargetName => 'Watch target name';

  @override
  String get infocutterWatchAliases => 'Aliases (comma-separated)';

  @override
  String get infocutterAddWatchTarget => 'Add watch target';

  @override
  String get infocutterWatchDetections => 'Recent detections';

  @override
  String get infocutterCaptureEvidence => 'Save current page capture';

  @override
  String get infocutterNoEvidenceRecords => 'No capture records saved';

  @override
  String infocutterEvidenceCaptured(int sequence) {
    return 'Saved capture record #$sequence';
  }

  @override
  String get infocutterAiAutoMasking => 'AI auto masking';

  @override
  String get infocutterAiPendingDecision =>
      'App inclusion, privacy, and cost policy still need a product decision.';

  @override
  String infocutterAiConfigured(String model) {
    return '$model configured';
  }

  @override
  String get infocutterAiEndpoint => 'AI endpoint';

  @override
  String get infocutterAiModel => 'Model';

  @override
  String get infocutterAiApiKey => 'API key';

  @override
  String get infocutterAiSaveConfig => 'Save AI config';

  @override
  String get infocutterAiConfigSaved => 'AI config saved';

  @override
  String get infocutterAiResetHosts => 'Reset analyzed hosts';

  @override
  String infocutterAiAnalyzedHosts(int count) {
    return '$count analyzed hosts';
  }

  @override
  String get infocutterAiAnalyzeCurrentPage => 'Analyze current page with AI';

  @override
  String get infocutterAiAnalyzing => 'Analyzing';

  @override
  String get infocutterAiAnalyzeFailed => 'AI analysis failed';

  @override
  String get infocutterAiApplySuggestion => 'Apply suggestion';

  @override
  String infocutterAiSuggestions(int count) {
    return '$count AI suggestions';
  }

  @override
  String get infocutterTextBlocks => 'Text blocks';

  @override
  String get infocutterTextBlockGlobalEnabled => 'Enable text block hiding';

  @override
  String get infocutterTextBlockKeyword => 'Keyword';

  @override
  String get infocutterTextBlockObjectName => 'Object name';

  @override
  String get infocutterTextBlockMinMatchCount => 'Minimum repeats';

  @override
  String get infocutterTextBlockAddRule => 'Add text block rule';

  @override
  String get infocutterTextBlockProfileEnabled =>
      'Enable text rules for this site';

  @override
  String get infocutterCaptureKeyword => 'Grab keyword';

  @override
  String get infocutterNetworkFilters => 'Network filters';

  @override
  String get infocutterNetworkFilterGlobalEnabled => 'Enable network filters';

  @override
  String get infocutterNetworkFilterPaste => 'Paste ABP/uBlock network filters';

  @override
  String get infocutterNetworkFilterImport => 'Import filters';

  @override
  String infocutterNetworkFilterImportResult(int imported, int skipped) {
    return '$imported imported · $skipped skipped';
  }

  @override
  String get infocutterNetworkFilterAllowRule => 'Allow rule';

  @override
  String get infocutterNetworkFilterBlockRule => 'Block rule';

  @override
  String get infocutterRemove => 'Remove';

  @override
  String infocutterSavedCards(int count) {
    return '$count blocks';
  }

  @override
  String infocutterSavedRules(int count) {
    return '$count rules';
  }

  @override
  String infocutterEnabledRules(int count) {
    return '$count active hides';
  }

  @override
  String infocutterMatchCount(int count) {
    return '$count matches';
  }

  @override
  String get infocutterInvalidSelector => 'Invalid selector';

  @override
  String get infocutterSaveRule => 'Hide block';

  @override
  String get infocutterSessionPickHint =>
      'Click elements on the page to stage them';

  @override
  String infocutterStagedCount(int count) {
    return '$count staged';
  }

  @override
  String infocutterSessionApplyAll(int count) {
    return 'Apply all ($count)';
  }

  @override
  String get infocutterPickTab => 'Pick';

  @override
  String get infocutterHiddenListTab => 'Hidden list';

  @override
  String get infocutterTooBroadSelector => 'Hides the whole page';

  @override
  String get infocutterFixSelectorsToApply => 'Fix invalid selectors to apply';

  @override
  String get infocutterModulesTab => 'Modules';

  @override
  String get infocutterModulesHint =>
      'Turning a module off stops it on every site';

  @override
  String get infocutterBackupRestore => 'Backup / restore';

  @override
  String get infocutterExportRules => 'Export';

  @override
  String get infocutterImportRules => 'Import';

  @override
  String get infocutterRulesExported => 'Block rules copied to clipboard';

  @override
  String get infocutterRulesImported => 'Rules imported';

  @override
  String get infocutterImportPasteHint => 'Paste exported JSON';

  @override
  String get infocutterUndo => 'Undo';

  @override
  String get infocutterEvidenceCaptureFailed => 'Could not save page capture';

  @override
  String get infocutterImportReplaceWarning =>
      'Warning: importing replaces your saved rules';

  @override
  String get infocutterImportInvalid => 'Not a valid config bundle';

  @override
  String get infocutterAiPrompt => 'AI prompt';

  @override
  String get infocutterAiPromptHelp =>
      'Describe what to hide (the output format is handled automatically)';

  @override
  String infocutterAlreadyHiddenSection(int count) {
    return 'Already hidden ($count)';
  }

  @override
  String infocutterPickingNowSection(int count) {
    return 'Picking now ($count)';
  }

  @override
  String get infocutterAppliedEditsLiveHint =>
      'Edits here apply to the page immediately';

  @override
  String get infocutterDeleteRule => 'Delete rule';

  @override
  String get infocutterCardsManagedInPickTab =>
      'Edit this profile\'s cards in the 고르기 (Pick) tab';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsAdvancedSubtitle =>
      'Detailed WebView options. Most people never need these.';

  @override
  String get settingsDeveloperTools => 'Developer tools';

  @override
  String get onboardingTitle => 'Keep only what you want to see';

  @override
  String get onboardingPickBody =>
      'Tap the scissors next to the address bar, then pick what to hide. It stays hidden the next time you visit.';

  @override
  String get onboardingPeekBody =>
      'Turn on peek to reveal hidden parts for a moment. Rules are saved per site.';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get authUnsupportedTitle => 'Sign-in is not available in this browser';

  @override
  String get authUnsupportedBody =>
      'Google and some other services block sign-in from in-app browsers by policy. This is not an app error.';

  @override
  String get authOpenExternally => 'Open in default browser';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yForward => 'Forward';

  @override
  String get a11yReload => 'Reload';

  @override
  String get a11yMoreMenu => 'More options';

  @override
  String get a11yTabCount => 'Open tabs';

  @override
  String get a11yInfocutterPick => 'Pick element to hide';

  @override
  String get a11yActionBar => 'Browser toolbar';

  @override
  String get a11ySiteInfo => 'View site info';

  @override
  String get rendererCrashTitle => 'The page process stopped';

  @override
  String get rendererCrashBody =>
      'When the device runs low on memory, the system reclaims web page processes first. Close other apps and try again.';

  @override
  String get rendererCrashRetry => 'Try again';

  @override
  String get loadErrorTitle => 'Could not load this page';

  @override
  String get loadErrorBodyGeneric =>
      'A network error occurred, or the site could not be reached.';

  @override
  String get loadErrorTimeout =>
      'No response in time. Check the connection and try again.';

  @override
  String get loadErrorRetry => 'Try again';

  @override
  String get siteProtectionBypassTitle => 'Turn off protection on this site';

  @override
  String get siteProtectionBypassSubtitle =>
      'Temporarily disable hide, filters, and watch if they break the page';

  @override
  String get siteProtectionBypassActiveHint =>
      'Infocutter protection is off for this host.';

  @override
  String get networkFilterSubscribeUrl => 'Filter list URL';

  @override
  String get networkFilterSubscribeAction => 'Fetch from URL';

  @override
  String networkFilterSubscribeFailed(String error) {
    return 'Could not fetch filter list: $error';
  }

  @override
  String get jsDialogDefaultTitle => 'Page message';

  @override
  String get readerModeTitle => 'Reader mode';

  @override
  String get readerModeEmpty => 'Could not find readable text on this page.';

  @override
  String get readerModeFailed => 'Could not open reader mode.';

  @override
  String get menuReaderMode => 'Reader mode';

  @override
  String get pickerStopped => 'Selection mode ended';
}
