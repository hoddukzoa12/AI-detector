part of 'browser.dart';

extension _BrowserTabScroller on _BrowserState {
  Widget _buildWebViewTabsViewer() {
    final browserModel = Provider.of<BrowserModel>(context);
    final windowModel = Provider.of<WindowModel>(context);

    // ignore: deprecated_member_use
    return WillPopScope(
        onWillPop: () async {
          browserModel.showTabScroller = false;
          return false;
        },
        child: Scaffold(
            appBar: const TabViewerAppBar(),
            body: TabViewer(
              currentIndex: windowModel.getCurrentTabIndex(),
              children: windowModel.webViewModels.map((webViewModel) {
                webViewTabStateKey.currentState?.pause();
                return _buildTabViewerItem(
                  browserModel: browserModel,
                  currentTabIndex: windowModel.getCurrentTabIndex(),
                  webViewModel: webViewModel,
                  windowModel: windowModel,
                );
              }).toList(),
              onTap: (index) async {
                browserModel.showTabScroller = false;
                windowModel.showTab(index);
              },
            )));
  }

  Widget _buildTabViewerItem({
    required BrowserModel browserModel,
    required int currentTabIndex,
    required WebViewModel webViewModel,
    required WindowModel windowModel,
  }) {
    final isCurrentTab = currentTabIndex == webViewModel.tabIndex;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: _tabTileColor(webViewModel, isCurrentTab),
          child: ListTile(
            leading: _buildTabFavicon(webViewModel),
            title: _buildTabTitle(webViewModel, isCurrentTab),
            subtitle: _buildTabSubtitle(webViewModel, isCurrentTab),
            isThreeLine: true,
            trailing: _buildCloseTabButton(
              browserModel: browserModel,
              isCurrentTab: isCurrentTab,
              webViewModel: webViewModel,
              windowModel: windowModel,
            ),
          ),
        ),
        Expanded(
          child: _buildTabScreenshot(webViewModel),
        )
      ],
    );
  }

  Color _tabTileColor(WebViewModel webViewModel, bool isCurrentTab) {
    if (isCurrentTab) return Colors.blue;
    return webViewModel.isIncognitoMode ? Colors.black : Colors.white;
  }

  Widget _buildTabFavicon(WebViewModel webViewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        CustomImage(
          url: _faviconUrl(webViewModel),
          maxWidth: 30.0,
          height: 30.0,
        )
      ],
    );
  }

  Uri? _faviconUrl(WebViewModel webViewModel) {
    final url = webViewModel.url;
    return webViewModel.favicon?.url ??
        (url != null && ["http", "https"].contains(url.scheme)
            ? Uri.parse("${url.origin}/favicon.ico")
            : null);
  }

  Widget _buildTabTitle(WebViewModel webViewModel, bool isCurrentTab) {
    return Text(
      webViewModel.title ?? webViewModel.url?.toString() ?? "",
      maxLines: 2,
      style: TextStyle(color: _tabTextColor(webViewModel, isCurrentTab)),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTabSubtitle(WebViewModel webViewModel, bool isCurrentTab) {
    return Text(
      webViewModel.url?.toString() ?? "",
      style: TextStyle(color: _tabSubtitleColor(webViewModel, isCurrentTab)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _tabTextColor(WebViewModel webViewModel, bool isCurrentTab) {
    return webViewModel.isIncognitoMode || isCurrentTab
        ? Colors.white
        : Colors.black;
  }

  Color _tabSubtitleColor(WebViewModel webViewModel, bool isCurrentTab) {
    return webViewModel.isIncognitoMode || isCurrentTab
        ? Colors.white60
        : Colors.black54;
  }

  Widget _buildCloseTabButton({
    required BrowserModel browserModel,
    required bool isCurrentTab,
    required WebViewModel webViewModel,
    required WindowModel windowModel,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          icon: Icon(
            Icons.close,
            size: 20.0,
            color: _tabSubtitleColor(webViewModel, isCurrentTab),
          ),
          onPressed: () => _closeTab(browserModel, windowModel, webViewModel),
        )
      ],
    );
  }

  void _closeTab(
    BrowserModel browserModel,
    WindowModel windowModel,
    WebViewModel webViewModel,
  ) {
    rebuild(() {
      final tabIndex = webViewModel.tabIndex;
      if (tabIndex == null) return;

      windowModel.closeTab(tabIndex);
      if (windowModel.webViewModels.isEmpty) {
        browserModel.showTabScroller = false;
      }
    });
  }

  Widget _buildTabScreenshot(WebViewModel webViewModel) {
    final screenshotData = webViewModel.screenshot;
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      width: double.infinity,
      child: screenshotData != null ? Image.memory(screenshotData) : null,
    );
  }
}
