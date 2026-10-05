import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../models/webview_model.dart';
import '../../../models/window_model.dart';

/// android_settings.dart 의 섹션 빌더들이 공유하는 호출 문맥.
///
/// 원래 각 항목이 인라인으로 반복하던 대입·적용·저장·리빌드 절차를 [apply] 로,
/// `settings?.x ?? fallback` 형태의 값 읽기를 [read] / [readOrNull] 로 추출한
/// 것이다. 동작은 그대로다.
class AndroidSettingsContext {
  AndroidSettingsContext({
    required this.context,
    required this.windowModel,
    required this.webViewModel,
    required this.webViewController,
    required this.setStateWith,
  });

  final BuildContext context;
  final WindowModel windowModel;
  final WebViewModel webViewModel;
  final InAppWebViewController? webViewController;

  /// State.setState 를 그대로 넘겨받는다.
  final void Function(VoidCallback fn) setStateWith;

  /// 원본의 `setState(() {})`.
  void refresh() => setStateWith(() {});

  /// 원본의 `windowModel.saveInfo()`.
  void saveInfo() => windowModel.saveInfo();

  /// `settings?.<x>` 와 같다. settings 가 없으면 null.
  T? readOrNull<T>(T? Function(InAppWebViewSettings settings) get) {
    final settings = webViewModel.settings;
    if (settings == null) {
      return null;
    }
    return get(settings);
  }

  /// `settings?.<x> ?? fallback` 과 같다.
  T read<T>(T? Function(InAppWebViewSettings settings) get, T fallback) {
    return readOrNull<T>(get) ?? fallback;
  }

  /// `settings?.<x> = v` 뒤에 이어지던 적용·저장·리빌드 절차.
  ///
  /// settings 가 null 이면 원본의 `?.` 와 마찬가지로 대입 자체가 일어나지 않는다.
  Future<void> apply(
      void Function(InAppWebViewSettings settings) mutate) async {
    final settings = webViewModel.settings;
    if (settings != null) {
      mutate(settings);
    }
    webViewController?.setSettings(
        settings: webViewModel.settings ?? InAppWebViewSettings());
    webViewModel.settings = await webViewController?.getSettings();
    windowModel.saveInfo();
    refresh();
  }
}
