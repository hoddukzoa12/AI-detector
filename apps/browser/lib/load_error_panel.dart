import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// 메인 프레임 로드 실패·타임아웃 때 WebView 위에 덮는 화면.
///
/// `disableDefaultErrorPage = true` 이면 플랫폼 오류 페이지가 없고,
/// `loadData` HTML 도 렌더러/네트워크 상태에 따라 안 그려질 수 있다.
/// Flutter 오버레이로 URL·사유·재시도를 항상 보여 준다.
class LoadErrorPanel extends StatelessWidget {
  const LoadErrorPanel({
    required this.url,
    required this.reason,
    required this.onRetry,
    super.key,
  });

  final String? url;
  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _LoadErrorBody(url: url, reason: reason, onRetry: onRetry),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadErrorBody extends StatelessWidget {
  const _LoadErrorBody({
    required this.url,
    required this.reason,
    required this.onRetry,
  });

  final String? url;
  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.wifi_off_outlined,
          size: 48,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.loadErrorTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          reason.isEmpty ? l10n.loadErrorBodyGeneric : reason,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        _FailedUrlLabel(url: url),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.loadErrorRetry),
        ),
      ],
    );
  }
}

class _FailedUrlLabel extends StatelessWidget {
  const _FailedUrlLabel({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final shownUrl = url;
    if (shownUrl == null || shownUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        shownUrl,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
