import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/app_bar/address_display.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/services/address_suggestions.dart';
import 'package:infocutter_app/services/browser_url_resolver.dart';
import 'package:infocutter_app/theme/infocutter_tokens.g.dart';
import 'package:infocutter_app/util.dart';
import 'package:provider/provider.dart';

/// 주소창. **신원(자물쇠)과 주소만** 담는다.
///
/// 인포커터 동작 버튼은 하단 액션바로 내려갔다. 예전에는 `Stack` + `Positioned`
/// 로 TextField 위에 버튼 4개(128px)를 얹고 `contentPadding` 으로 48px 만
/// 비워 둬서 URL 이 아이콘 밑으로 파고들었다. 지금은 자물쇠마저
/// `InputDecoration.prefixIcon` 으로 옮겨 프레임워크가 여백을 예약하게 했다.
class WebViewTabAddressField extends StatefulWidget {
  final TextEditingController? searchController;
  final FocusNode? focusNode;
  final VoidCallback onShowUrlInfo;
  final void Function(WebUri url) onOpenUrlInNewTab;

  const WebViewTabAddressField({
    required this.searchController,
    required this.focusNode,
    required this.onShowUrlInfo,
    required this.onOpenUrlInNewTab,
    super.key,
  });

  @override
  State<WebViewTabAddressField> createState() => _WebViewTabAddressFieldState();
}

class _WebViewTabAddressFieldState extends State<WebViewTabAddressField> {
  static const _outlineBorder = OutlineInputBorder(
    borderSide: BorderSide(color: Colors.transparent, width: 0.0),
    borderRadius: BorderRadius.all(Radius.circular(50.0)),
  );

