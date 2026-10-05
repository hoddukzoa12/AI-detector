import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/selection_session_controller.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';

/// Staging metadata for a picked element: the depth ladder the sidebar offers
/// and the ordered alternative selectors its "다음 기준" cycles through.
StageOptions stageOptionsForPickerResult(PickerResult result) {
  final depthOptions = result.depthTargets.length > 1
      ? result.depthTargets
          .map((t) => CardDepthOption(
                label: t.label,
                selector: t.selector,
                matchCount: t.matchCount,
                alternatives: t.selectorCandidates,
              ))
          .toList()
      : const <CardDepthOption>[];
  return StageOptions(
    frameScope: result.frameScope,
    alternatives: alternativeSelectorsFor(result),
    depthOptions: depthOptions,
    depthIndex: depthOptions.isEmpty
        ? 0
        : result.selectedDepthIndex.clamp(0, depthOptions.length - 1),
  );
}

/// Ordered, de-duplicated candidate selectors for the picked element. Order
/// matters: the sidebar's "다음 기준" cycles through this list, so keep the
/// picker's preferred selector first and dedupe without reordering.
List<String> alternativeSelectorsFor(PickerResult result) {
  final seen = <String>{};
  final ordered = <String>[];
  for (final value in [
    result.selector,
    ...result.selectorCandidates,
    ...result.alternatives,
  ]) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed)) {
      ordered.add(trimmed);
    }
  }
  return ordered;
}

/// Remove [rules] from whichever profile currently holds them.
Future<void> removeAppliedBlockRules({
  required List<StoredRule> rules,
  required InfocutterService infocutter,
  required BlockRuleRepository repository,
}) async {
  for (final rule in rules) {
    final profileId = profileIdForStoredRule(infocutter, rule);
    if (profileId == null) continue;
    // One rule that's already gone (removed via the UI) must not abort the
    // rest of the undo.
    try {
      await repository.removeStoredRule(
        profileId: profileId,
        targetRule: rule,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[infocutter] undo remove failed: $error');
      }
    }
  }
}

String? profileIdForStoredRule(InfocutterService infocutter, StoredRule rule) {
  for (final profile in infocutter.profiles) {
    // Full-identity match (not just cardId+selector) so undo can't target a
    // different pre-existing rule that happens to share a selector.
    if (profile.rules.any((r) => isSameStoredRule(r, rule))) {
      return profile.id;
    }
  }
  return null;
}
