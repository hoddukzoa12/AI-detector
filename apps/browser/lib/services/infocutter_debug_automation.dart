import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/browser_url_resolver.dart';
import 'package:provider/provider.dart';

typedef InfocutterAutomationHandler = Future<Map<String, Object?>> Function(
  Map<String, String> parameters,
);

class InfocutterDebugAutomationHost extends StatefulWidget {
  const InfocutterDebugAutomationHost({required this.child, super.key});

  final Widget child;

  @override
  State<InfocutterDebugAutomationHost> createState() =>
      _InfocutterDebugAutomationHostState();
}

class _InfocutterDebugAutomationHostState
    extends State<InfocutterDebugAutomationHost> {
  @override
  void initState() {
    super.initState();
    InfocutterDebugAutomationRegistry.instance.attach(_handleCommand);
  }

  @override
  void dispose() {
    InfocutterDebugAutomationRegistry.instance.detach(_handleCommand);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<Map<String, Object?>> _handleCommand(
    Map<String, String> parameters,
  ) async {
    switch (parameters['command']) {
      case 'getState':
        return _state();
      case 'openUrl':
        return _openUrl(parameters['url']);
      default:
        return {
          'ok': false,
          'error': 'Unsupported command: ${parameters['command']}',
        };
    }
  }

  Map<String, Object?> _state() {
    final windowModel = context.read<WindowModel>();
    final webViewModel = windowModel.getCurrentWebViewModel();

    return {
      'ok': true,
      'tabCount': windowModel.webViewModels.length,
      'currentTabIndex': windowModel.getCurrentTabIndex(),
      'url': webViewModel?.url?.toString(),
      'title': webViewModel?.title,
      'loaded': webViewModel?.loaded,
    };
  }

  Future<Map<String, Object?>> _openUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return {'ok': false, 'error': 'url is required'};
    }

    final browserModel = context.read<BrowserModel>();
    final windowModel = context.read<WindowModel>();
    final currentWebViewModel = context.read<WebViewModel>();
    final url = const BrowserUrlResolver().resolve(
      rawUrl,
      browserModel.getSettings(),
    );
    final webViewModel = windowModel.getCurrentWebViewModel();

    if (webViewModel?.webViewController != null) {
      await webViewModel!.webViewController!.loadUrl(
        urlRequest: URLRequest(url: url),
      );
      webViewModel.url = url;
      currentWebViewModel.updateWithValue(webViewModel);
      windowModel.notifyCurrentTabUpdated();
      return {'ok': true, 'route': 'currentTab', 'url': url.toString()};
    }

    windowModel.addTab(WebViewModel(url: url));
    return {'ok': true, 'route': 'newTab', 'url': url.toString()};
  }
}

class InfocutterDebugAutomationRegistry {
  InfocutterDebugAutomationRegistry._();

  static final instance = InfocutterDebugAutomationRegistry._();

  InfocutterAutomationHandler? _handler;
  var _registered = false;

  void attach(InfocutterAutomationHandler handler) {
    _handler = handler;
    if (!kDebugMode || _registered) {
      return;
    }
    developer.registerExtension(
      'ext.infocutter_app.control',
      _handleExtensionRequest,
    );
    _registered = true;
  }

  void detach(InfocutterAutomationHandler handler) {
    if (_handler == handler) {
      _handler = null;
    }
  }

  Future<developer.ServiceExtensionResponse> _handleExtensionRequest(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final handler = _handler;
      if (handler == null) {
        return _jsonResponse({
          'ok': false,
          'error': 'No active Infocutter automation host',
        });
      }
      return _jsonResponse(await handler(parameters));
    } catch (error, stackTrace) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        jsonEncode({
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        }),
      );
    }
  }

  developer.ServiceExtensionResponse _jsonResponse(
    Map<String, Object?> payload,
  ) {
    return developer.ServiceExtensionResponse.result(jsonEncode(payload));
  }
}
