part of 'infocutter_sidebar.dart';

/// The scissors (block) panel: a "고르기" tab that stages new blocks via the
/// picker and a "숨긴 목록" tab that lists/un-hides what's already hidden on the
/// site. The on-page picker is paused whenever the user leaves "고르기" so the
/// page stays scrollable/clickable while they review.
class _InfocutterBlockPanel extends StatefulWidget {
  const _InfocutterBlockPanel({
    required this.data,
    required this.actions,
  });

  final InfocutterSidebarData data;
  final InfocutterSidebarActions actions;

  @override
  State<_InfocutterBlockPanel> createState() => _InfocutterBlockPanelState();
}

class _InfocutterBlockPanelState extends State<_InfocutterBlockPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      widget.actions.onResumePicker();
    } else {
      widget.actions.onPausePicker();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.infocutterPickTab),
              Tab(text: l10n.infocutterHiddenListTab),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              InfocutterPickTab(
                url: widget.data.url,
                session: widget.data.session,
                onRemoveSessionCard: widget.actions.onRemoveSessionCard,
                onRefineSessionCard: widget.actions.onRefineSessionCard,
                onRenameSessionCard: widget.actions.onRenameSessionCard,
                onApplySession: widget.actions.onApplySession,
                onCancelSession: widget.actions.onCancelSession,
                onRulesChanged: widget.actions.onRulesChanged,
                onPreviewStoredRule: widget.actions.onPreviewStoredRule,
                onSetSessionCardDepth: widget.actions.onSetSessionCardDepth,
              ),
              InfocutterSiteTab(
                onPreviewRule: widget.actions.onPreviewStoredRule,
                url: widget.data.url,
                onRulesChanged: widget.actions.onRulesChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfocutterNestedTab {
  const _InfocutterNestedTab({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;
}

class _InfocutterNestedTabs extends StatelessWidget {
  const _InfocutterNestedTabs({
    required this.tabs,
  });

  final List<_InfocutterNestedTab> tabs;

  @override
  Widget build(BuildContext context) {
    if (tabs.length == 1) {
      return tabs.single.child;
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final tab in tabs) Tab(text: tab.label),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final tab in tabs) tab.child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
