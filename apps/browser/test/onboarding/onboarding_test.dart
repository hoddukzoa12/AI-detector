import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/onboarding/onboarding_gate.dart';
import 'package:infocutter_app/onboarding/onboarding_store.dart';
import 'package:infocutter_app/onboarding/onboarding_view.dart';

class _FakeOnboardingStore implements OnboardingStore {
  bool seen = false;
  int markCount = 0;

  @override
  Future<bool> hasSeenOnboarding() async => seen;

  @override
  Future<void> markOnboardingSeen() async {
    markCount++;
    seen = true;
  }
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Widget _gateHarness(OnboardingStore store) => _app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showOnboardingIfNeeded(context, store: store),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the onboarding card renders both discovery hints',
      (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: OnboardingView(onStart: () {}, onSkip: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('보고 싶은 것만 남기세요'), findsOneWidget);
    expect(find.textContaining('가위 버튼'), findsOneWidget);
    expect(find.textContaining('미리보기'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('건너뛰기'), findsOneWidget);
  });

  testWidgets('skip dismisses the card', (tester) async {
    final store = _FakeOnboardingStore();
    await tester.pumpWidget(_gateHarness(store));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingView), findsOneWidget);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingView), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('start dismisses the card', (tester) async {
    final store = _FakeOnboardingStore();
    await tester.pumpWidget(_gateHarness(store));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingView), findsNothing);
  });

  testWidgets('the card never returns once the seen flag is stored',
      (tester) async {
    final store = _FakeOnboardingStore();
    await tester.pumpWidget(_gateHarness(store));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingView), findsNothing);
    expect(store.markCount, 1);
  });

  test('a store that has never been written reports unseen', () async {
    final store = _FakeOnboardingStore();

    expect(await store.hasSeenOnboarding(), isFalse);
    await store.markOnboardingSeen();
    expect(await store.hasSeenOnboarding(), isTrue);
    expect(onboardingSeenKey, 'infocutter.onboarding.seen');
  });
}
