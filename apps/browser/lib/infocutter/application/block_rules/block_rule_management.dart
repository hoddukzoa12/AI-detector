import 'package:infocutter_app/infocutter/models.dart';

abstract interface class BlockRuleManagement {
  Future<void> deleteProfile(String profileId);

  Future<RuleProfile?> removeCard({
    required String profileId,
    required String cardId,
  });

  Future<void> removeStoredRule({
    required String profileId,
    required StoredRule targetRule,
  });

  Future<RuleProfile?> renameCard({
    required String profileId,
    required String cardId,
    required String cardName,
  });

  Future<RuleProfile?> renameProfile(String profileId, String name);

  Future<RuleProfile?> setCardEnabled({
    required String profileId,
    required String cardId,
    required bool enabled,
  });

  Future<void> setGlobalEnabled(bool value);

  Future<RuleProfile?> setProfileEnabled(String profileId, bool enabled);

  Future<RuleProfile?> setProfileMatchers(
    String profileId,
    List<String> matchers,
  );

  Future<RuleProfile> upsertProfile({
    required String name,
    String? id,
    bool enabled = true,
    List<String> matchers = const [],
    String? sourceTemplateSlug,
  });

  Future<RuleProfile?> updateStoredRule({
    required String profileId,
    required StoredRule targetRule,
    String? selector,
    RuleMode? mode,
    String? frameScope,
  });
}
