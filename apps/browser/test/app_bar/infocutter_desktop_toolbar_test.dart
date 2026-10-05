import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/app_bar/infocutter_desktop_toolbar.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('desktop toolbar exposes pick / keyword / ai entry points',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<BlockRuleRepository>(
            create: (_) =>
                InfocutterServiceBlockRuleRepository(InfocutterService()),
          ),
          ChangeNotifierProvider(create: (_) => WindowModel()),
          ChangeNotifierProvider(create: (_) => WebViewModel()),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InfocutterDesktopToolbar()),
        ),
      ),
    );

    expect(find.byIcon(Icons.content_cut), findsOneWidget);
    expect(find.byIcon(Icons.text_fields), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });
}
