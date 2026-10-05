import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'infocutter_runtime_contracts.dart';

/// picker UserScript 의 고유 ID. 다중 주입 방지에 사용.
const String pickerUserScriptId = 'infocutter.picker';

/// DOM runtime UserScript 의 고유 ID. 다중 주입 방지에 사용.
const String runtimeUserScriptId = 'infocutter.runtime';

/// Watch runtime UserScript 의 고유 ID.
const String watchRuntimeUserScriptId = 'infocutter.watch';

/// Text block runtime UserScript 의 고유 ID.
const String textBlockRuntimeUserScriptId = 'infocutter.textBlocks';

/// Keyword-capture UserScript 의 고유 ID.
const String keywordCaptureUserScriptId = 'infocutter.keywordCapture';

/// Lazy image promote UserScript 의 고유 ID (#26 data-src).
const String lazyImagePromoteUserScriptId = 'infocutter.lazyImagePromote';

class InfocutterUserScriptContribution {
  const InfocutterUserScriptContribution({
    required this.groupName,
    required this.source,
    this.injectionTime = UserScriptInjectionTime.AT_DOCUMENT_END,
  });

  final String groupName;
  final String source;
  final UserScriptInjectionTime injectionTime;

  UserScript buildUserScript() {
    return UserScript(
      groupName: groupName,
      source: source,
      injectionTime: injectionTime,
      forMainFrameOnly: false,
    );
  }
}

const List<InfocutterUserScriptContribution> infocutterUserScriptContributions =
    [
  InfocutterUserScriptContribution(
    groupName: runtimeUserScriptId,
    source: infocutterBlockRuntimeUserScriptSource,
  ),
  InfocutterUserScriptContribution(
    groupName: pickerUserScriptId,
    source: infocutterPickerRuntimeUserScriptSource,
  ),
  InfocutterUserScriptContribution(
    groupName: watchRuntimeUserScriptId,
    source: infocutterWatchRuntimeUserScriptSource,
  ),
  InfocutterUserScriptContribution(
    groupName: textBlockRuntimeUserScriptId,
    source: infocutterTextBlockRuntimeUserScriptSource,
  ),
  InfocutterUserScriptContribution(
    groupName: keywordCaptureUserScriptId,
    source: infocutterKeywordCaptureRuntimeUserScriptSource,
  ),
  InfocutterUserScriptContribution(
    groupName: lazyImagePromoteUserScriptId,
    source: infocutterLazyImageRuntimeUserScriptSource,
    // 가능한 한 이른 시점에 붙여 Naver 등 지연 이미지를 선제 승격한다.
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  ),
];
