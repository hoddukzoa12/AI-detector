part of '../app_automation_controller.dart';

/// `textBlock.*`, `watch.*`, `network.*`, `ai.*` and `evidence.*` action
/// dispatch, split out of [AppAutomationController] to keep the controller
/// file small.
extension AppAutomationContentDispatch on AppAutomationController {
  /// Dispatch for the remaining content modules: text blocks, watch targets,
  /// network filters, AI suggestions and evidence capture.
  Future<AppAutomationResult> _runContentAction(
    String action,
    _AutomationArgs automationArgs,
  ) async {
    final result = _runTextBlockAction(action, automationArgs) ??
        _runWatchAction(action, automationArgs) ??
        _runNetworkAction(action, automationArgs) ??
        _runAiAction(action, automationArgs);
    if (result == null) {
      throw ArgumentError.value(action, 'action', 'unsupported action');
    }
    return result;
  }

  /// Dispatch for the `textBlock.*` actions. Returns null when unmatched.
  Future<AppAutomationResult>? _runTextBlockAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'textBlock.global':
        return _infocutterCommands.setTextBlockGlobalEnabled(
          automationArgs.requiredBool('enabled'),
        );
      case 'textBlock.setCaptureMode':
        return _infocutterCommands.setTextBlockCaptureMode(
          automationArgs.requiredBool('enabled'),
        );
      case 'textBlock.addRule':
        return _infocutterCommands.addTextBlockRule(
          keyword: automationArgs.requiredString('keyword'),
          objectName: automationArgs.stringArg('objectName') ?? '',
          minMatchCount: automationArgs.intArg('minMatchCount') ?? 2,
        );
      case 'textBlock.listRules':
        return _infocutterCommands.listTextBlockRules();
      case 'textBlock.setRuleEnabled':
        return _infocutterCommands.setTextBlockRuleEnabled(
          profileId: automationArgs.requiredString('profileId'),
          ruleId: automationArgs.requiredString('ruleId'),
          enabled: automationArgs.requiredBool('enabled'),
        );
      case 'textBlock.removeRule':
        return _infocutterCommands.removeTextBlockRule(
          profileId: automationArgs.requiredString('profileId'),
          ruleId: automationArgs.requiredString('ruleId'),
        );
      default:
        return null;
    }
  }

  /// Dispatch for the `watch.*` actions. Returns null when unmatched.
  Future<AppAutomationResult>? _runWatchAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'watch.global':
        return _infocutterCommands.setWatchGlobalEnabled(
          automationArgs.requiredBool('enabled'),
        );
      case 'watch.autoMask':
        return _infocutterCommands.setWatchAutoMask(
          automationArgs.requiredBool('enabled'),
        );
      case 'watch.addTarget':
        return _infocutterCommands.addWatchTarget(
          name: automationArgs.requiredString('name'),
          aliases: automationArgs.stringListArg('aliases'),
        );
      case 'watch.listTargets':
        return _infocutterCommands.listWatchTargets();
      case 'watch.listDetections':
        return _infocutterCommands.listWatchDetections();
      case 'watch.setTargetEnabled':
        return _infocutterCommands.setWatchTargetEnabled(
          id: automationArgs.requiredString('id'),
          enabled: automationArgs.requiredBool('enabled'),
        );
      case 'watch.removeTarget':
        return _infocutterCommands.removeWatchTarget(
          automationArgs.requiredString('id'),
        );
      default:
        return null;
    }
  }

  /// Dispatch for the `network.*` filter actions. Returns null when unmatched.
  Future<AppAutomationResult>? _runNetworkAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'network.global':
        return _infocutterCommands.setNetworkFilterGlobalEnabled(
          automationArgs.requiredBool('enabled'),
        );
      case 'network.importFilters':
        return _infocutterCommands.importNetworkFilters(
          automationArgs.requiredString('rawList'),
        );
      case 'network.listRules':
        return _infocutterCommands.listNetworkRules();
      case 'network.setRuleEnabled':
        return _infocutterCommands.setNetworkRuleEnabled(
          id: automationArgs.requiredString('id'),
          enabled: automationArgs.requiredBool('enabled'),
        );
      case 'network.removeRule':
        return _infocutterCommands.removeNetworkRule(
          automationArgs.requiredString('id'),
        );
      default:
        return null;
    }
  }

  /// Dispatch for the `ai.*` suggestion actions and evidence capture. Returns
  /// null when unmatched.
  Future<AppAutomationResult>? _runAiAction(
    String action,
    _AutomationArgs automationArgs,
  ) {
    switch (action) {
      case 'ai.config':
        return _infocutterCommands.saveAiConfig(
          endpoint: automationArgs.stringArg('endpoint'),
          apiKey: automationArgs.stringArg('apiKey'),
          model: automationArgs.requiredString('model'),
          prompt: automationArgs.stringArg('prompt'),
        );
      case 'ai.listSuggestions':
        return _infocutterCommands.listAiSuggestions(
          host: automationArgs.stringArg('host'),
        );
      case 'ai.applySuggestion':
        return _infocutterCommands.applyAiSuggestion(
          selector: automationArgs.requiredString('selector'),
        );
      case 'evidence.capture':
        return _infocutterCommands.captureEvidence();
      default:
        return null;
    }
  }
}
