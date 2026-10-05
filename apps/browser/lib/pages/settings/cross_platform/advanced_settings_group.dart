import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// WebView 원시 설정처럼 대부분의 사용자가 건드릴 일 없는 묶음을 접어 둔다.
///
/// 접힌 상태에서도 자식은 트리에 남긴다(Offstage). 설정 위젯들이 컨트롤러와
/// 로컬 상태를 들고 있어서 펼칠 때마다 새로 만들면 입력 중이던 값이 날아가고,
/// 렌더 항목 수를 고정한 회귀 테스트(test/pages/settings_smoke_test.dart)도
/// 접힘 여부에 따라 흔들린다.
class AdvancedSettingsGroup extends StatefulWidget {
  const AdvancedSettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  State<AdvancedSettingsGroup> createState() => _AdvancedSettingsGroupState();
}

class _AdvancedSettingsGroupState extends State<AdvancedSettingsGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        _buildHeader(context),
        Offstage(
          offstage: !_expanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.children,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsAdvanced,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n.settingsAdvancedSubtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more),
            ),
          ],
        ),
      ),
    );
  }
}
