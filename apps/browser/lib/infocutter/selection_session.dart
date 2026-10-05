import 'package:meta/meta.dart';

/// One ancestor-chain level for a staged card's range control. The JS picker
/// sends the whole chain (current element + parents), each with its own selector
/// and a precomputed match count, so switching levels just swaps the card's
/// selector — no re-pick, no JS round-trip.
@immutable
class CardDepthOption {
  const CardDepthOption({
    required this.label,
    required this.selector,
    required this.matchCount,
    this.alternatives = const [],
  });

  final String label; // "현재 요소", "부모 1단계", …
  final String selector;
  final int matchCount;
  final List<String> alternatives;

  Map<String, Object?> toJson() => {
        'label': label,
        'selector': selector,
        'matchCount': matchCount,
        'alternatives': alternatives,
      };
}

/// One staged element in a picker selection session — the multi-select model
/// ported from the Chrome extension: a session holds several cards, each a
/// distinct element-specific selector, applied all at once on confirm.
///
/// The session is owned by Dart (per tab) so both the human picker and external
/// AI/MCP commands mutate the same source of truth, and it is exposed in the
/// automation snapshot. Pure list operations live as top-level functions so
/// they are trivially testable.
@immutable
class SelectionCard {
  const SelectionCard({
    required this.id,
    required this.name,
    required this.selector,
    required this.frameScope,
    required this.matchCount,
    this.alternatives = const [],
    this.depthOptions = const [],
    this.depthIndex = 0,
  });

  final String id;
  final String name;
  final String selector;

  /// null in the top document; `${origin}${pathname}` inside an iframe.
  final String? frameScope;

  /// How many elements the selector currently matches (-1 = unknown).
  final int matchCount;

  /// Other selectors the picker offered for the same element (the "다음 기준"
  /// candidates). Empty for AI/manually-added cards. Lets the sidebar swap a
  /// card's selector without re-picking.
  final List<String> alternatives;

  /// The picked element's ancestor chain (current + parents) with each level's
  /// selector/match-count. Empty for AI/manual cards or single-level picks.
  final List<CardDepthOption> depthOptions;

  /// Which entry of [depthOptions] is currently applied to [selector].
  final int depthIndex;

  SelectionCard copyWith({
    String? name,
    String? selector,
    int? matchCount,
    List<String>? alternatives,
    List<CardDepthOption>? depthOptions,
    int? depthIndex,
  }) =>
      SelectionCard(
        id: id,
        name: name ?? this.name,
        selector: selector ?? this.selector,
        frameScope: frameScope,
        matchCount: matchCount ?? this.matchCount,
        alternatives: alternatives ?? this.alternatives,
        depthOptions: depthOptions ?? this.depthOptions,
        depthIndex: depthIndex ?? this.depthIndex,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'selector': selector,
        'frameScope': frameScope,
        'matchCount': matchCount,
        'alternatives': alternatives,
        'depthOptions': depthOptions.map((o) => o.toJson()).toList(),
        'depthIndex': depthIndex,
      };
}

/// Whether [selector] would hide (almost) the whole page — a foot-gun if
/// applied. Catches the page-root selectors a stray pick or hand-edit can yield
/// (`html`, `body`, `:root`, `*`, or empty). Normal element/container
/// selectors (`.ad`, `div.card`, `article`) are allowed.
bool isOverlyBroadSelector(String selector) {
  final normalized = selector.trim().toLowerCase();
  return const {'', 'html', 'body', ':root', '*'}.contains(normalized);
}

/// Toggle a card: removes an existing card with the same selector+frameScope,
/// otherwise appends the new one. Mirrors the extension's `sessionToggleElement`.
List<SelectionCard> sessionToggle(
  List<SelectionCard> session,
  SelectionCard card,
) {
  final index = session.indexWhere(
    (existing) =>
        existing.selector == card.selector &&
        existing.frameScope == card.frameScope,
  );
  if (index >= 0) {
    return [...session]..removeAt(index);
  }
  return [...session, card];
}

List<SelectionCard> sessionRemove(List<SelectionCard> session, String id) =>
    session.where((card) => card.id != id).toList();

List<SelectionCard> sessionUpdateSelector(
  List<SelectionCard> session,
  String id,
  String selector, {
  int? matchCount,
}) =>
    session
        .map((card) => card.id == id
            ? card.copyWith(selector: selector, matchCount: matchCount)
            : card)
        .toList();

List<SelectionCard> sessionRename(
  List<SelectionCard> session,
  String id,
  String name,
) {
  final trimmed = name.trim();
  return session
      .map((card) => card.id == id && trimmed.isNotEmpty
          ? card.copyWith(name: trimmed)
          : card)
      .toList();
}

/// Set a card's active depth level: swap its selector/matchCount/alternatives to
/// the chosen ancestor and record the index. No-op for unknown id, empty
/// options, or an out-of-range index.
List<SelectionCard> sessionSetDepthIndex(
  List<SelectionCard> session,
  String id,
  int index,
) =>
    session.map((card) {
      if (card.id != id) return card;
      if (index < 0 || index >= card.depthOptions.length) return card;
      final option = card.depthOptions[index];
      return card.copyWith(
        selector: option.selector,
        matchCount: option.matchCount,
        alternatives: option.alternatives,
        depthIndex: index,
      );
    }).toList();
