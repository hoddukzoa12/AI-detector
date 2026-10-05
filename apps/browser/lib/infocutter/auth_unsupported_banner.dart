import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// 임베디드 웹뷰 로그인이 정책으로 막히는 인증 origin 안내 배너.
/// 앱 버그로 오인되지 않게 이유를 밝히고 기본 브라우저 탈출구를 준다.
class AuthUnsupportedBanner extends StatelessWidget {
  const AuthUnsupportedBanner({required this.onOpenExternally, super.key});

  final VoidCallback onOpenExternally;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.authUnsupportedTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.authUnsupportedBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onOpenExternally,
                    child: Text(l10n.authOpenExternally),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
