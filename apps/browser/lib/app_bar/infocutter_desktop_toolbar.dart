import 'package:flutter/material.dart';
import 'package:infocutter_app/app_bar/infocutter_actions.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/theme/infocutter_tokens.g.dart';
import 'package:provider/provider.dart';

/// 데스크톱 앱바에 인포커터 핵심 진입점을 노출한다.
///
/// 모바일은 하단 [BrowserBottomActionBar] 가 담당하고, 맥/윈도우는 여기만 있다.
class InfocutterDesktopToolbar extends StatelessWidget {
  const InfocutterDesktopToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = InfocutterTokens(Theme.of(context).brightness);
    final url = context.select<WebViewModel, Uri?>((m) => m.url);
    final hidden = activeHiddenCount(context, url);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Badge(
          isLabelVisible: hidden > 0,
          label: Text('$hidden'),
          offset: const Offset(-2, 4),
          child: IconButton(
            tooltip: l10n.infocutterPickBlockRemoveTab,
            icon: Icon(Icons.content_cut, color: tokens.primary, size: 20),
            onPressed: () => requestInfocutterPanel(
              context,
              InfocutterPanelMode.block,
              l10n,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.infocutterKeywordBlockRemoveTab,
          icon: Icon(Icons.text_fields, color: tokens.primary, size: 20),
          onPressed: () => requestInfocutterPanel(
            context,
            InfocutterPanelMode.keyword,
            l10n,
          ),
        ),
        IconButton(
          tooltip: l10n.infocutterAiRecommendRemoveTab,
          icon: Icon(Icons.auto_awesome, color: tokens.primary, size: 20),
          onPressed: () => requestInfocutterPanel(
            context,
            InfocutterPanelMode.ai,
            l10n,
          ),
        ),
        InfocutterMoreMenu(color: tokens.primary, iconSize: 20),
      ],
    );
  }
}
