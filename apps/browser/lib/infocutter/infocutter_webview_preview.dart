import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/selection_session.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';

/// Page-side helpers used by [InfocutterWebViewCoordinator] to count selector
/// matches and to temporarily reveal a stored rule's target on the live page.
Future<int?> countInfocutterSelectorMatches(
  InAppWebViewController controller,
  String selector,
) async {
  final trimmed = selector.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final raw = await controller.evaluateJavascript(
    source:
        'window.$infocutterPickerRuntimeObjectName && window.$infocutterPickerRuntimeObjectName.countMatches(${jsonEncode(trimmed)})',
  );
  if (raw is num) {
    return raw.toInt();
  }
  return null;
}

Future<void> setInfocutterRuntimePeek(
  InAppWebViewController controller, {
  required bool enabled,
}) async {
  await controller.evaluateJavascript(
    source:
        'window.$infocutterBlockRuntimeObjectName && window.$infocutterBlockRuntimeObjectName.setPeek(${enabled ? 'true' : 'false'})',
  );
}

Future<void> scrollFirstInfocutterMatchIntoView(
  InAppWebViewController controller,
  String selector,
) async {
  final trimmed = selector.trim();
  if (trimmed.isEmpty) return;
  await controller.evaluateJavascript(
    source: '''
        (function () {
          var el = null;
          try { el = document.querySelector(${jsonEncode(trimmed)}); } catch (e) {}
          if (!el || typeof el.scrollIntoView !== 'function') return false;
          el.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'smooth' });
          return true;
        })()
      ''',
  );
}

Future<void> setInfocutterPreviewStyle(
  InAppWebViewController controller, {
  required String selector,
}) async {
  final trimmed = selector.trim();
  // A real CSS selector never contains braces; reject them so an imported /
  // hand-edited selector can't break out of the rule and inject CSS.
  if (trimmed.isEmpty || trimmed.contains('{') || trimmed.contains('}')) {
    return;
  }
  await controller.evaluateJavascript(
    source: '''
        (function () {
          var id = '__infocutter_preview_style';
          var style = document.getElementById(id);
          if (!style) {
            style = document.createElement('style');
            style.id = id;
            (document.head || document.documentElement).appendChild(style);
          }
          style.textContent = ${jsonEncode('$trimmed { display: revert !important; visibility: visible !important; opacity: 1 !important; }')};
        })()
      ''',
  );
}

Future<void> clearInfocutterPreviewStyle(
  InAppWebViewController controller,
) async {
  await controller.evaluateJavascript(
    source: '''
        (function () {
          var style = document.getElementById('__infocutter_preview_style');
          if (style && style.parentNode) style.parentNode.removeChild(style);
        })()
      ''',
  );
}

/// Reveal + highlight [rule] for three seconds, then restore the page.
///
/// [isCurrentPreview] guards the teardown so a superseded preview does not
/// undo the styling of the one that replaced it; [restoreHighlights] repaints
/// the staged session instead of clearing every highlight.
Future<void> runInfocutterStoredRulePreview(
  InAppWebViewController controller,
  StoredRule rule, {
  required bool Function() isCurrentPreview,
  required Future<void> Function() restoreHighlights,
}) async {
  try {
    await setInfocutterRuntimePeek(controller, enabled: true);
    await setInfocutterPreviewStyle(controller, selector: rule.selector);
    await scrollFirstInfocutterMatchIntoView(controller, rule.selector);
    await applyInfocutterSessionHighlights(
      controller,
      [
        SelectionCard(
          id: 'stored-rule-preview',
          name: rule.cardName,
          selector: rule.selector,
          frameScope: rule.frameScope,
          matchCount: -1,
        ),
      ],
    );
    await Future<void>.delayed(const Duration(seconds: 3));
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[infocutter] stored rule preview failed: $error');
    }
  } finally {
    if (isCurrentPreview()) {
      await clearInfocutterPreviewStyle(controller);
      await setInfocutterRuntimePeek(controller, enabled: false);
      // Restore the staged session's on-page numbered highlights instead of
      // clearing all highlights — the preview now shares the 「고르기」 tab with
      // live staged cards, so a blanket clear would wipe their badges.
      await restoreHighlights();
    }
  }
}
