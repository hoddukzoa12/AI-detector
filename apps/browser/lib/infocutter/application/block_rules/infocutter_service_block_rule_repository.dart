import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/template_catalog.dart';

class InfocutterServiceBlockRuleRepository implements BlockRuleRepository {
  const InfocutterServiceBlockRuleRepository(this._service);

  final InfocutterService _service;

  @override
  void addListener(VoidCallback listener) {
    _service.addListener(listener);
  }

  @override
  bool get globalEnabled => _service.globalEnabled;

  @override
  List<RuleProfile> get profiles => _service.profiles;

  @override
  Future<StoredRule> addPickedRuleForUrl({
    required Uri url,
    required String selector,
    String cardName = 'Picked elements',
    String? frameScope,
  }) {
    return _service.addPickedRuleForUrl(
      url: url,
      selector: selector,
      cardName: cardName,
      frameScope: frameScope,
    );
  }

  @override
  ActiveSiteState buildActiveSiteState(Uri url) {
    return _service.buildActiveSiteState(url);
  }

  @override
  Future<void> deleteProfile(String profileId) {
    return _service.deleteProfile(profileId);
  }

  @override
  String exportChromeJson() => _service.exportChromeJson();

  @override
  Future<void> importChromeJson(String raw) {
    return _service.importChromeJson(raw);
  }

  @override
  Future<RuleProfile> importTemplate(InfocutterTemplate template) {
    return _service.importTemplate(template);
  }

  @override
  void removeListener(VoidCallback listener) {
    _service.removeListener(listener);
  }

  @override
  Future<RuleProfile?> removeCard({
    required String profileId,
    required String cardId,
  }) {
    return _service.removeCard(profileId: profileId, cardId: cardId);
  }

  @override
  Future<void> removeStoredRule({
    required String profileId,
    required StoredRule targetRule,
  }) {
    return _service.removeStoredRule(
      profileId: profileId,
      targetRule: targetRule,
    );
  }

  @override
  Future<RuleProfile?> renameCard({
    required String profileId,
    required String cardId,
    required String cardName,
  }) {
    return _service.renameCard(
      profileId: profileId,
      cardId: cardId,
      cardName: cardName,
    );
  }

  @override
  Future<RuleProfile?> renameProfile(String profileId, String name) {
    return _service.renameProfile(profileId, name);
  }

  @override
  Future<RuleProfile?> setCardEnabled({
    required String profileId,
    required String cardId,
    required bool enabled,
  }) {
    return _service.setCardEnabled(
      profileId: profileId,
      cardId: cardId,
      enabled: enabled,
    );
  }

  @override
  Future<void> setGlobalEnabled(bool value) {
    return _service.setGlobalEnabled(value);
  }

  @override
  Future<RuleProfile?> setProfileEnabled(String profileId, bool enabled) {
    return _service.setProfileEnabled(profileId, enabled);
  }

  @override
  Future<RuleProfile?> setProfileMatchers(
    String profileId,
    List<String> matchers,
  ) {
    return _service.setProfileMatchers(profileId, matchers);
  }

  @override
  Future<RuleProfile> upsertProfile({
    required String name,
    String? id,
    bool enabled = true,
    List<String> matchers = const [],
    String? sourceTemplateSlug,
  }) {
    return _service.upsertProfile(
      name: name,
      id: id,
      enabled: enabled,
      matchers: matchers,
      sourceTemplateSlug: sourceTemplateSlug,
    );
  }

  @override
  Future<RuleProfile?> updateStoredRule({
    required String profileId,
    required StoredRule targetRule,
    String? selector,
    RuleMode? mode,
    String? frameScope,
  }) {
    return _service.updateStoredRule(
      profileId: profileId,
      targetRule: targetRule,
      selector: selector,
      mode: mode,
      frameScope: frameScope,
    );
  }
}
