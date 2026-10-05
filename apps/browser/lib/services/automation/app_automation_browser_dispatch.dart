part of '../app_automation_controller.dart';

/// `tab.*`, `page.*`, `cookie.*` and `browser.*` action dispatch, split out of
/// [AppAutomationController] to keep the controller file small.
extension AppAutomationBrowserDispatch on AppAutomationController {
  /// Dispatch for `tab.*` actions. Returns null when [action] belongs to
  /// another namespace so `_run` can keep trying the next dispatcher.
  Future<AppAutomationResult>? _runTabAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'tab.open':
        return _browserCommands.openTab(
          automationArgs.requiredString('target'),
          incognito: automationArgs.boolArg('incognito'),
        );
      case 'tab.select':
        return _browserCommands.selectTab(automationArgs.requiredInt('index'));
      case 'tab.close':
        return _browserCommands.closeTab(automationArgs.requiredInt('index'));
      case 'tab.closeAll':
        return _browserCommands.closeAllTabs();
      default:
        return null;
    }
  }

  /// Dispatch for `page.*` actions: navigation, find, scripting and the
  /// selector-driven interactions. Returns null when unmatched.
  Future<AppAutomationResult>? _runPageAction(
    String action,
    _AutomationArgs automationArgs,
  ) =>
      _runPageNavigationAction(action, automationArgs) ??
      _runPageInteractionAction(action, automationArgs);

  /// Dispatch for the history/navigation and in-page find `page.*` actions.
  /// Returns null when unmatched.
  Future<AppAutomationResult>? _runPageNavigationAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'page.load':
        return _browserCommands.loadCurrent(
          automationArgs.requiredString('target'),
        );
      case 'page.back':
        return _browserCommands.goBack();
      case 'page.forward':
        return _browserCommands.goForward();
      case 'page.reload':
        return _browserCommands.reload();
      case 'page.stop':
        return _browserCommands.stopLoading();
      case 'page.home':
        return _browserCommands.goHome();
      case 'page.find':
        return _browserCommands.findOnPage(
          automationArgs.requiredString('text'),
        );
      case 'page.findNext':
        return _browserCommands.findNext(
          forward: automationArgs.boolArg('forward', fallback: true),
        );
      case 'page.clearFind':
        return _browserCommands.clearFind();
      default:
        return null;
    }
  }

  /// Dispatch for the scripting, capture, selector interaction and wait
  /// `page.*` actions. Returns null when unmatched.
  Future<AppAutomationResult>? _runPageInteractionAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'page.evalJs':
        return _browserCommands.evaluateJavascript(
          automationArgs.requiredString('source'),
        );
      case 'page.screenshot':
        return _browserCommands.takeScreenshot();
      case 'page.click':
        return _browserCommands.clickSelector(
          automationArgs.requiredString('selector'),
        );
      case 'page.fill':
        return _browserCommands.fillSelector(
          automationArgs.requiredString('selector'),
          automationArgs.stringArg('value') ?? '',
        );
      case 'page.getText':
        return _browserCommands.getText(
          automationArgs.requiredString('selector'),
        );
      case 'page.candidates':
        return _browserCommands.pageCandidates();
      case 'page.waitForSelector':
        return _browserCommands.waitForSelector(
          automationArgs.requiredString('selector'),
          timeoutMs: automationArgs.intArg('timeoutMs') ?? 5000,
        );
      case 'page.waitForLoad':
        return _browserCommands.waitForLoad(
          timeoutMs: automationArgs.intArg('timeoutMs') ?? 15000,
        );
      default:
        return null;
    }
  }

  /// Dispatch for `cookie.*` and `browser.*` storage actions. Returns null
  /// when unmatched.
  Future<AppAutomationResult>? _runCookieAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'cookie.list':
        return _browserCommands.cookieList(automationArgs.stringArg('url'));
      case 'cookie.get':
        return _browserCommands.cookieGet(
          automationArgs.stringArg('url'),
          automationArgs.requiredString('name'),
        );
      case 'cookie.set':
        return _browserCommands.cookieSet(
          name: automationArgs.requiredString('name'),
          value: automationArgs.rawStringArg('value') ?? '',
          attributes: CookieAttributes(
            urlArg: automationArgs.stringArg('url'),
            domain: automationArgs.stringArg('domain'),
            path: automationArgs.stringArg('path'),
            isSecure: automationArgs._values['isSecure'] is bool
                ? automationArgs._values['isSecure'] as bool
                : null,
            isHttpOnly: automationArgs._values['isHttpOnly'] is bool
                ? automationArgs._values['isHttpOnly'] as bool
                : null,
          ),
        );
      case 'cookie.delete':
        return _browserCommands.cookieDelete(
          automationArgs.stringArg('url'),
          automationArgs.requiredString('name'),
        );
      case 'browser.clearData':
        return _browserCommands.clearBrowserData(
          cookies: automationArgs.boolArg('cookies', fallback: true),
          cache: automationArgs.boolArg('cache', fallback: true),
          storage: automationArgs.boolArg('storage', fallback: true),
        );
      default:
        return null;
    }
  }
}
