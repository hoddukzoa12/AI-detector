import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_backup_contributors.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_modules_panel.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('backup contributors keep stable bundle keys', () {
    expect(
      infocutterBackupContributors.map((contributor) => contributor.key),
      ['block', 'textBlocks', 'watch', 'network'],
    );
  });

  testWidgets('renders a switch per module + backup/restore buttons',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<BlockRuleRepository>(
            create: (_) =>
                InfocutterServiceBlockRuleRepository(InfocutterService()),
          ),
          ChangeNotifierProvider<TextBlockService>(
            create: (_) => TextBlockService(),
          ),
          ChangeNotifierProvider<WatchService>(create: (_) => WatchService()),
          ChangeNotifierProvider<NetworkFilterService>(
            create: (_) => NetworkFilterService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterModulesPanel(
              onRulesChanged: () async {},
              onReloadRules: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNWidgets(4));
    expect(find.text('내보내기'), findsOneWidget);
    expect(find.text('가져오기'), findsOneWidget);
  });

  testWidgets('importing a non-bundle paste is rejected without wiping data',
      (tester) async {
    final watch = WatchService();
    await watch.load();
    await watch.addTarget(name: '홍길동');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<BlockRuleRepository>(
            create: (_) =>
                InfocutterServiceBlockRuleRepository(InfocutterService()),
          ),
          ChangeNotifierProvider<TextBlockService>(
            create: (_) => TextBlockService(),
          ),
          ChangeNotifierProvider<WatchService>.value(value: watch),
          ChangeNotifierProvider<NetworkFilterService>(
            create: (_) => NetworkFilterService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterModulesPanel(
              onRulesChanged: () async {},
              onReloadRules: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '가져오기'));
    await tester.pumpAndSettle();
    final importButton = find.widgetWithText(FilledButton, '가져오기');
    expect(tester.widget<FilledButton>(importButton).onPressed, isNull);

    // A JSON object that is NOT our bundle (no version key).
    await tester.enterText(find.byType(TextField), '{"watch": {}}');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(importButton).onPressed, isNotNull);

    await tester.tap(importButton);
    await tester.pumpAndSettle();

    expect(find.text('올바른 설정 형식이 아닙니다'), findsOneWidget);
    expect(watch.targets, isNotEmpty); // not wiped
  });

  testWidgets('toggling a module switch flips its service', (tester) async {
    final textBlocks = TextBlockService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<BlockRuleRepository>(
            create: (_) =>
                InfocutterServiceBlockRuleRepository(InfocutterService()),
          ),
          ChangeNotifierProvider<TextBlockService>.value(value: textBlocks),
          ChangeNotifierProvider<WatchService>(create: (_) => WatchService()),
          ChangeNotifierProvider<NetworkFilterService>(
            create: (_) => NetworkFilterService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InfocutterModulesPanel(
              onRulesChanged: () async {},
              onReloadRules: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = textBlocks.globalEnabled;
    await tester.tap(find.text('문구가 있는 블록 지우기'));
    await tester.pumpAndSettle();
    expect(textBlocks.globalEnabled, !before);
  });
}
