import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/browser_model.dart';
import '../../../models/window_model.dart';

/// cross_platform_settings.dart 의 섹션 빌더들이 공유하는 호출 문맥.
///
/// 원래 `_CrossPlatformSettingsState` 안에 있던 `_BaseSettingsContext` 와
/// `setState` / `context` / 홈페이지 컨트롤러 접근을 한데 묶은 것이다.
/// 동작은 그대로다.
class CrossPlatformSettingsContext {
  const CrossPlatformSettingsContext({
    required this.context,
    required this.browserModel,
    required this.settings,
    required this.windowModel,
    required this.l10n,
    required this.setStateWith,
    required this.customHomePageController,
  });

  final BuildContext context;
  final BrowserModel browserModel;
  final BrowserSettings settings;
  final WindowModel windowModel;
  final AppLocalizations l10n;

  /// State.setState 를 그대로 넘겨받는다.
  final void Function(VoidCallback fn) setStateWith;

  final TextEditingController customHomePageController;

  /// 원본의 `browserModel.updateSettings(settings)`.
  void updateSettings() => browserModel.updateSettings(settings);
}

/// `_buildDefaultUserAgentTile` / `_buildWebViewPackageInfo` 가 쓰던
/// 위젯 파라미터 로더들. 테스트에서 주입할 수 있게 원본 그대로 옮겼다.
class CrossPlatformSettingsLoaders {
  const CrossPlatformSettingsLoaders({
    this.defaultUserAgentLoader,
    this.currentWebViewPackageLoader,
  });

  final Future<String> Function()? defaultUserAgentLoader;
  final Future<WebViewPackageInfo?> Function()? currentWebViewPackageLoader;
}
