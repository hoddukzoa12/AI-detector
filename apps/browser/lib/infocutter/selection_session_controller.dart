import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';

/// The card-shaping details of [SelectionSessionController.stage] — everything
/// beyond "which selector, under what name". Grouped so the common call stays
/// `stage(selector, name: ...)` while the picker path passes the full shape.
class StageOptions {
  const StageOptions({
    this.frameScope,
    this.alternatives = const [],
    this.depthOptions = const [],
    this.depthIndex = 0,
  });

  final String? frameScope;
  final List<String> alternatives;
  final List<CardDepthOption> depthOptions;
  final int depthIndex;
}

/// Drives the per-tab multi-select session for the HUMAN picker flow.
///
/// It is a thin, fully unit-testable wrapper over the pure [selection_session]
/// functions: it owns no widgets and no WebView — match counting and on-page
/// highlight repainting are injected, so the same mutation logic the AI/MCP
/// commands use is shared here without dragging in a controller. The session
/// itself ([session]) is the single source of truth shared with the AI path.
class SelectionSessionController {
  SelectionSessionController({
    required ValueNotifier<List<SelectionCard>> session,
    required Future<int?> Function(String selector) countMatches,
    required Future<void> Function(List<SelectionCard> session)
        repaintHighlights,
    String Function(int seq)? newCardId,
  })  : _session = session,
        _countMatches = countMatches,
        _repaint = repaintHighlights,
        _newCardId = newCardId ?? _defaultCardId;

  final ValueNotifier<List<SelectionCard>> _session;
  final Future<int?> Function(String selector) _countMatches;
  final Future<void> Function(List<SelectionCard> session) _repaint;
  final String Function(int seq) _newCardId;

  int _seq = 0;

  List<SelectionCard> get cards => _session.value;
  bool get isEmpty => _session.value.isEmpty;

  /// Toggle [selector] into the session: a fresh element is appended as a
  /// numbered card; clicking an already-staged element removes it (the
  /// extension's toggle semantics). No-op for a blank selector.
  Future<void> stage(
    String selector, {
    required String name,
    StageOptions options = const StageOptions(),
  }) async {
    final normalized = selector.trim();
    if (normalized.isEmpty) return;
    final card = SelectionCard(
      id: _newCardId(_seq++),
      name: name.trim().isNotEmpty ? name.trim() : normalized,
      selector: normalized,
      frameScope: options.frameScope,
      matchCount: await _countMatches(normalized) ?? -1,
      alternatives: options.alternatives,
      depthOptions: options.depthOptions,
      depthIndex: options.depthIndex,
    );
    _session.value = sessionToggle(_session.value, card);
    await _repaint(_session.value);
  }

  /// Switch a staged card to a different ancestor depth (parent/child). Uses the
  /// precomputed per-level match count, so no JS round-trip; repaints so the
  /// on-page highlight box moves to the new range.
  Future<void> setDepthIndex(String id, int index) async {
    _session.value = sessionSetDepthIndex(_session.value, id, index);
    await _repaint(_session.value);
  }

  /// Repaint the on-page highlights for the current session (e.g. when the
  /// picker (re)starts on a tab that already has staged cards).
  Future<void> refreshHighlights() => _repaint(_session.value);

  Future<void> remove(String id) async {
    _session.value = sessionRemove(_session.value, id);
    await _repaint(_session.value);
  }

  /// Replace one card's selector and recompute its match count.
  Future<void> refine(String id, String selector) async {
    final normalized = selector.trim();
    if (normalized.isEmpty) return;
    _session.value = sessionUpdateSelector(
      _session.value,
      id,
      normalized,
      matchCount: await _countMatches(normalized) ?? -1,
    );
    await _repaint(_session.value);
  }

  /// Renames a card. Names don't affect the on-page highlights (those show the
  /// index/color only), so this skips the repaint.
  void rename(String id, String name) {
    _session.value = sessionRename(_session.value, id, name);
  }

  Future<void> clear() async {
    _session.value = const [];
    await _repaint(_session.value);
  }

  /// Persist every staged card via [save], then clear the session and repaint
  /// (which removes the staged highlights — the committed rules take over).
  /// Returns the cards that were applied, in order.
  Future<List<SelectionCard>> apply(
    Future<void> Function(SelectionCard card) save,
  ) async {
    final applied = List<SelectionCard>.unmodifiable(_session.value);
    for (final card in applied) {
      await save(card);
    }
    _session.value = const [];
    await _repaint(_session.value);
    return applied;
  }

  static String _defaultCardId(int seq) =>
      'sel-${DateTime.now().microsecondsSinceEpoch}-$seq';
}
