import 'selector_engine.dart';
import 'text_block_runtime.dart';
import 'watch_runtime.dart';

const String infocutterBlockRuntimeObjectName = '__infocutterRuntime';
const String infocutterPickerRuntimeObjectName = '__infocutterPicker';
const String infocutterWatchRuntimeObjectName = '__infocutterWatch';
const String infocutterTextBlockRuntimeObjectName = '__infocutterTextBlocks';
const String infocutterKeywordCaptureRuntimeObjectName =
    '__infocutterKeywordCapture';
const String infocutterLazyImageRuntimeObjectName =
    '__infocutterLazyImagePromote';

const String infocutterBlockRuntimeUserScriptSource =
    infocutterRuntimeUserScriptSource;
const String infocutterPickerRuntimeUserScriptSource = pickerUserScriptSource;
const String infocutterWatchRuntimeUserScriptSource =
    infocutterWatchUserScriptSource;
const String infocutterTextBlockRuntimeUserScriptSource =
    infocutterTextBlockUserScriptSource;
const String infocutterKeywordCaptureRuntimeUserScriptSource =
    keywordCaptureUserScriptSource;
const String infocutterLazyImageRuntimeUserScriptSource =
    lazyImagePromoteUserScriptSource;

class InfocutterRuntimeContract {
  const InfocutterRuntimeContract({
    required this.objectName,
    required this.userScriptSource,
  });

  final String objectName;
  final String userScriptSource;
}

const InfocutterRuntimeContract infocutterBlockRuntimeContract =
    InfocutterRuntimeContract(
  objectName: infocutterBlockRuntimeObjectName,
  userScriptSource: infocutterBlockRuntimeUserScriptSource,
);

const InfocutterRuntimeContract infocutterPickerRuntimeContract =
    InfocutterRuntimeContract(
  objectName: infocutterPickerRuntimeObjectName,
  userScriptSource: infocutterPickerRuntimeUserScriptSource,
);

const InfocutterRuntimeContract infocutterWatchRuntimeContract =
    InfocutterRuntimeContract(
  objectName: infocutterWatchRuntimeObjectName,
  userScriptSource: infocutterWatchRuntimeUserScriptSource,
);

const InfocutterRuntimeContract infocutterTextBlockRuntimeContract =
    InfocutterRuntimeContract(
  objectName: infocutterTextBlockRuntimeObjectName,
  userScriptSource: infocutterTextBlockRuntimeUserScriptSource,
);

const InfocutterRuntimeContract infocutterKeywordCaptureRuntimeContract =
    InfocutterRuntimeContract(
  objectName: infocutterKeywordCaptureRuntimeObjectName,
  userScriptSource: infocutterKeywordCaptureRuntimeUserScriptSource,
);

const InfocutterRuntimeContract infocutterLazyImageRuntimeContract =
    InfocutterRuntimeContract(
  objectName: infocutterLazyImageRuntimeObjectName,
  userScriptSource: infocutterLazyImageRuntimeUserScriptSource,
);
