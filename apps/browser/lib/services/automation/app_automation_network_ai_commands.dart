part of '../app_automation_controller.dart';

/// `network.*`, `ai.*` and `evidence.*` command implementations, split out
/// of [_AppAutomationInfocutterCommands] to keep that file small.
extension _AppAutomationNetworkAiCommands on _AppAutomationInfocutterCommands {
  Future<AppAutomationResult> setNetworkFilterGlobalEnabled(
    bool enabled,
  ) async {
    await _networkFilters.setGlobalEnabled(enabled);
    return AppAutomationResult.success(
      'network.global',
      {'enabled': enabled},
    );
  }

  Future<AppAutomationResult> importNetworkFilters(String rawList) async {
    final summary = await _networkFilters.importRawList(rawList);
    return AppAutomationResult.success('network.importFilters', {
      'imported': summary.imported,
      'skipped': summary.skipped,
    });
  }

  Future<AppAutomationResult> listNetworkRules() async {
    final rules = _networkFilters.rules.map((rule) => rule.toJson()).toList();
    return AppAutomationResult.success('network.listRules', {
      'rules': rules,
      'count': rules.length,
    });
  }

  Future<AppAutomationResult> setNetworkRuleEnabled({
    required String id,
    required bool enabled,
  }) async {
    await _networkFilters.setRuleEnabled(id, enabled);
    return AppAutomationResult.success('network.setRuleEnabled', {
      'id': id,
      'enabled': enabled,
    });
  }

  Future<AppAutomationResult> removeNetworkRule(String id) async {
    final before = _networkFilters.rules.length;
    await _networkFilters.removeRule(id);
    final removed = _networkFilters.rules.length < before;
    return AppAutomationResult.success('network.removeRule', {
      'id': id,
      'removed': removed,
    });
  }

  Future<AppAutomationResult> saveAiConfig({
    required String model,
    String? endpoint,
    String? apiKey,
    String? prompt,
  }) async {
    final current = _aiConfig.snapshot;
    await _aiConfig.saveConfig(
      endpoint: endpoint ?? current.endpoint,
      apiKey: apiKey ?? current.apiKey,
      model: model,
      prompt: prompt,
    );
    return AppAutomationResult.success('ai.config', {
      'endpoint': _aiConfig.snapshot.endpoint,
      'model': _aiConfig.snapshot.model,
      'prompt': _aiConfig.snapshot.prompt,
      'configured': _aiConfig.isConfigured,
    });
  }

  Future<AppAutomationResult> listAiSuggestions({String? host}) async {
    final resolvedHost = (host ?? _currentUri()?.host ?? '').toLowerCase();
    final suggestions = _aiRules
        .rulesForHost(resolvedHost)
        .map((rule) => {
              'id': rule.id,
              'selector': rule.selector,
              'label': rule.label,
              'reason': rule.reason,
              'confidence': rule.confidence,
              'applied': rule.applied,
              'appliedAt': rule.appliedAt?.toIso8601String(),
              'host': rule.host,
              'url': rule.url,
            })
        .toList();
    return AppAutomationResult.success('ai.listSuggestions', {
      'host': resolvedHost,
      'suggestions': suggestions,
      'count': suggestions.length,
    });
  }

  Future<AppAutomationResult> applyAiSuggestion({
    required String selector,
  }) async {
    final url = _requireCurrentUri();
    final host = url.host.toLowerCase();
    final normalizedSelector = selector.trim();
    final rule = await _savePickedBlockRule(
      SavePickedBlockRuleCommand(
        url: url,
        selector: normalizedSelector,
        cardName: 'AI suggestions',
      ),
    );
    await _aiRules.markAppliedForSelector(
      host: host,
      selector: normalizedSelector,
    );
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('ai.applySuggestion', {
      'selector': rule.selector,
      'cardId': rule.cardId,
      'profileId': _profileIdForRule(rule),
      'host': host,
    });
  }

  Future<AppAutomationResult> captureEvidence() async {
    final tab = _requireCurrentTab();
    final url = _requireCurrentUri();
    final controller = _requireCurrentController();
    final html = await controller.getHtml() ?? '';
    final Uint8List? pngBytes = await controller.takeScreenshot();
    final record = await _evidence.captureHtmlSnapshot(
      EvidenceCaptureRequest(
        url: url,
        pageTitle: tab.title ?? '',
        html: html,
        pngBytes: pngBytes,
      ),
    );
    return AppAutomationResult.success('evidence.capture', {
      'id': record.id,
      'sequence': record.sequence,
      'url': record.url,
      'htmlFilename': record.htmlFilename,
      'pngFilename': record.pngFilename,
      'pdfFilename': record.pdfFilename,
    });
  }
}
