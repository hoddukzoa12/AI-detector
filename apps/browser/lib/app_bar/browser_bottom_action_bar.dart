import 'package:flutter/material.dart';
import 'package:infocutter_app/app_bar/infocutter_actions.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/theme/infocutter_tokens.g.dart';
import 'package:infocutter_app/util.dart';
import 'package:provider/provider.dart';

/// 모바일 하단 액션바.
///
/// 왼쪽부터 **뒤로 · 앞으로**(브라우저 이동, 중립색)와
/// **가리기 · 키워드 · AI · 더보기**(인포커터 동작, 브랜드색)를 담는다.
/// 역할을 색으로 갈라 두 무리가 섞여 보이지 않게 한다.
///
/// 데스크톱은 별도 앱바·탭스트립 체계가 있으므로 아무것도 그리지 않는다.
class BrowserBottomActionBar extends StatelessWidget {
  const BrowserBottomActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Util.isMobile()) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final tokens = InfocutterTokens(Theme.of(context).brightness);

    return Semantics(
      container: true,
      label: l10n.a11yActionBar,
      child: BottomAppBar(
        color: tokens.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: InfocutterTokens.spaceSm,
        ),
        height: 56,
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavigationButtons(tokens: tokens, l10n: l10n),
              _InfocutterButtons(tokens: tokens, l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationButtons extends StatelessWidget {
  const _NavigationButtons({required this.tokens, required this.l10n});

  final InfocutterTokens tokens;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // WebViewModel 은 canGoBack/canGoForward 를 상태로 들고 있지 않다.
    // 없는 상태를 지어내지 않고, 조종할 웹뷰가 있는지만으로 활성화를 정한다.
    final controller = context
        .watch<WindowModel>()
        .getCurrentWebViewModel()
        ?.webViewController;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarButton(
          icon: Icons.arrow_back,
          tooltip: l10n.a11yBack,
          color: tokens.text,
          onPressed: controller?.goBack,
        ),
        _BarButton(
          icon: Icons.arrow_forward,
          tooltip: l10n.a11yForward,
          color: tokens.text,
          onPressed: controller?.goForward,
        ),
      ],
    );
  }
}

class _InfocutterButtons extends StatelessWidget {
  const _InfocutterButtons({required this.tokens, required this.l10n});

  final InfocutterTokens tokens;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final url = context.select<WebViewModel, Uri?>((model) => model.url);
    final hiddenCount = activeHiddenCount(context, url);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Badge(
          isLabelVisible: hiddenCount > 0,
          label: Text('$hiddenCount'),
          offset: const Offset(-4, 4),
          child: _BarButton(
            icon: Icons.content_cut,
            tooltip: l10n.infocutterPickBlockRemoveTab,
            color: tokens.primary,
            onPressed: () => requestInfocutterPanel(
              context,
              InfocutterPanelMode.block,
              l10n,
            ),
          ),
        ),
        _BarButton(
          icon: Icons.text_fields,
          tooltip: l10n.infocutterKeywordBlockRemoveTab,
          color: tokens.primary,
          onPressed: () => requestInfocutterPanel(
            context,
            InfocutterPanelMode.keyword,
            l10n,
          ),
        ),
        _BarButton(
          icon: Icons.auto_awesome,
          tooltip: l10n.infocutterAiRecommendRemoveTab,
          color: tokens.primary,
          onPressed: () => requestInfocutterPanel(
            context,
            InfocutterPanelMode.ai,
            l10n,
          ),
        ),
        InfocutterMoreMenu(color: tokens.primary),
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = InfocutterTokens(Theme.of(context).brightness);
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      color: color,
      disabledColor: tokens.mutedText,
      onPressed: onPressed,
    );
  }
}
