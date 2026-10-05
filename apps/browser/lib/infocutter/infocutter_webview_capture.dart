import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/infocutter/ai_masking_candidate_collector.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';

/// The owning widget's hooks into an evidence capture.
///
/// [evidence] and [pageTitle] are callbacks rather than values so they are
/// resolved from the widget tree only after the page reads complete and the
/// caller has re-confirmed it is still mounted.
@immutable
class InfocutterEvidenceCaptureHost {
  const InfocutterEvidenceCaptureHost({
    required this.pageTitle,
    required this.isMounted,
    required this.evidence,
    required this.onCaptured,
  });

  final String Function() pageTitle;
  final bool Function() isMounted;
  final EvidenceService Function() evidence;
  final void Function(int sequence) onCaptured;
}

/// Snapshot the live page (HTML + screenshot) into the evidence store.
Future<void> captureInfocutterEvidence(
  InAppWebViewController controller,
  Uri url,
  InfocutterEvidenceCaptureHost host, {
  WatchDetection? detection,
}) async {
  final isMounted = host.isMounted;
  final html = await controller.getHtml() ?? '';
  final Uint8List? pngBytes = await controller.takeScreenshot();
  if (!isMounted()) return;
  final record = await host.evidence().captureHtmlSnapshot(
        EvidenceCaptureRequest(
          url: url,
          pageTitle: detection?.pageTitle ?? host.pageTitle(),
          html: html,
          pngBytes: pngBytes,
          targetId: detection?.targetId ?? '',
          matchedTerm: detection?.term ?? '',
          matchedText: detection?.matchedText ?? '',
        ),
      );
  if (!isMounted()) return;
  host.onCaptured(record.sequence);
}

Future<List<AiPageCandidate>> collectInfocutterAiMaskingCandidates(
  InAppWebViewController controller,
) async {
  final raw = await controller.evaluateJavascript(
    source: aiMaskingCandidateCollectorScript,
  );
  return parseAiPageCandidates(raw);
}
