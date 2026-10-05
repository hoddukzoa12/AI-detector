import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/models/webview_model.dart';

/// Tracks which infocutter sidebar panel is open for a tab (and for which URL).
/// The multi-select block session itself lives on
/// [WebViewModel.infocutterSelectionSession]; this only governs open/close +
/// the active mode, shared by every panel.
class InfocutterSidebarState {
  const InfocutterSidebarState({
    required this.mode,
    required this.url,
  });

  final InfocutterPanelMode mode;
  final Uri url;
}

class InfocutterSidebarSession {
  InfocutterSidebarSession({
    required this.webViewModel,
    required this.onChanged,
  });

  final WebViewModel webViewModel;
  final VoidCallback onChanged;

  InfocutterSidebarState? get state => _state;
  InfocutterSidebarState? _state;

  void open({
    required InfocutterPanelMode mode,
    required Uri url,
  }) {
    _state = InfocutterSidebarState(mode: mode, url: url);
    webViewModel.infocutterOpenPanel = mode;
    onChanged();
  }

  void close() {
    _state = null;
    webViewModel.infocutterOpenPanel = null;
    onChanged();
  }

  String defaultCardName(Uri url) {
    final title = webViewModel.title;
    return title != null && title.trim().isNotEmpty ? title.trim() : url.host;
  }
}
