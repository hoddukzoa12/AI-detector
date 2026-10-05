part of 'webview_tab_app_bar.dart';

extension _WebViewTabAppBarDialogs on _WebViewTabAppBarState {
  void showSavedWindows() {
    showDialog(
      context: context,
      builder: (context) {
        final browserModel = Provider.of<BrowserModel>(context);

        return AlertDialog(
          contentPadding: const EdgeInsets.all(0.0),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setState) {
                return FutureBuilder(
                  future: browserModel.getWindows(),
                  builder: (context, snapshot) {
                    final savedWindows = (snapshot.data ?? []);
                    savedWindows.sortBy((e) => e.updatedTime);

                    return ListView(
                      children: savedWindows
                          .map(
                            (window) => _buildSavedWindowTile(
                              dialogContext: context,
                              browserModel: browserModel,
                              savedWindows: savedWindows,
                              savedWindow: window,
                              refreshDialog: setState,
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void showFavorites() {
    showDialog(
      context: context,
      builder: (context) {
        final browserModel = Provider.of<BrowserModel>(context);

        return AlertDialog(
          contentPadding: const EdgeInsets.all(0.0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: browserModel.favorites
                  .map(
                    (favorite) => _buildFavoriteTile(
                      dialogContext: context,
                      browserModel: browserModel,
                      favorite: favorite,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  void showHistory() {
    showDialog(
      context: context,
      builder: (context) {
        final webViewModel = Provider.of<WebViewModel>(context);

        return AlertDialog(
          contentPadding: const EdgeInsets.all(0.0),
          content: FutureBuilder(
            future: webViewModel.webViewController?.getCopyBackForwardList(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container();
              }

              final history = snapshot.data as WebHistory;
              return SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: history.list?.reversed
                          .map(
                            (historyItem) => _buildHistoryTile(
                              dialogContext: context,
                              webViewModel: webViewModel,
                              historyItem: historyItem,
                            ),
                          )
                          .toList() ??
                      <Widget>[],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void showWebArchives() {
    showDialog(
      context: context,
      builder: (context) {
        final browserModel = Provider.of<BrowserModel>(context);
        final webArchives = browserModel.webArchives.values;

        return AlertDialog(
          contentPadding: const EdgeInsets.all(0.0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: webArchives
                  .map(
                    (webArchive) => _buildWebArchiveTile(
                      dialogContext: context,
                      browserModel: browserModel,
                      webArchive: webArchive,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  ListTile _buildSavedWindowTile({
    required BuildContext dialogContext,
    required BrowserModel browserModel,
    required List<WindowModel> savedWindows,
    required WindowModel savedWindow,
    required StateSetter refreshDialog,
  }) {
    return ListTile(
      title: Text(
        savedWindow.name.isNotEmpty ? savedWindow.name : savedWindow.id,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () async {
        await browserModel.openWindow(savedWindow);
        refreshDialog(() {
          Navigator.pop(dialogContext);
        });
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close, size: 20.0),
            onPressed: () async {
              await _removeSavedWindow(
                dialogContext: dialogContext,
                browserModel: browserModel,
                savedWindows: savedWindows,
                savedWindow: savedWindow,
                refreshDialog: refreshDialog,
              );
            },
          )
        ],
      ),
    );
  }

  Future<void> _removeSavedWindow({
    required BuildContext dialogContext,
    required BrowserModel browserModel,
    required List<WindowModel> savedWindows,
    required WindowModel savedWindow,
    required StateSetter refreshDialog,
  }) async {
    await browserModel.removeWindow(savedWindow);
    refreshDialog(() {
      if (savedWindows.length <= 1) {
        Navigator.pop(dialogContext);
      }
    });
  }

  ListTile _buildFavoriteTile({
    required BuildContext dialogContext,
    required BrowserModel browserModel,
    required FavoriteModel favorite,
  }) {
    final url = favorite.url;

    return ListTile(
      leading: _buildFavicon(url, faviconUrl: favorite.favicon?.url),
      title: Text(
        favorite.title ?? favorite.url?.toString() ?? "",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        favorite.url?.toString() ?? "",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      onTap: () {
        _refreshAppBar(() {
          addNewTab(url: favorite.url);
          Navigator.pop(dialogContext);
        });
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close, size: 20.0),
            onPressed: () {
              _removeFavorite(
                dialogContext: dialogContext,
                browserModel: browserModel,
                favorite: favorite,
              );
            },
          )
        ],
      ),
    );
  }

  void _removeFavorite({
    required BuildContext dialogContext,
    required BrowserModel browserModel,
    required FavoriteModel favorite,
  }) {
    _refreshAppBar(() {
      browserModel.removeFavorite(favorite);
      if (browserModel.favorites.isEmpty) {
        Navigator.pop(dialogContext);
      }
    });
  }

  ListTile _buildHistoryTile({
    required BuildContext dialogContext,
    required WebViewModel webViewModel,
    required WebHistoryItem historyItem,
  }) {
    final url = historyItem.url;

    return ListTile(
      leading: _buildFavicon(url),
      title: Text(
        historyItem.title ?? url.toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        url?.toString() ?? "",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      onTap: () {
        webViewModel.webViewController?.goTo(historyItem: historyItem);
        Navigator.pop(dialogContext);
      },
    );
  }

  ListTile _buildWebArchiveTile({
    required BuildContext dialogContext,
    required BrowserModel browserModel,
    required WebArchiveModel webArchive,
  }) {
    final url = webArchive.url;

    return ListTile(
      leading: _buildFavicon(url),
      title: Text(
        webArchive.title ?? url?.toString() ?? "",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        url?.toString() ?? "",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () {
          _refreshAppBar(() {
            browserModel.removeWebArchive(webArchive);
            browserModel.save();
          });
        },
      ),
      isThreeLine: true,
      onTap: () {
        _openWebArchivePath(webArchive.path);
        Navigator.pop(dialogContext);
      },
    );
  }

  Column _buildFavicon(WebUri? url, {WebUri? faviconUrl}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        CustomImage(
          url: faviconUrl ?? WebUri("${url?.origin ?? ""}/favicon.ico"),
          maxWidth: 30.0,
          height: 30.0,
        )
      ],
    );
  }

  void _openWebArchivePath(String? path) {
    if (path == null) {
      return;
    }

    final windowModel = Provider.of<WindowModel>(context, listen: false);
    windowModel.addTab(
      WebViewModel(url: WebUri("file://$path")),
    );
  }
}
