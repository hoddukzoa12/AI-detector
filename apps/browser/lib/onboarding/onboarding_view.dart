import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// The single first-run card that explains how hiding elements is reached.
///
/// It stays one screen on purpose: the two things a first-time user needs are
/// "where the picker lives" and "how to peek at what is hidden".
class OnboardingView extends StatelessWidget {
  const OnboardingView({
    required this.onStart,
    required this.onSkip,
    super.key,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.onboardingTitle,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            OnboardingStep(
              icon: Icons.content_cut,
              body: l10n.onboardingPickBody,
            ),
            const SizedBox(height: 14),
            OnboardingStep(
              icon: Icons.visibility_outlined,
              body: l10n.onboardingPeekBody,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(l10n.onboardingSkip),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onStart,
                  child: Text(l10n.onboardingStart),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class OnboardingStep extends StatelessWidget {
  const OnboardingStep({required this.icon, required this.body, super.key});

  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(body, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
