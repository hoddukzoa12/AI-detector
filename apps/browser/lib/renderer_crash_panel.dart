import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// 렌더러 프로세스가 반복해서 죽었을 때 웹뷰 위에 덮는 화면.
///
/// HTML 오류 페이지로는 이 상황을 못 그린다 — 그릴 렌더러가 이미 죽었기
/// 때문이다. 그래서 Flutter 위젯으로 덮는다.
class RendererCrashPanel extends StatelessWidget {
  const RendererCrashPanel({
    required this.url,
    required this.onRetry,
    super.key,
  });

  /// 죽는 순간 열려 있던 주소. 없으면 표시하지 않는다.
  final String? url;
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
              child: _RendererCrashBody(url: url, onRetry: onRetry),
            ),
          ),
        ),
      ),
    );
  }
}

class _RendererCrashBody extends StatelessWidget {
  const _RendererCrashBody({required this.url, required this.onRetry});

  final String? url;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.report_gmailerrorred_outlined,
          size: 48,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.rendererCrashTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.rendererCrashBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        _CrashedUrlLabel(url: url),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.rendererCrashRetry),
        ),
      ],
    );
  }
}

/// 주소가 없으면(about:blank 등) 자리만 차지하지 않게 아무것도 그리지 않는다.
class _CrashedUrlLabel extends StatelessWidget {
  const _CrashedUrlLabel({required this.url});

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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
