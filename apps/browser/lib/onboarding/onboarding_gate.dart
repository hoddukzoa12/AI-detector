import 'package:flutter/material.dart';
import 'package:infocutter_app/onboarding/onboarding_store.dart';
import 'package:infocutter_app/onboarding/onboarding_view.dart';

/// Shows the first-run onboarding once, then never again.
///
/// Returns `true` when the dialog was actually presented. The seen flag is
/// written as soon as the card is shown, so skipping counts as "seen" too.
Future<bool> showOnboardingIfNeeded(
  BuildContext context, {
  OnboardingStore store = const SharedPreferencesOnboardingStore(),
}) async {
  if (await store.hasSeenOnboarding()) return false;
  if (!context.mounted) return false;

  await store.markOnboardingSeen();
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      child: OnboardingView(
        onStart: () => Navigator.of(dialogContext).pop(),
        onSkip: () => Navigator.of(dialogContext).pop(),
      ),
    ),
  );
  return true;
}
