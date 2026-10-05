import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/models.dart';

/// Presentation-layer glue that runs a block-rule mutation on the repository
/// and then fires onRulesChanged (live JS re-apply, no reload). Shared by the
/// 「고르기」 applied-cards section and the 「숨긴 목록」 rule manager so both edit
/// paths behave identically.
class InfocutterStoredRuleActions {
  const InfocutterStoredRuleActions({
    required this.onPreviewRule,
    required this.repository,
    required this.onRulesChanged,
  });

  final Future<void> Function(StoredRule rule)? onPreviewRule;
  final BlockRuleRepository repository;
  final Future<void> Function()? onRulesChanged;

  bool get canPreviewRule => onPreviewRule != null;

  Future<void> previewRule(StoredRule rule) async {
    await onPreviewRule?.call(rule);
  }

  Future<void> createProfile({
    required String name,
    required List<String> matchers,
  }) =>
      _run(() => repository.upsertProfile(name: name, matchers: matchers));

  Future<void> deleteProfile(String profileId) =>
      _run(() => repository.deleteProfile(profileId));

  Future<void> importChromeJson(String raw) =>
      _run(() => repository.importChromeJson(raw));

  Future<void> removeCard({
    required String profileId,
    required String cardId,
  }) =>
      _run(() => repository.removeCard(profileId: profileId, cardId: cardId));

  Future<void> removeStoredRule({
    required String profileId,
    required StoredRule targetRule,
  }) =>
      _run(() => repository.removeStoredRule(
            profileId: profileId,
            targetRule: targetRule,
          ));

  Future<void> renameCard({
    required String profileId,
    required String cardId,
    required String cardName,
  }) =>
      _run(() => repository.renameCard(
            profileId: profileId,
            cardId: cardId,
            cardName: cardName,
          ));

  Future<void> renameProfile(String profileId, String name) =>
      _run(() => repository.renameProfile(profileId, name));

  Future<void> setCardEnabled({
    required String profileId,
    required String cardId,
    required bool enabled,
  }) =>
      _run(() => repository.setCardEnabled(
            profileId: profileId,
            cardId: cardId,
            enabled: enabled,
          ));

  Future<void> setGlobalEnabled(bool value) =>
      _run(() => repository.setGlobalEnabled(value));

  Future<void> setProfileEnabled(String profileId, bool enabled) =>
      _run(() => repository.setProfileEnabled(profileId, enabled));

  Future<void> setProfileMatchers(String profileId, List<String> matchers) =>
      _run(() => repository.setProfileMatchers(profileId, matchers));

  Future<void> updateStoredRule({
    required String profileId,
    required StoredRule targetRule,
    String? selector,
    RuleMode? mode,
    String? frameScope,
  }) =>
      _run(() => repository.updateStoredRule(
            profileId: profileId,
            targetRule: targetRule,
            selector: selector,
            mode: mode,
            frameScope: frameScope,
          ));

  Future<void> _run(Future<void> Function() mutation) async {
    await mutation();
    await onRulesChanged?.call();
  }
}
