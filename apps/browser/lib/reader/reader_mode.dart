import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';

/// 현재 페이지에서 본문 후보를 뽑아 읽기용 화면으로 연다 (#17 reader-first).
///
/// 완전 readability 엔진이 아니라 article/main/body 휴리스틱이다.
class ReaderMode {
  const ReaderMode();

  static const extractJs = r'''
(function () {
  function textOf(el) {
    if (!el) return '';
    return (el.innerText || el.textContent || '').replace(/\s+\n/g, '\n').trim();
  }
  var root =
    document.querySelector('article') ||
    document.querySelector('[role="main"]') ||
    document.querySelector('main') ||
    document.body;
  var title =
    (document.querySelector('h1') && document.querySelector('h1').innerText) ||
    document.title ||
    '';
  var text = textOf(root);
  if (text.length < 80 && document.body) {
    text = textOf(document.body);
  }
  return JSON.stringify({
    title: String(title).trim(),
    text: text,
    url: location.href,
    length: text.length
  });
})();
''';

  Future<void> openFromController(
    BuildContext context,
    InAppWebViewController? controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.openWebPageFirst)),
      );
      return;
    }
    try {
      final raw = await controller.evaluateJavascript(source: extractJs);
      final decoded = _decodePayload(raw);
      if (decoded == null || (decoded['text'] as String?)?.trim().isEmpty == true) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.readerModeEmpty)),
        );
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderModePage(
            title: (decoded['title'] as String?)?.trim().isNotEmpty == true
                ? decoded['title'] as String
                : l10n.readerModeTitle,
            body: decoded['text'] as String,
            sourceUrl: decoded['url'] as String? ?? '',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.readerModeFailed)),
      );
    }
  }

  Map<String, dynamic>? _decodePayload(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      var s = raw.trim();
      if (s.startsWith('"') && s.endsWith('"')) {
        s = jsonDecode(s) as String;
      }
      final v = jsonDecode(s);
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return null;
  }
}

class ReaderModePage extends StatelessWidget {
  const ReaderModePage({
    required this.title,
    required this.body,
    required this.sourceUrl,
    super.key,
  });

  final String title;
  final String body;
  final String sourceUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.readerModeTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (sourceUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                sourceUrl,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SelectableText(
              body,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.55,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
