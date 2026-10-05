import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/ai_config_service.dart';
import 'package:infocutter_app/infocutter/ai_masking_candidate_collector.dart';
import 'package:infocutter_app/infocutter/ai_rule_service.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/template_catalog.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/util.dart';

part 'app_automation_args.dart';
part 'app_automation_browser_commands.dart';
part 'app_automation_infocutter_commands.dart';
part 'app_automation_infocutter_session_commands.dart';
part 'app_automation_snapshot_builder.dart';
part 'automation/app_automation_browser_dispatch.dart';
part 'automation/app_automation_content_dispatch.dart';
part 'automation/app_automation_infocutter_dispatch.dart';
part 'automation/app_automation_network_ai_commands.dart';
part 'automation/app_automation_text_block_commands.dart';
part 'automation/app_automation_watch_commands.dart';

class AppAutomationResult {
  const AppAutomationResult({
    required this.action,
    required this.ok,
    this.data = const {},
    this.error,
    this.code,
  });

  final String action;
  final bool ok;
  final Map<String, Object?> data;
  final String? error;

  /// Stable, machine-readable failure code (e.g. `no_current_tab`,
  /// `unsupported_action`). Null on success.
  final String? code;

  Map<String, Object?> toJson() => {
        'action': action,
        'ok': ok,
        if (error != null) 'error': error,
        if (code != null) 'code': code,
        ...data,
      };

  static AppAutomationResult success(
    String action, [
    Map<String, Object?> data = const {},
  ]) =>
      AppAutomationResult(action: action, ok: true, data: data);

  static AppAutomationResult failure(String action, Object error) =>
      AppAutomationResult(
        action: action,
        ok: false,
        error: error.toString(),
        code: _codeForError(error),
      );

  /// Derives a stable failure [code] from the thrown [error]'s type and
  /// message, preferring type inspection over brittle full-string matching.
  static String _codeForError(Object error) {
    // RangeError extends ArgumentError, so it must be checked first.
    if (error is RangeError) return 'out_of_range';
    if (error is ArgumentError) {
      final message = error.message?.toString().toLowerCase() ?? '';
      if (message.contains('unsupported action')) return 'unsupported_action';
      return 'invalid_arg';
    }
    if (error is StateError) {
      final message = error.message.toLowerCase();
      if (message.contains('no current tab')) return 'no_current_tab';
      if (message.contains('controller')) return 'no_controller';
      if (message.contains('url with host')) return 'no_url';
    }
    return 'error';
  }
}

class AppAutomationController {
  AppAutomationController({
    required BrowserModel browser,
    required WindowModel window,
    required InfocutterService infocutter,
    required WatchService watch,
    required EvidenceService evidence,
    required TextBlockService textBlocks,
    required NetworkFilterService networkFilters,
    required AiConfigService aiConfig,
    required AiRuleService aiRules,
    required SavePickedBlockRuleUseCase savePickedBlockRule,
  })  : _browserCommands = _AppAutomationBrowserCommands(
          browser: browser,
          window: window,
        ),
        _infocutterCommands = _AppAutomationInfocutterCommands(
          window: window,
          infocutter: infocutter,
          savePickedBlockRule: savePickedBlockRule,
          watch: watch,
          evidence: evidence,
          textBlocks: textBlocks,
          networkFilters: networkFilters,
          aiConfig: aiConfig,
          aiRules: aiRules,
        ),
        _snapshotBuilder = _AppAutomationSnapshotBuilder(
          browser: browser,
          window: window,
          infocutter: infocutter,
          watch: watch,
          evidence: evidence,
          textBlocks: textBlocks,
          networkFilters: networkFilters,
          aiConfig: aiConfig,
          aiRules: aiRules,
        );

  final _AppAutomationBrowserCommands _browserCommands;
  final _AppAutomationInfocutterCommands _infocutterCommands;
  final _AppAutomationSnapshotBuilder _snapshotBuilder;

  static const _browserCapabilities = [
    'state.read',
    'tab.open',
    'tab.select',
    'tab.close',
    'tab.closeAll',
    'page.load',
    'page.back',
    'page.forward',
    'page.reload',
    'page.stop',
    'page.home',
    'page.find',
    'page.findNext',
    'page.clearFind',
    'page.evalJs',
    'page.screenshot',
    'page.click',
    'page.fill',
    'page.getText',
    'page.candidates',
    'page.waitForSelector',
    'page.waitForLoad',
    'cookie.list',
    'cookie.get',
    'cookie.set',
    'cookie.delete',
    'browser.clearData',
  ];

  static const _infocutterCapabilities = [
    'infocutter.global',
    'infocutter.openPanel',
    'infocutter.pick',
    'infocutter.session.add',
    'infocutter.session.remove',
    'infocutter.session.refine',
    'infocutter.session.setDepth',
    'infocutter.session.rename',
    'infocutter.session.clear',
    'infocutter.session.apply',
    'infocutter.addBlockRule',
    'infocutter.importTemplate',
    'infocutter.listProfiles',
    'infocutter.removeRule',
    'infocutter.setCardEnabled',
    'infocutter.setProfileEnabled',
    'infocutter.removeProfile',
  ];

  static const _contentCapabilities = [
    'textBlock.global',
    'textBlock.setCaptureMode',
    'textBlock.addRule',
    'textBlock.listRules',
    'textBlock.setRuleEnabled',
    'textBlock.removeRule',
    'watch.global',
    'watch.autoMask',
    'watch.addTarget',
    'watch.listTargets',
    'watch.listDetections',
    'watch.setTargetEnabled',
    'watch.removeTarget',
    'network.global',
    'network.importFilters',
    'network.listRules',
    'network.setRuleEnabled',
    'network.removeRule',
    'ai.config',
    'ai.listSuggestions',
    'ai.applySuggestion',
    'evidence.capture',
  ];

  static const capabilities = [
    ..._browserCapabilities,
    ..._infocutterCapabilities,
    ..._contentCapabilities,
  ];

  Map<String, Object?> snapshot() => _snapshotBuilder.build(capabilities);

  Future<AppAutomationResult> run(
    String action, [
    Map<String, Object?> args = const {},
  ]) async {
    try {
      return await _run(action, args);
    } catch (error) {
      return AppAutomationResult.failure(action, error);
    }
  }

  Future<AppAutomationResult> _run(
    String action,
    Map<String, Object?> args,
  ) async {
    final automationArgs = _AutomationArgs(args);
    if (action == 'state.read') {
      return AppAutomationResult.success(action, snapshot());
    }
    final browserResult = _runTabAction(action, automationArgs) ??
        _runPageAction(action, automationArgs) ??
        _runCookieAction(action, automationArgs);
    if (browserResult != null) {
      return browserResult;
    }
    if (action.split('.').first == 'infocutter') {
      return _runInfocutterAction(action, automationArgs);
    }
    return _runContentAction(action, automationArgs);
  }
}

WebUri normalizeAutomationTarget(
  String target,
  BrowserSettings settings,
) {
  final trimmed = target.trim();
  var url = WebUri(trimmed);
  if (Util.isLocalizedContent(url) ||
      (url.isValidUri && url.toString().split('.').length > 1)) {
    return url.scheme.isEmpty ? WebUri('https://$url') : url;
  }
  return WebUri(settings.searchEngine.searchUrl + Uri.encodeComponent(trimmed));
}

WebUri normalizeTarget(String target, BrowserSettings settings) {
  return normalizeAutomationTarget(target, settings);
}
