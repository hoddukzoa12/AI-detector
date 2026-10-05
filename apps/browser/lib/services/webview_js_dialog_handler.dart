import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// WebView `alert` / `confirm` / `prompt` 를 Flutter 다이얼로그로 중계한다.
///
/// 핸들러를 안 붙이면 일부 플랫폼에서 다이얼로그가 먹통이거나 무시된다 (#14).
class WebViewJsDialogHandler {
  const WebViewJsDialogHandler();

  Future<JsAlertResponse?> onAlert(
    BuildContext context,
    JsAlertRequest request,
  ) async {
    final l10n = AppLocalizations.of(context);
    await _showSimpleDialog(
      context,
      title: request.message ?? l10n.jsDialogDefaultTitle,
      message: request.message,
      l10n: l10n,
      showCancel: false,
    );
    return JsAlertResponse(
      handledByClient: true,
      action: JsAlertResponseAction.CONFIRM,
    );
  }

  Future<JsConfirmResponse?> onConfirm(
    BuildContext context,
    JsConfirmRequest request,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _showSimpleDialog(
      context,
      title: l10n.jsDialogDefaultTitle,
      message: request.message,
      l10n: l10n,
      showCancel: true,
    );
    return JsConfirmResponse(
      handledByClient: true,
      action: ok == true
          ? JsConfirmResponseAction.CONFIRM
          : JsConfirmResponseAction.CANCEL,
    );
  }

  Future<JsPromptResponse?> onPrompt(
    BuildContext context,
    JsPromptRequest request,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: request.defaultValue ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _PromptDialog(
        title: l10n.jsDialogDefaultTitle,
        message: request.message ?? '',
        controller: controller,
        cancelLabel: l10n.cancel,
        okLabel: l10n.ok,
      ),
    );
    controller.dispose();
    if (value == null) {
      return JsPromptResponse(
        handledByClient: true,
        action: JsPromptResponseAction.CANCEL,
      );
    }
    return JsPromptResponse(
      handledByClient: true,
      action: JsPromptResponseAction.CONFIRM,
      value: value,
    );
  }

  Future<bool?> _showSimpleDialog(
    BuildContext context, {
    required String title,
    required String? message,
    required AppLocalizations l10n,
    required bool showCancel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: (message == null || message.isEmpty)
            ? null
            : SingleChildScrollView(child: Text(message)),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}

class _PromptDialog extends StatelessWidget {
  const _PromptDialog({
    required this.title,
    required this.message,
    required this.controller,
    required this.cancelLabel,
    required this.okLabel,
  });

  final String title;
  final String message;
  final TextEditingController controller;
  final String cancelLabel;
  final String okLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message),
            ),
          TextField(controller: controller, autofocus: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(okLabel),
        ),
      ],
    );
  }
}