  bool _shouldSelectText = true;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocusChanged);
    widget.searchController?.addListener(_onAddressChanged);
  }

  @override
  void didUpdateWidget(covariant WebViewTabAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      widget.focusNode?.addListener(_onFocusChanged);
    }
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_onAddressChanged);
      widget.searchController?.addListener(_onAddressChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChanged);
    widget.searchController?.removeListener(_onAddressChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onAddressChanged() {
    if (mounted && _showSummary) setState(() {});
  }

  /// 요약 표시는 모바일 전용이다 — 데스크톱은 늘 편집 상태의 주소창을 쓴다.
  bool get _showSummary =>
      Util.isMobile() && !(widget.focusNode?.hasFocus ?? false);

  @override
  Widget build(BuildContext context) {
    final browserModel = Provider.of<BrowserModel>(context);
    final settings = browserModel.getSettings();
    final webViewModel = Provider.of<WebViewModel>(context);
    final l10n = AppLocalizations.of(context);
    final tokens = InfocutterTokens(Theme.of(context).brightness);

    // TextField 는 늘 트리에 살아 있어야 한다 — cmd+L 처럼 밖에서 포커스를
    // 요청하는 경로가 focusNode 를 통해 그대로 동작해야 하기 때문이다.
    // 포커스가 없을 때만 같은 자리를 요약이 통째로(Positioned.fill) 덮는다.
    return SizedBox(
      height: 40.0,
      child: Stack(
        children: <Widget>[
          _buildAddressInput(
            hintText: l10n.searchOrTypeWebAddress,
            settings: settings,
            webViewModel: webViewModel,
            tokens: tokens,
          ),
          if (_showSummary)
            Positioned.fill(
              child: _buildAddressSummary(
                hintText: l10n.searchOrTypeWebAddress,
                webViewModel: webViewModel,
                tokens: tokens,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressInput({
    required String hintText,
    required BrowserSettings settings,
    required WebViewModel webViewModel,
    required InfocutterTokens tokens,
  }) {
    return RawAutocomplete<AddressSuggestion>(
      textEditingController: widget.searchController,
      focusNode: widget.focusNode,
      optionsBuilder: _optionsForQuery,
      displayStringForOption: (option) => option.url,
      onSelected: (option) {
        widget.searchController?.text = option.url;
        _submitAddress(option.url, settings, webViewModel);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          onSubmitted: (value) =>
              _submitAddress(value, settings, webViewModel),
          onTap: _selectAddressText,
          onTapOutside: (event) {
            _shouldSelectText = true;
          },
          keyboardType: TextInputType.url,
          focusNode: focusNode,
          controller: controller,
          textInputAction: TextInputAction.go,
          decoration: _addressDecoration(hintText, webViewModel, tokens),
          style: TextStyle(color: tokens.text, fontSize: 16.0),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _AddressSuggestionList(
          options: options,
          onSelected: onSelected,
        );
      },
    );
  }

  Iterable<AddressSuggestion> _optionsForQuery(TextEditingValue value) {
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final openTabUrls = windowModel.webViewModels
        .map((tab) => tab.url?.toString() ?? '')
        .where((url) => url.isNotEmpty);
    return const AddressSuggestions().suggest(
      AddressSuggestionQuery(
        query: value.text,
        favorites: browserModel.favorites,
        openTabUrls: openTabUrls,
        recentUrls: browserModel.webArchives.keys,
      ),
    );
  }

  /// 포커스가 없을 때 보여줄 요약. 편집이 아니라 **읽기**를 위한 화면이라
  /// `https://`·`www.` 를 접고 호스트를 강조한다. 누르면 편집으로 넘어간다.
  Widget _buildAddressSummary({
    required String hintText,
    required WebViewModel webViewModel,
    required InfocutterTokens tokens,
  }) {
    final raw = widget.searchController?.text ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _beginEditing,
      child: InputDecorator(
        decoration: _addressDecoration(hintText, webViewModel, tokens),
        isEmpty: raw.trim().isEmpty,
        child: _buildAddressText(raw, tokens),
      ),
    );
  }

  Widget _buildAddressText(String raw, InfocutterTokens tokens) {
    final display = displayAddress(raw);
    if (display.isEmpty) {
      return const SizedBox.shrink();
    }

    final host = displayAddressHost(raw);
    final mutedStyle = TextStyle(color: tokens.mutedText, fontSize: 16.0);
    if (host.isEmpty || !display.startsWith(host)) {
      return Text(display,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: mutedStyle);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: host,
            style: TextStyle(
              color: tokens.text,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: display.substring(host.length), style: mutedStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _beginEditing() {
    widget.focusNode?.requestFocus();
    _selectAddressText();
  }

  InputDecoration _addressDecoration(
    String hintText,
    WebViewModel webViewModel,
    InfocutterTokens tokens,
  ) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
      filled: true,
      fillColor: tokens.inputFill,
      border: _outlineBorder,
      focusedBorder: _outlineBorder,
      enabledBorder: _outlineBorder,
      hintText: hintText,
      hintStyle: TextStyle(color: tokens.mutedText, fontSize: 16.0),
      // prefixIcon 은 아이콘 폭만큼 여백을 스스로 예약한다 — 손으로 맞추던
      // contentPadding 좌우 하드코딩(45/48)이 사라진 이유다.
      prefixIcon: _buildSecurityButton(webViewModel, tokens),
    );
  }

  void _submitAddress(
    String value,
    BrowserSettings settings,
    WebViewModel webViewModel,
  ) {
    final url = _addressToUrl(value, settings);
    final controller = webViewModel.webViewController;
    if (controller != null) {
      controller.loadUrl(urlRequest: URLRequest(url: url));
      return;
    }

    widget.onOpenUrlInNewTab(url);
    webViewModel.url = url;
  }

  WebUri _addressToUrl(String value, BrowserSettings settings) {
    return const BrowserUrlResolver().resolve(value, settings);
  }

  void _selectAddressText() {
    final searchController = widget.searchController;
    if (!_shouldSelectText ||
        searchController == null ||
        searchController.text.isEmpty) {
      return;
    }

    _shouldSelectText = false;
    searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: searchController.text.length,
    );
  }

  Widget _buildSecurityButton(
    WebViewModel webViewModel,
    InfocutterTokens tokens,
  ) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.a11ySiteInfo,
      icon: Selector<WebViewModel, bool>(
        selector: (context, webViewModel) => webViewModel.isSecure,
        builder: (context, isSecure, child) {
          return Icon(
            _securityIcon(webViewModel, isSecure),
            color: isSecure ? tokens.accent : tokens.mutedText,
          );
        },
      ),
      onPressed: widget.onShowUrlInfo,
    );
  }

  IconData _securityIcon(WebViewModel webViewModel, bool isSecure) {
    if (webViewModel.isIncognitoMode) {
      return Icons.visibility_off;
    }
    if (isSecure && webViewModel.url?.scheme == "file") {
      return Icons.offline_pin;
    }
    if (isSecure) {
      return Icons.lock;
    }
    return Icons.info_outline;
  }
}

class _AddressSuggestionList extends StatelessWidget {
  const _AddressSuggestionList({
    required this.options,
    required this.onSelected,
  });

  final Iterable<AddressSuggestion> options;
  final AutocompleteOnSelected<AddressSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 480),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                dense: true,
                leading: Icon(_iconFor(option.source), size: 18),
                title: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  option.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AddressSuggestionSource source) {
    return switch (source) {
      AddressSuggestionSource.favorite => Icons.star_outline,
      AddressSuggestionSource.openTab => Icons.tab,
      AddressSuggestionSource.recent => Icons.history,
    };
  }
}
