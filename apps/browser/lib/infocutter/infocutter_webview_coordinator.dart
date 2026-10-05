import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/infocutter_webview_capture.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/infocutter_runtime_applier.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/infocutter_session_actions.dart';
import 'package:infocutter_app/infocutter/infocutter_sidebar_session.dart';
import 'package:infocutter_app/infocutter/infocutter_webview_preview.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session_controller.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:provider/provider.dart';

class InfocutterWebViewCoordinator {
  InfocutterWebViewCoordinator({
    required BuildContext Function() context,
    required InAppWebViewController? Function() controller,
    required bool Function() isMounted,
    required void Function(int sequence) onEvidenceCaptured,
    required void Function(String selector, String host) onRuleSaved,
    required VoidCallback onSidebarChanged,
    required WebViewModel webViewModel,
    Future<void> Function({required bool active})? togglePickerForTest,
  })  : _context = context,
        _controller = controller,
        _isMounted = isMounted,
        _onEvidenceCaptured = onEvidenceCaptured,
        _onRuleSaved = onRuleSaved,
        _togglePickerForTest = togglePickerForTest,
        _webViewModel = webViewModel,
        _sidebarSession = InfocutterSidebarSession(
          webViewModel: webViewModel,
          onChanged: onSidebarChanged,
        ),
        _runtimeApplier = InfocutterRuntimeApplier(
          context: context,
          webViewModel: webViewModel,
        ) {
    _selectionSession = SelectionSessionController(
      session: webViewModel.infocutterSelectionSession,
      countMatches: (selector) async {
        final controller = _controller();
        if (controller == null) return -1;
        try {
          return await countInfocutterSelectorMatches(controller, selector);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('[infocutter] match count failed: $error');
          }
          return -1;
        }
      },
      repaintHighlights: (cards) async {
        final controller = _controller();
        if (controller == null) return;
        try {
          await applyInfocutterSessionHighlights(controller, cards);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('[infocutter] highlight repaint failed: $error');
          }
        }
      },
    );
  }

  final BuildContext Function() _context;
  final InAppWebViewController? Function() _controller;
  final bool Function() _isMounted;
  final void Function(int sequence) _onEvidenceCaptured;
  final void Function(String selector, String host) _onRuleSaved;
  final Future<void> Function({required bool active})? _togglePickerForTest;
  final WebViewModel _webViewModel;
  final InfocutterSidebarSession _sidebarSession;
  final InfocutterRuntimeApplier _runtimeApplier;
  late final SelectionSessionController _selectionSession;
  int _previewSequence = 0;
  List<StoredRule> _lastApplied = const [];

  InfocutterSidebarState? get sidebar => _sidebarSession.state;

  Future<bool> openPanel(InfocutterPanelMode mode) async {
    final url = _webViewModel.url;
    if (url == null || url.host.isEmpty) {
      return false;
    }
    await _setPickerActiveIfAvailable(active: false);
    if (!_isMounted()) return false;
    _sidebarSession.open(mode: mode, url: Uri.parse(url.toString()));
    return true;
  }

  Future<void> startBlockPicker() async {
    final controller = _controller();
    final rawUrl = _webViewModel.url;
    if (controller == null || rawUrl == null || rawUrl.host.isEmpty) {
      return;
    }
    final url = Uri.parse(rawUrl.toString());
    await _setPickerActive(controller, active: true);
    if (!_isMounted()) return;
    // Open the sidebar in block mode so the staged-card list stays visible
    // while the human keeps clicking; repaint any already-staged highlights.
    _sidebarSession.open(mode: InfocutterPanelMode.block, url: url);
    await _selectionSession.refreshHighlights();
  }

  Future<void> handlePickerResult(
    InfocutterService infocutter,
    PickerResult result,
  ) async {
    final controller = _controller();
    final rawUrl = _webViewModel.url;
    if (controller == null || rawUrl == null || rawUrl.host.isEmpty) {
      return;
    }
    final url = Uri.parse(rawUrl.toString());
    // Multi-select: stage the picked element and KEEP the picker active so the
    // human can keep clicking. The sidebar card list updates from the session.
    await _selectionSession.stage(
      result.selector,
      name: _sidebarSession.defaultCardName(url),
      options: stageOptionsForPickerResult(result),
    );
    if (!_isMounted()) return;
    if (_sidebarSession.state == null) {
      _sidebarSession.open(mode: InfocutterPanelMode.block, url: url);
    }
  }

  void handleWatchDetection(WatchDetection detection) {
    final watch = Provider.of<WatchService>(_context(), listen: false);
    watch.recordDetection(detection);
  }

  bool get keywordCaptureActive =>
      _webViewModel.infocutterKeywordCaptureActive.value;

  Future<void> handleKeywordCapture(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _webViewModel.infocutterCapturedKeyword.value = trimmed;
  }

  Future<void> startKeywordCapture() async {
    final controller = _controller();
    if (controller == null) return;
    await setInfocutterKeywordCaptureActive(controller, active: true);
    _webViewModel.infocutterKeywordCaptureActive.value = true;
  }

  Future<void> stopKeywordCapture() async {
    final controller = _controller();
    if (controller != null) {
      await setInfocutterKeywordCaptureActive(controller, active: false);
    }
    _webViewModel.infocutterKeywordCaptureActive.value = false;
  }

  /// 사이드바 닫을 때 피커 오버레이도 종료 (#2).
  Future<void> closeSidebar() async {
    await _setPickerActiveIfAvailable(active: false);
    if (!_isMounted()) return;
    _sidebarSession.close();
  }

  /// Navigating to a different host invalidates the open panel (its rules/session
  /// were for the previous site), so discard the staged session, stop the picker
  /// and close the sidebar. Same-host (SPA) navigation keeps it open.
  Future<void> handleHostChange(Uri? newUrl) async {
    // The last-applied undo is scoped to the host it was applied on; once we
    // leave that host its rules must not be reachable from a stale undo.
    if (newUrl != null && newUrl.host != _webViewModel.url?.host) {
      _lastApplied = const [];
    }
    final sidebar = _sidebarSession.state;
    if (sidebar == null || newUrl == null || newUrl.host == sidebar.url.host) {
      return;
    }
    await _selectionSession.clear();
    if (!_isMounted()) return;
    await closeSidebar();
  }

  /// Re-arm the page picker without reopening the sidebar (the staged session
  /// stays); used when returning to the "고르기" tab.
  Future<void> resumePicker() async {
    final controller = _controller();
    if (controller == null) return;
    await _setPickerActive(controller, active: true);
    await _selectionSession.refreshHighlights();
  }

  /// Stop the page picker but keep the staged session + sidebar open; used when
  /// leaving the "고르기" tab so the page stays interactive (e.g. to scroll the
  /// "숨긴 목록").
  Future<void> pausePicker() => _setPickerActiveIfAvailable(active: false);

  /// Temporarily reveal and highlight a stored rule from the hidden-list tab so
  /// the user can see which on-page block the saved selector targets.
  Future<void> previewStoredRule(StoredRule rule) async {
    final controller = _controller();
    if (controller == null || rule.selector.trim().isEmpty) return;
    final sequence = ++_previewSequence;
    await runInfocutterStoredRulePreview(
      controller,
      rule,
      isCurrentPreview: () => sequence == _previewSequence,
      // refreshHighlights repaints the current session (empty → effectively a clear).
      restoreHighlights: _selectionSession.refreshHighlights,
    );
  }

  Future<void> removeSessionCard(String id) => _selectionSession.remove(id);

  Future<void> refineSessionCard(String id, String selector) =>
      _selectionSession.refine(id, selector);

  Future<void> setSessionCardDepth(String id, int index) =>
      _selectionSession.setDepthIndex(id, index);

  void renameSessionCard(String id, String name) =>
      _selectionSession.rename(id, name);

  /// Persist every staged card as a block rule, refresh the runtime so the
  /// elements hide, then stop the picker and close the sidebar.
  Future<void> applySession() async {
    final controller = _controller();
    final url = _sidebarSession.state?.url;
    if (controller == null || url == null || url.host.isEmpty) {
      return;
    }
    final infocutter = Provider.of<InfocutterService>(
      _context(),
      listen: false,
    );
    final savePickedBlockRule = Provider.of<SavePickedBlockRuleUseCase>(
      _context(),
      listen: false,
    );
    final savedRules = <StoredRule>[];
    final applied = await _selectionSession.apply((card) async {
      savedRules.add(
        await savePickedBlockRule(
          SavePickedBlockRuleCommand(
            url: url,
            selector: card.selector,
            cardName: card.name,
            frameScope: card.frameScope,
          ),
        ),
      );
    });
    _lastApplied = savedRules;
    // The rules are persisted for the URL we picked on; only push the runtime
    // to the live page if it's still the same host (the user may have navigated
    // away mid-session). On a different page the rules apply on its next load.
    if (_webViewModel.url?.host == url.host) {
      await applySettingsForUrl(controller, infocutter, url);
      await applyRuntimeForUrl(controller, infocutter, url);
    }
    // Stopping the picker must never strand the sidebar open on success.
    if (!_isMounted()) return;
    await closeSidebar();
    if (applied.isNotEmpty) {
      _onRuleSaved(applied.last.selector, url.host);
    }
  }

  /// Remove the rules created by the most recent [applySession] — backs the
  /// "undo" action on the rule-saved snackbar. No-op once undone/expired.
  Future<void> undoLastApply() async {
    final rules = _lastApplied;
    if (rules.isEmpty) return;
    _lastApplied = const [];
    final infocutter =
        Provider.of<InfocutterService>(_context(), listen: false);
    final repository = Provider.of<BlockRuleRepository>(
      _context(),
      listen: false,
    );
    await removeAppliedBlockRules(
      rules: rules,
      infocutter: infocutter,
      repository: repository,
    );
    final controller = _controller();
    final rawUrl = _webViewModel.url;
    if (controller != null && rawUrl != null && rawUrl.host.isNotEmpty) {
      final url = Uri.parse(rawUrl.toString());
      await applySettingsForUrl(controller, infocutter, url);
      await applyRuntimeForUrl(controller, infocutter, url);
    }
  }

  /// Discard the staged session, clear the highlights, stop the picker, close.
  Future<void> cancelSession() async {
    await _selectionSession.clear();
    if (!_isMounted()) return;
    await closeSidebar();
  }

  Future<void> applySettingsForUrl(
    InAppWebViewController controller,
    InfocutterService infocutter,
    Uri? url,
  ) async {
    await _runtimeApplier.applySettingsForUrl(controller, infocutter, url);
  }

  Future<void> applyRuntimeForUrl(
    InAppWebViewController controller,
    InfocutterService infocutter,
    Uri? url,
  ) async {
    await _runtimeApplier.applyRuntimeForUrl(controller, infocutter, url);
  }

  Future<void> applyTextBlockRuntimeForUrl(
    InAppWebViewController controller,
    TextBlockService textBlocks,
    Uri? url,
  ) async {
    await _runtimeApplier.applyTextBlockRuntimeForUrl(
      controller,
      textBlocks,
      url,
    );
  }

  Future<void> applyWatchRuntime(
    InAppWebViewController controller,
    WatchService watch,
  ) async {
    await _runtimeApplier.applyWatchRuntime(controller, watch);
  }

  Future<void> refreshForCurrentUrl({bool reload = false}) async {
    await _runtimeApplier.refreshForCurrentUrl(_controller(), reload: reload);
  }

  Future<void> captureEvidence({WatchDetection? detection}) async {
    final controller = _controller();
    final url = _webViewModel.url;
    if (controller == null || url == null) return;
    await captureInfocutterEvidence(
      controller,
      url,
      InfocutterEvidenceCaptureHost(
        pageTitle: () => _webViewModel.title ?? '',
        isMounted: _isMounted,
        evidence: () => Provider.of<EvidenceService>(_context(), listen: false),
        onCaptured: _onEvidenceCaptured,
      ),
      detection: detection,
    );
  }

  Future<List<AiPageCandidate>> collectAiMaskingCandidates() async {
    final controller = _controller();
    if (controller == null) return const [];
    return collectInfocutterAiMaskingCandidates(controller);
  }

  Future<void> _setPickerActiveIfAvailable({required bool active}) async {
    final controller = _controller();
    if (controller == null && _togglePickerForTest == null) {
      return;
    }
    try {
      await _setPickerActive(controller, active: active);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[infocutter] ignored picker stop failure: $error');
      }
    }
  }

  Future<void> _setPickerActive(
    InAppWebViewController? controller, {
    required bool active,
  }) async {
    final togglePickerForTest = _togglePickerForTest;
    if (togglePickerForTest != null) {
      await togglePickerForTest(active: active);
      return;
    }
    if (controller == null) return;
    await setPickerActive(controller, active: active);
  }
}
