import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:provider/provider.dart';

/// 인포커터 패널 요청 — 주소창에 있던 동작을 그대로 옮긴 것.
///
/// 반드시 **현재 탭 모델**(WebViewTab 이 듣고 있는 인스턴스)을 대상으로 한다.
/// 공유 `Provider.of<WebViewModel>` 자리표시자가 아니다.
void requestInfocutterPanel(
  BuildContext context,
  InfocutterPanelMode mode,
  AppLocalizations l10n,
) {
  final webViewModel =
      Provider.of<WindowModel>(context, listen: false).getCurrentWebViewModel();
  final url = webViewModel?.url;
  if (webViewModel == null || url == null || url.host.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.openWebPageFirst)),
    );
    return;
  }
  webViewModel.infocutterPanelRequest.value = mode;
}

/// 현재 사이트에서 실제로 가려지고 있는 규칙 수.
///
/// 사용자가 몇 개를 가렸는지 아는 유일한 단서라 배지로 노출한다.
int activeHiddenCount(BuildContext context, Uri? url) {
  if (url == null || url.host.isEmpty) {
    return 0;
  }
  final state = context
      .watch<BlockRuleRepository>()
      .buildActiveSiteState(Uri.parse(url.toString()));
  return state.globalEnabled && state.profileEnabled
      ? state.enabledSelectorCount
      : 0;
}

/// 인포커터 "더보기" 메뉴 — 감시/네트워크/관리/모듈/설정.
class InfocutterMoreMenu extends StatelessWidget {
  const InfocutterMoreMenu({
    required this.color,
    this.iconSize = 22,
    super.key,
  });

  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<InfocutterPanelMode>(
      tooltip: l10n.infocutterManageRemovedCategory,
      icon: Icon(Icons.more_vert, color: color, size: iconSize),
      onSelected: (mode) => requestInfocutterPanel(context, mode, l10n),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: InfocutterPanelMode.watch,
          child: Text(l10n.infocutterWatchAutoRemoveTab),
        ),
        PopupMenuItem(
          value: InfocutterPanelMode.network,
          child: Text(l10n.infocutterNetworkRequestBlockTab),
        ),
        PopupMenuItem(
          value: InfocutterPanelMode.manage,
          child: Text(l10n.infocutterManageRemovedCategory),
        ),
        PopupMenuItem(
          value: InfocutterPanelMode.modules,
          child: Text(l10n.infocutterModulesTab),
        ),
        PopupMenuItem(
          value: InfocutterPanelMode.settings,
          child: Text(l10n.infocutterGlobalSettingsTab),
        ),
      ],
    );
  }
}
