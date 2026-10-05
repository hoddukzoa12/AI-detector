import 'package:infocutter_app/infocutter/models.dart';

/// Re-resolve a stored rule from the freshest [cards] by its stable identity
/// (cardId + createdAt), which survives selector/mode/frame edits. Used at
/// inline-edit commit time so a captured (stale) StoredRule never desyncs the
/// mutation target. Returns null if the rule is no longer present.
StoredRule? findRuleByIdentity(
  List<SavedCard> cards,
  String cardId,
  DateTime createdAt,
) {
  for (final card in cards) {
    if (card.cardId != cardId) continue;
    for (final rule in card.rules) {
      if (rule.createdAt == createdAt) return rule;
    }
  }
  return null;
}
