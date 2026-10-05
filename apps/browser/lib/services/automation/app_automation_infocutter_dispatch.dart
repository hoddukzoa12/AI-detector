part of '../app_automation_controller.dart';

/// `infocutter.*` action dispatch, split out of [AppAutomationController] to
/// keep the controller file small.
extension AppAutomationInfocutterDispatch on AppAutomationController {
  /// Dispatch for `infocutter.*` actions (block rules + the multi-select
  /// session). Split out of `_run` to keep each dispatcher small.
  Future<AppAutomationResult> _runInfocutterAction(
    String action,
    _AutomationArgs automationArgs,
  ) async {
    final result = _runInfocutterPanelAction(action, automationArgs) ??
        _runInfocutterSessionAction(action, automationArgs) ??
        _runInfocutterProfileAction(action, automationArgs);
    if (result == null) {
      throw ArgumentError.value(action, 'action', 'unsupported action');
    }
    return result;
  }

  /// Dispatch for the global toggle, panel and single-element pick
  /// `infocutter.*` actions. Returns null when unmatched.
  Future<AppAutomationResult>? _runInfocutterPanelAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'infocutter.global':
        return _infocutterCommands.setInfocutterGlobalEnabled(
          automationArgs.requiredBool('enabled'),
        );
      case 'infocutter.addBlockRule':
        return _infocutterCommands.addBlockRule(
          selector: automationArgs.requiredString('selector'),
          cardName:
              automationArgs.rawStringArg('cardName') ?? 'AI selected blocks',
          frameScope: automationArgs.stringArg('frameScope'),
        );
      case 'infocutter.openPanel':
        return _infocutterCommands.openInfocutterPanel(
          InfocutterPanelMode.values.byName(
            automationArgs.requiredString('mode'),
          ),
        );
      case 'infocutter.pick':
        return _infocutterCommands.pickElement(
          automationArgs.requiredString('selector'),
        );
      default:
        return null;
    }
  }

  /// Dispatch for the multi-select `infocutter.session.*` actions. Returns
  /// null when unmatched.
  Future<AppAutomationResult>? _runInfocutterSessionAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'infocutter.session.add':
        return _infocutterCommands.addToSession(
          automationArgs.requiredString('selector'),
          name: automationArgs.stringArg('name'),
          toggle: automationArgs.boolArg('toggle', fallback: true),
        );
      case 'infocutter.session.remove':
        return _infocutterCommands.removeFromSession(
          automationArgs.requiredString('cardId'),
        );
      case 'infocutter.session.refine':
        return _infocutterCommands.refineSessionCard(
          automationArgs.requiredString('cardId'),
          automationArgs.requiredString('selector'),
        );
      case 'infocutter.session.setDepth':
        return _infocutterCommands.setSessionCardDepth(
          automationArgs.requiredString('cardId'),
          automationArgs.requiredInt('index'),
        );
      case 'infocutter.session.rename':
        return _infocutterCommands.renameSessionCard(
          automationArgs.requiredString('cardId'),
          automationArgs.requiredString('name'),
        );
      case 'infocutter.session.clear':
        return _infocutterCommands.clearSession();
      case 'infocutter.session.apply':
        return _infocutterCommands.applySession();
      default:
        return null;
    }
  }

  /// Dispatch for the stored block-rule, card and profile `infocutter.*`
  /// actions. Returns null when unmatched.
  Future<AppAutomationResult>? _runInfocutterProfileAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'infocutter.importTemplate':
        return _infocutterCommands.importTemplate(
          automationArgs.requiredString('slug'),
        );
      case 'infocutter.listProfiles':
        return _infocutterCommands.listProfiles();
      case 'infocutter.removeRule':
        return _infocutterCommands.removeBlockRule(
          profileId: automationArgs.requiredString('profileId'),
          cardId: automationArgs.requiredString('cardId'),
          selector: automationArgs.requiredString('selector'),
        );
      case 'infocutter.setCardEnabled':
        return _infocutterCommands.setBlockCardEnabled(
          profileId: automationArgs.requiredString('profileId'),
          cardId: automationArgs.requiredString('cardId'),
          enabled: automationArgs.requiredBool('enabled'),
        );
      case 'infocutter.setProfileEnabled':
        return _infocutterCommands.setBlockProfileEnabled(
          profileId: automationArgs.requiredString('profileId'),
          enabled: automationArgs.requiredBool('enabled'),
        );
      case 'infocutter.removeProfile':
        return _infocutterCommands.removeProfile(
          automationArgs.requiredString('profileId'),
        );
      default:
        return null;
    }
  }
}
