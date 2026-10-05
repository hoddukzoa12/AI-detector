import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_ai_settings_panel.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_evidence_tab.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_modules_panel.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_network_filter_panel.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_pick_tab.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_settings_tab.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_header.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_site_tab.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_template_tab.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_text_block_panel.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_watch_tab.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

part 'infocutter_sidebar_tabs.dart';
part 'infocutter_sidebar_modules.dart';

class InfocutterSidebarData {
  const InfocutterSidebarData({
    required this.mode,
    required this.session,
    required this.url,
    this.capturedKeyword,
    this.keywordCaptureActive,
  });

  final InfocutterPanelMode mode;

  /// The live per-tab multi-select block session (block mode only).
  final List<SelectionCard> session;
  final Uri url;

  /// Live captured keyword text from the page — filled by the JS capture flow.
  final ValueListenable<String?>? capturedKeyword;

  /// Whether the keyword capture mode is currently active on the page.
  /// A [ValueListenable<bool>] so the sidebar toggle reflects state reactively.
  final ValueListenable<bool>? keywordCaptureActive;
}

class InfocutterSidebarActions {
  const InfocutterSidebarActions({
    required this.onAnalyzeAiCurrentPage,
    required this.onApplySession,
    required this.onCancelSession,
    required this.onClose,
    required this.onCaptureDetectionEvidence,
    required this.onCaptureEvidence,
    required this.onNetworkFiltersChanged,
    required this.onPausePicker,
    required this.onPreviewStoredRule,
    required this.onRefineSessionCard,
    required this.onRemoveSessionCard,
    required this.onRenameSessionCard,
    required this.onResumePicker,
    required this.onRulesChanged,
    required this.onSetSessionCardDepth,
    required this.onStartBlockPicker,
    required this.onWatchChanged,
    this.onSetKeywordCapture,
  });

  final Future<List<AiPageCandidate>> Function() onAnalyzeAiCurrentPage;
  final VoidCallback onApplySession;
  final VoidCallback onCancelSession;
  final VoidCallback onClose;
  final Future<void> Function(WatchDetection detection)
      onCaptureDetectionEvidence;
  final Future<void> Function() onCaptureEvidence;
  final Future<void> Function() onNetworkFiltersChanged;
  final Future<void> Function() onPausePicker;
  final Future<void> Function(StoredRule rule) onPreviewStoredRule;
  final void Function(String id, String selector) onRefineSessionCard;
  final void Function(String id) onRemoveSessionCard;
  final void Function(String id, String name) onRenameSessionCard;
  final Future<void> Function() onResumePicker;
  final Future<void> Function() onRulesChanged;
  final void Function(String id, int index) onSetSessionCardDepth;
  final Future<void> Function() onStartBlockPicker;
  final Future<void> Function() onWatchChanged;

  /// Activates or deactivates the keyword capture mode on the page.
  final void Function(bool active)? onSetKeywordCapture;
}

class InfocutterSidebar extends StatelessWidget {
  const InfocutterSidebar({
    required this.data,
    required this.actions,
    super.key,
  });

  final InfocutterSidebarData data;
  final InfocutterSidebarActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final module = infocutterModuleForMode(data.mode);
    final width = MediaQuery.sizeOf(context).width;
    final sidebarWidth = width < 620 ? width * 0.92 : 420.0;

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: sidebarWidth,
      child: SafeArea(
        left: false,
        child: Material(
          elevation: 16,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              InfocutterSidebarHeader(
                icon: module.icon,
                title: module.title(l10n),
                onClose: actions.onClose,
              ),
              Expanded(
                child: module.buildPanel(context, data, actions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
