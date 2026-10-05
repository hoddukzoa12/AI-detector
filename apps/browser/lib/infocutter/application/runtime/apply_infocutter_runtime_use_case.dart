import 'dart:convert';

import 'infocutter_runtime_page.dart';

enum ApplyInfocutterRuntimeResult {
  applied,
  injectedAndApplied,
}

class ApplyInfocutterRuntimeCommand {
  const ApplyInfocutterRuntimeCommand({
    required this.page,
    required this.state,
  });

  final InfocutterRuntimePage page;
  final Map<String, Object?> state;
}

class ApplyInfocutterRuntimeUseCase {
  const ApplyInfocutterRuntimeUseCase({
    required String runtimeObjectName,
    required String runtimeUserScriptSource,
  })  : _runtimeObjectName = runtimeObjectName,
        _runtimeUserScriptSource = runtimeUserScriptSource;

  final String _runtimeObjectName;
  final String _runtimeUserScriptSource;

  Future<ApplyInfocutterRuntimeResult> call(
    ApplyInfocutterRuntimeCommand command,
  ) async {
    var result = await command.page.evaluateJavascript(
      _applyRuntimeSource(command.state),
    );
    if (result != 'missing') {
      return ApplyInfocutterRuntimeResult.applied;
    }

    await command.page.evaluateJavascript(_runtimeUserScriptSource);
    result = await command.page.evaluateJavascript(
      _applyRuntimeSource(command.state),
    );
    return ApplyInfocutterRuntimeResult.injectedAndApplied;
  }

  String _applyRuntimeSource(Map<String, Object?> state) => '''
        (function () {
          var runtime = window.$_runtimeObjectName;
          if (!runtime || typeof runtime.apply !== 'function') {
            return 'missing';
          }
          runtime.apply(${jsonEncode(state)});
          return 'ok';
        })()
      ''';
}
