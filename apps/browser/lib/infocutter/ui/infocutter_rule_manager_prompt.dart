import 'package:flutter/material.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

class InfocutterPromptTextRequest {
  const InfocutterPromptTextRequest({
    required this.title,
    required this.initialValue,
    this.hintText,
    this.maxLines = 1,
    this.requireNonEmpty = false,
    this.saveLabel,
    this.supportingText,
  });

  final String title;
  final String initialValue;
  final String? hintText;
  final int maxLines;
  final bool requireNonEmpty;
  final String? saveLabel;
  final String? supportingText;
}

Future<String?> promptInfocutterText(
  BuildContext context,
  InfocutterPromptTextRequest request,
) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PromptTextDialog(request: request),
  );
}

class _PromptTextDialog extends StatefulWidget {
  const _PromptTextDialog({required this.request});

  final InfocutterPromptTextRequest request;

  @override
  State<_PromptTextDialog> createState() => _PromptTextDialogState();
}

class _PromptTextDialogState extends State<_PromptTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.request.initialValue)
      ..addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = widget.request;
    return AlertDialog(
      title: Text(request.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.supportingText != null) ...[
            Text(
              request.supportingText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: request.hintText,
              border: const OutlineInputBorder(),
            ),
            maxLines: request.maxLines,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          child: Text(request.saveLabel ?? l10n.infocutterSave),
        ),
      ],
    );
  }

  bool get _canSave =>
      !widget.request.requireNonEmpty || _controller.text.trim().isNotEmpty;

  void _handleTextChanged() {
    setState(() {});
  }
}
