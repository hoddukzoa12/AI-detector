/// Which single Infocutter function a sidebar panel is showing.
///
/// Each toolbar icon / overflow-menu entry opens the sidebar in exactly one of
/// these modes, replacing the former crammed multi-category tab layout.
enum InfocutterPanelMode {
  /// Selector/picker-based element hiding (entered via the page picker).
  block,

  /// Keyword-based text block hiding.
  keyword,

  /// AI auto-masking suggestions.
  ai,

  /// Watch targets (auto-remove by detected name).
  watch,

  /// Network request blocking.
  network,

  /// Manage existing removals: current-site rules, templates, evidence.
  manage,

  /// Per-module on/off toggles + config backup/restore (import/export).
  modules,

  /// Global Infocutter settings.
  settings,
}
