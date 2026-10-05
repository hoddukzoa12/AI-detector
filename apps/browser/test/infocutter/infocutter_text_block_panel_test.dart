import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_text_block_panel.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness({
  required ValueListenable<String?> capturedKeyword,
  ValueListenable<bool>? keywordCaptureActive,
  void Function(bool active)? onSetKeywordCapture,
}) {
  return ChangeNotifierProvider<TextBlockService>(
    create: (_) => TextBlockService(),
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InfocutterTextBlockPanel(
          url: Uri.parse('https://example.com'),
          onTextBlocksChanged: () async {},
          showHeader: false,
          capturedKeyword: capturedKeyword,
          keywordCaptureActive: keywordCaptureActive,
          onSetKeywordCapture: onSetKeywordCapture,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'toggling 키워드 잡기 fires onSetKeywordCapture(true)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool? capturedValue;
      final keyword = ValueNotifier<String?>(null);
      addTearDown(keyword.dispose);

      await tester.pumpWidget(
        _harness(
          capturedKeyword: keyword,
          onSetKeywordCapture: (active) => capturedValue = active,
        ),
      );
      await tester.pumpAndSettle();

      // Toggle should be visible when onSetKeywordCapture is provided.
      expect(find.text('키워드 잡기'), findsOneWidget);

      await tester.tap(find.text('키워드 잡기'));
      await tester.pumpAndSettle();

      expect(capturedValue, isTrue);
    },
  );

  testWidgets(
    'setting capturedKeyword fills the keyword TextField',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final keyword = ValueNotifier<String?>(null);
      addTearDown(keyword.dispose);

      await tester.pumpWidget(
        _harness(
          capturedKeyword: keyword,
          onSetKeywordCapture: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Initially empty.
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        anyOf(isNull, isEmpty),
      );

      keyword.value = '광고';
      await tester.pump();

      final keywordField = find.byType(TextField).first;
      expect(
        tester.widget<TextField>(keywordField).controller?.text,
        '광고',
      );
    },
  );

  testWidgets(
    'toggle is hidden when onSetKeywordCapture is null',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final keyword = ValueNotifier<String?>(null);
      addTearDown(keyword.dispose);

      await tester.pumpWidget(
        _harness(
          capturedKeyword: keyword,
          // onSetKeywordCapture intentionally omitted → toggle should not render.
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('키워드 잡기'), findsNothing);
    },
  );
}
