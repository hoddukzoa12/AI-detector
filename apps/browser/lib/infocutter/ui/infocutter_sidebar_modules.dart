part of 'infocutter_sidebar.dart';

typedef InfocutterModuleTitleBuilder = String Function(AppLocalizations l10n);

typedef InfocutterModulePanelBuilder = Widget Function(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
);

class InfocutterModuleDescriptor {
  const InfocutterModuleDescriptor({
    required this.mode,
    required this.icon,
    required this.title,
    required this.buildPanel,
  });

  final InfocutterPanelMode mode;
  final IconData icon;
  final InfocutterModuleTitleBuilder title;
  final InfocutterModulePanelBuilder buildPanel;
}

final Map<InfocutterPanelMode, InfocutterModuleDescriptor>
    _infocutterModulesByMode = {
  for (final module in infocutterModules) module.mode: module,
};

InfocutterModuleDescriptor infocutterModuleForMode(
  InfocutterPanelMode mode,
) =>
    _infocutterModulesByMode[mode]!;

const List<InfocutterModuleDescriptor> infocutterModules = [
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.block,
    icon: Icons.content_cut,
    title: _blockTitle,
    buildPanel: _buildBlockPanel,
  ),
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.keyword,
    icon: Icons.text_fields,
    title: _keywordTitle,
    buildPanel: _buildKeywordPanel,
  ),
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.ai,
    icon: Icons.auto_awesome,
    title: _aiTitle,
    buildPanel: _buildAiPanel,
  ),
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.watch,
    icon: Icons.visibility,
    title: _watchTitle,
    buildPanel: _buildWatchPanel,
  ),
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.network,
    icon: Icons.block,
    title: _networkTitle,
    buildPanel: _buildNetworkPanel,
  ),
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.manage,
    icon: Icons.tune,
    title: _manageTitle,
    buildPanel: _buildManagePanel,
  ),
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.modules,
    icon: Icons.widgets_outlined,
    title: _modulesTitle,
    buildPanel: _buildModulesPanel,
  ),
  InfocutterModuleDescriptor(
    mode: InfocutterPanelMode.settings,
    icon: Icons.settings,
    title: _settingsTitle,
    buildPanel: _buildSettingsPanel,
  ),
];

String _blockTitle(AppLocalizations l10n) => l10n.infocutterPickBlockRemoveTab;
String _keywordTitle(AppLocalizations l10n) =>
    l10n.infocutterKeywordBlockRemoveTab;
String _aiTitle(AppLocalizations l10n) => l10n.infocutterAiRecommendRemoveTab;
String _watchTitle(AppLocalizations l10n) => l10n.infocutterWatchAutoRemoveTab;
String _networkTitle(AppLocalizations l10n) =>
    l10n.infocutterNetworkRequestBlockTab;
String _manageTitle(AppLocalizations l10n) =>
    l10n.infocutterManageRemovedCategory;
String _modulesTitle(AppLocalizations l10n) => l10n.infocutterModulesTab;
String _settingsTitle(AppLocalizations l10n) =>
    l10n.infocutterGlobalSettingsTab;

Widget _buildBlockPanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) {
  // The scissors panel carries both halves of "hiding": staging new blocks and
  // reviewing/un-hiding what's already hidden on this site.
  return _InfocutterBlockPanel(data: data, actions: actions);
}

Widget _buildKeywordPanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) {
  final onSetKeywordCapture = actions.onSetKeywordCapture;
  return InfocutterTextBlockPanel(
    url: data.url,
    onTextBlocksChanged: actions.onRulesChanged,
    showHeader: false,
    capturedKeyword: data.capturedKeyword,
    keywordCaptureActive: data.keywordCaptureActive,
    onSetKeywordCapture: onSetKeywordCapture,
  );
}

Widget _buildAiPanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) =>
    InfocutterAiSettingsPanel(
      onAnalyzeCurrentPage: actions.onAnalyzeAiCurrentPage,
      onRulesChanged: actions.onRulesChanged,
      url: data.url,
      showHeader: false,
    );

Widget _buildWatchPanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) =>
    InfocutterWatchTab(
      onCaptureDetectionEvidence: actions.onCaptureDetectionEvidence,
      onWatchChanged: actions.onWatchChanged,
    );

Widget _buildNetworkPanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) =>
    InfocutterNetworkFilterPanel(
      onNetworkFiltersChanged: actions.onNetworkFiltersChanged,
      showHeader: false,
    );

Widget _buildManagePanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) {
  final l10n = AppLocalizations.of(context);
  return _InfocutterNestedTabs(
    tabs: [
      _InfocutterNestedTab(
        label: l10n.infocutterBlockShortTab,
        child: InfocutterSiteTab(
          onPreviewRule: actions.onPreviewStoredRule,
          onRulesChanged: actions.onRulesChanged,
          url: data.url,
        ),
      ),
      _InfocutterNestedTab(
        label: l10n.infocutterTextShortTab,
        child: InfocutterTextBlockPanel(
          onTextBlocksChanged: actions.onRulesChanged,
          showHeader: false,
          url: data.url,
          capturedKeyword: data.capturedKeyword,
          keywordCaptureActive: data.keywordCaptureActive,
          onSetKeywordCapture: actions.onSetKeywordCapture,
        ),
      ),
      _InfocutterNestedTab(
        label: l10n.infocutterAiShortTab,
        child: InfocutterAiSettingsPanel(
          onAnalyzeCurrentPage: actions.onAnalyzeAiCurrentPage,
          onRulesChanged: actions.onRulesChanged,
          showHeader: false,
          url: data.url,
        ),
      ),
      _InfocutterNestedTab(
        label: l10n.infocutterTemplatesShortTab,
        child: InfocutterTemplateTab(
          onRulesChanged: actions.onRulesChanged,
        ),
      ),
      _InfocutterNestedTab(
        label: l10n.infocutterEvidenceTab,
        child: InfocutterEvidenceTab(
          onCaptureEvidence: actions.onCaptureEvidence,
        ),
      ),
    ],
  );
}

Widget _buildModulesPanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) =>
    InfocutterModulesPanel(
      onRulesChanged: actions.onRulesChanged,
      onReloadRules: actions.onNetworkFiltersChanged,
    );

Widget _buildSettingsPanel(
  BuildContext context,
  InfocutterSidebarData data,
  InfocutterSidebarActions actions,
) =>
    InfocutterSettingsTab(
      onReloadRules: actions.onNetworkFiltersChanged,
    );
