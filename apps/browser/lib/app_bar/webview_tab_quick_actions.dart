import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/favorite_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/services/web_archive_service.dart';
import 'package:infocutter_app/util.dart';
import 'package:provider/provider.dart';

class WebViewTabQuickActions extends StatefulWidget {
  final BuildContext popupMenuContext;
  final BuildContext scaffoldContext;
  final Future<void> Function() onShowUrlInfoAfterPopup;
  final Future<void> Function() onTakeScreenshotAfterPopup;

  const WebViewTabQuickActions({
    required this.popupMenuContext,
    required this.scaffoldContext,
    required this.onShowUrlInfoAfterPopup,
    required this.onTakeScreenshotAfterPopup,
    super.key,
  });

  @override
  State<WebViewTabQuickActions> createState() => _WebViewTabQuickActionsState();
}

class _WebViewTabQuickActionsState extends State<WebViewTabQuickActions> {
  @override
  Widget build(BuildContext context) {
    final browserModel = Provider.of<BrowserModel>(context);
    final webViewModel = Provider.of<WebViewModel>(context);
    final favorite = _favoriteFor(webViewModel);
    final isFavorite =
        favorite != null && browserModel.containsFavorite(favorite);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _buildActions(browserModel, webViewModel, favorite, isFavorite),
    );
  }

  List<Widget> _buildActions(
    BrowserModel browserModel,
    WebViewModel webViewModel,
    FavoriteModel? favorite,
    bool isFavorite,
  ) {
    final children = <Widget>[];
    if (Util.isIOS() || Util.isMacOS() || Util.isWindows()) {
      children.add(_buildBackButton(webViewModel));
    }
    children.addAll(
      _buildCommonActions(browserModel, webViewModel, favorite, isFavorite),
    );
    return children;
  }

  Widget _buildBackButton(WebViewModel webViewModel) => _IconMenuButton(
        icon: Icons.arrow_back,
        tooltip: AppLocalizations.of(context).a11yBack,
        onPressed: () {
          webViewModel.webViewController?.goBack();
          Navigator.pop(widget.popupMenuContext);
        },
      );

  List<Widget> _buildCommonActions(
    BrowserModel browserModel,
    WebViewModel webViewModel,
    FavoriteModel? favorite,
    bool isFavorite,
  ) =>
      [
        _buildForwardButton(webViewModel),
        _buildFavoriteButton(browserModel, favorite, isFavorite),
        _buildArchiveButton(browserModel, webViewModel),
        _buildUrlInfoButton(),
        _buildScreenshotButton(),
        _buildRefreshButton(webViewModel),
      ];

  Widget _buildForwardButton(WebViewModel webViewModel) => _IconMenuButton(
        icon: Icons.arrow_forward,
        tooltip: AppLocalizations.of(context).a11yForward,
        onPressed: () {
          webViewModel.webViewController?.goForward();
          Navigator.pop(widget.popupMenuContext);
        },
      );

  Widget _buildFavoriteButton(
    BrowserModel browserModel,
    FavoriteModel? favorite,
    bool isFavorite,
  ) =>
      _IconMenuButton(
        icon: isFavorite ? Icons.star : Icons.star_border,
        tooltip: AppLocalizations.of(context).favorites,
        onPressed: () {
          setState(() {
            _toggleFavorite(browserModel, favorite);
          });
        },
      );

  Widget _buildArchiveButton(
    BrowserModel browserModel,
    WebViewModel webViewModel,
  ) =>
      _IconMenuButton(
        icon: Icons.file_download,
        onPressed: () async {
          Navigator.pop(widget.popupMenuContext);
          await _saveWebArchive(browserModel, webViewModel);
        },
      );

  Widget _buildUrlInfoButton() => _IconMenuButton(
        icon: Icons.info_outline,
        onPressed: () async {
          Navigator.pop(widget.popupMenuContext);
          await widget.onShowUrlInfoAfterPopup();
        },
      );

  Widget _buildScreenshotButton() => _IconMenuButton(
        icon: Icons.screenshot,
        onPressed: () async {
          Navigator.pop(widget.popupMenuContext);
          await widget.onTakeScreenshotAfterPopup();
        },
      );

  Widget _buildRefreshButton(WebViewModel webViewModel) => _IconMenuButton(
        icon: Icons.refresh,
        tooltip: AppLocalizations.of(context).a11yReload,
        onPressed: () {
          webViewModel.webViewController?.reload();
          Navigator.pop(widget.popupMenuContext);
        },
      );

  FavoriteModel? _favoriteFor(WebViewModel webViewModel) {
    final url = webViewModel.url;
    if (url == null || url.toString().isEmpty) {
      return null;
    }
    return FavoriteModel(
      url: url,
      title: webViewModel.title ?? "",
      favicon: webViewModel.favicon,
    );
  }

  void _toggleFavorite(BrowserModel browserModel, FavoriteModel? favorite) {
    if (favorite == null) {
      return;
    }
    if (browserModel.containsFavorite(favorite)) {
      browserModel.removeFavorite(favorite);
      return;
    }
    browserModel.addFavorite(favorite);
  }

  Future<void> _saveWebArchive(
    BrowserModel browserModel,
    WebViewModel webViewModel,
  ) async {
    final l10n = AppLocalizations.of(widget.scaffoldContext);
    final url = webViewModel.url;
    if (url == null || !url.scheme.startsWith("http")) {
      return;
    }

    final webArchiveService = Provider.of<WebArchiveService>(
      widget.scaffoldContext,
      listen: false,
    );
    final webArchiveModel = await webArchiveService.save(
      WebArchiveSaveRequest(
        webViewModel: webViewModel,
        timestamp: DateTime.now(),
      ),
    );

    if (webArchiveModel != null) {
      browserModel.addWebArchive(
        webArchiveModel.url.toString(),
        webArchiveModel,
      );
      _showSnackBar(l10n.savedOffline(webArchiveModel.url.toString()));
      browserModel.save();
      return;
    }

    _showSnackBar(l10n.unableToSave);
  }

  void _showSnackBar(String message) {
    if (!widget.scaffoldContext.mounted) {
      return;
    }
    ScaffoldMessenger.of(widget.scaffoldContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _IconMenuButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const _IconMenuButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30.0,
      child: IconButton(
        padding: const EdgeInsets.all(0.0),
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.black),
        onPressed: onPressed,
      ),
    );
  }
}
