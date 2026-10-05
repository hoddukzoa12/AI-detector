part of 'webview_tab.dart';

extension _WebViewTabSidebar on _WebViewTabState {
  Widget _buildInfocutterSidebar(InfocutterPanelMode mode, Uri url) {
    return ValueListenableBuilder<List<SelectionCard>>(
      valueListenable: widget.webViewModel.infocutterSelectionSession,
      builder: (context, session, _) => InfocutterSidebar(
        data: _buildInfocutterSidebarData(mode, url, session),
        actions: _buildInfocutterSidebarActions(mode),
      ),
    );
  }

  InfocutterSidebarData _buildInfocutterSidebarData(
      InfocutterPanelMode mode, Uri url, List<SelectionCard> session) {
    return InfocutterSidebarData(
      mode: mode,
      session: session,
      url: url,
      capturedKeyword: widget.webViewModel.infocutterCapturedKeyword,
      keywordCaptureActive: widget.webViewModel.infocutterKeywordCaptureActive,
    );
  }

  InfocutterSidebarActions _buildInfocutterSidebarActions(
      InfocutterPanelMode mode) {
    return InfocutterSidebarActions(
      onAnalyzeAiCurrentPage: _infocutterCoordinator.collectAiMaskingCandidates,
      onApplySession: _applyInfocutterSession,
      onCancelSession: _cancelInfocutterSession,
      // Closing the block panel discards the staged session and stops the
      // picker; other panels just close.
      onClose: mode == InfocutterPanelMode.block
          ? _cancelInfocutterSession
          : _infocutterCoordinator.closeSidebar,
      onCaptureDetectionEvidence: (detection) =>
          _captureInfocutterEvidence(detection: detection),
      onCaptureEvidence: _captureInfocutterEvidence,
      onNetworkFiltersChanged: _refreshInfocutterNetworkFiltersForCurrentUrl,
      onPausePicker: _pauseInfocutterPicker,
      onPreviewStoredRule: _infocutterCoordinator.previewStoredRule,
      onResumePicker: _resumeInfocutterPicker,
      onRefineSessionCard: _refineInfocutterSessionCard,
      onRemoveSessionCard: _removeInfocutterSessionCard,
      onRenameSessionCard: _renameInfocutterSessionCard,
      onRulesChanged: _refreshInfocutterForCurrentUrl,
      onSetSessionCardDepth: _setInfocutterSessionCardDepth,
      onStartBlockPicker: startInfocutterBlockPicker,
      onWatchChanged: _refreshInfocutterForCurrentUrl,
      onSetKeywordCapture: (active) => active
          ? unawaited(_infocutterCoordinator.startKeywordCapture())
          : unawaited(_infocutterCoordinator.stopKeywordCapture()),
    );
  }
}
