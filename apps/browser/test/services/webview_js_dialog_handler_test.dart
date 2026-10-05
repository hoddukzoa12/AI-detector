import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/services/webview_js_dialog_handler.dart';

void main() {
  testWidgets('js alert dialog confirms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  await const WebViewJsDialogHandler().onAlert(
                    context,
                    JsAlertRequest(message: 'hello-alert'),
                  );
                },
                child: const Text('go'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('hello-alert'), findsWidgets);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  });
}
