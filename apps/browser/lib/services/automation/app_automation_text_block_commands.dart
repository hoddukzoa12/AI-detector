part of '../app_automation_controller.dart';

/// `textBlock.*` command implementations, split out of
/// [_AppAutomationInfocutterCommands] to keep that file small.
extension _AppAutomationTextBlockCommands on _AppAutomationInfocutterCommands {
  Future<AppAutomationResult> setTextBlockCaptureMode(bool enabled) async {
    final tab = _requireCurrentTab();
    final controller = tab.webViewController;
    if (controller != null) {
      await setInfocutterKeywordCaptureActive(controller, active: enabled);
    }
    tab.infocutterKeywordCaptureActive.value = enabled;
    return AppAutomationResult.success(
      'textBlock.setCaptureMode',
      {'captureMode': enabled},
    );
  }

  Future<AppAutomationResult> setTextBlockGlobalEnabled(bool enabled) async {
    await _textBlocks.setGlobalEnabled(enabled);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success(
      'textBlock.global',
      {'enabled': enabled},
    );
  }

  Future<AppAutomationResult> addTextBlockRule({
    required String keyword,
    String objectName = '',
    int minMatchCount = 2,
  }) async {
    final url = _requireCurrentUri();
    final rule = await _textBlocks.addRuleForUrl(
      TextBlockRuleRequest(
        url: url,
        keyword: keyword,
        objectName: objectName,
        minMatchCount: minMatchCount,
      ),
    );
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('textBlock.addRule', {
      'id': rule.id,
      'keyword': rule.keyword,
      'objectName': rule.objectName,
      'url': url.toString(),
    });
  }

  Future<AppAutomationResult> listTextBlockRules() async {
    final profiles = _textBlocks.profiles
        .map((profile) => {
              'id': profile.id,
              'name': profile.name,
              'enabled': profile.enabled,
              'matchers': profile.matchers,
              'rules': profile.rules
                  .map((rule) => {
                        'id': rule.id,
                        'keyword': rule.keyword,
                        'enabled': rule.enabled,
                        'minMatchCount': rule.minMatchCount,
                        'objectName': rule.objectName,
                        'objectTags': rule.objectTags,
                      })
                  .toList(),
            })
        .toList();
    return AppAutomationResult.success('textBlock.listRules', {
      'profiles': profiles,
      'count': profiles.length,
    });
  }

  Future<AppAutomationResult> setTextBlockRuleEnabled({
    required String profileId,
    required String ruleId,
    required bool enabled,
  }) async {
    await _textBlocks.setRuleEnabled(profileId, ruleId, enabled);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('textBlock.setRuleEnabled', {
      'profileId': profileId,
      'ruleId': ruleId,
      'enabled': enabled,
    });
  }

  Future<AppAutomationResult> removeTextBlockRule({
    required String profileId,
    required String ruleId,
  }) async {
    final before = _textBlockRuleCount(profileId);
    await _textBlocks.removeRule(profileId, ruleId);
    final removed = _textBlockRuleCount(profileId) < before;
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('textBlock.removeRule', {
      'profileId': profileId,
      'ruleId': ruleId,
      'removed': removed,
    });
  }

  int _textBlockRuleCount(String profileId) {
    for (final profile in _textBlocks.profiles) {
      if (profile.id == profileId) return profile.rules.length;
    }
    return 0;
  }
}
