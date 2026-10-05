part of 'infocutter_service.dart';

extension InfocutterStoreMutations on InfocutterService {
  /// chrome 의 export JSON 을 import. 기존 profile 과 ID 가 충돌하면 덮어씀.
  Future<void> importChromeJson(String raw) async {
    final imported = _codec.decodeJson(raw);
    final byId = {
      for (final profile in _snapshot.profiles) profile.id: profile
    };
    for (final profile in imported.profiles) {
      byId[profile.id] = profile;
    }
    await _commitSnapshot(
      RuleStoreSnapshot(
        globalEnabled: imported.globalEnabled,
        profiles: byId.values.toList(),
      ),
    );
  }

  Future<RuleProfile> importTemplate(InfocutterTemplate template) async {
    final profile = template.toRuleProfile(DateTime.now().toUtc());
    final next = [..._snapshot.profiles];
    final existingIndex = next.indexWhere((p) => p.id == profile.id);
    if (existingIndex >= 0) {
      next[existingIndex] = profile;
    } else {
      next.add(profile);
    }
    await _commitProfiles(next);
    return profile;
  }
}
