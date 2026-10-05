import 'package:shared_preferences/shared_preferences.dart';

const String onboardingSeenKey = 'infocutter.onboarding.seen';

/// Remembers whether the first-run onboarding has already been shown.
abstract interface class OnboardingStore {
  Future<bool> hasSeenOnboarding();

  Future<void> markOnboardingSeen();
}

class SharedPreferencesOnboardingStore implements OnboardingStore {
  const SharedPreferencesOnboardingStore({this.storageKey = onboardingSeenKey});

  final String storageKey;

  @override
  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(storageKey) ?? false;
  }

  @override
  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, true);
  }
}
