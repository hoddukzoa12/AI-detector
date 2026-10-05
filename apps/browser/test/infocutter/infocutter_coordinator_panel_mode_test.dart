import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/infocutter_panel_mode.dart';
import 'package:infocutter_app/infocutter/infocutter_webview_coordinator.dart';
import 'package:infocutter_app/models/webview_model.dart';

void main() {
  InfocutterWebViewCoordinator buildCoordinator(
    WebViewModel model, {
    Future<void> Function({required bool active})? togglePickerForTest,
  }) {
    return InfocutterWebViewCoordinator(
      context: () => throw UnimplementedError(),
      controller: () => null,
      isMounted: () => true,
      onEvidenceCaptured: (_) {},
      onRuleSaved: (_, __) {},
      onSidebarChanged: () {},
      togglePickerForTest: togglePickerForTest,
      webViewModel: model,
    );
  }

  test('openPanel opens the sidebar in the requested mode', () async {
    final model = WebViewModel(url: WebUri('https://example.com/page'));
    final coordinator = buildCoordinator(model);

    final opened = await coordinator.openPanel(InfocutterPanelMode.block);

    expect(opened, isTrue);
    expect(coordinator.sidebar, isNotNull);
    expect(coordinator.sidebar!.mode, InfocutterPanelMode.block);
  });

  test('openPanel supports every toolbar and overflow mode', () async {
    for (final mode in InfocutterPanelMode.values) {
      final model = WebViewModel(url: WebUri('https://example.com/page'));
      final coordinator = buildCoordinator(model);

      expect(await coordinator.openPanel(mode), isTrue);
      expect(coordinator.sidebar!.mode, mode);
      expect(model.infocutterOpenPanel, mode);
    }
  });

  test('openPanel stops any active picker before showing the sidebar',
      () async {
    final calls = <bool>[];
    final model = WebViewModel(url: WebUri('https://example.com/page'));
    final coordinator = buildCoordinator(
      model,
      togglePickerForTest: ({required active}) async => calls.add(active),
    );

    expect(await coordinator.openPanel(InfocutterPanelMode.keyword), isTrue);

    expect(calls, [false]);
    expect(coordinator.sidebar!.mode, InfocutterPanelMode.keyword);
  });

  test('openPanel still shows the sidebar when picker stop fails', () async {
    final model = WebViewModel(url: WebUri('https://example.com/page'));
    final coordinator = buildCoordinator(
      model,
      togglePickerForTest: ({required active}) async {
        throw StateError('picker bridge unavailable');
      },
    );

    expect(await coordinator.openPanel(InfocutterPanelMode.block), isTrue);

    expect(coordinator.sidebar!.mode, InfocutterPanelMode.block);
  });

  test('navigating to a different host closes the sidebar', () async {
    final model = WebViewModel(url: WebUri('https://example.com/page'));
    final coordinator = buildCoordinator(model);
    await coordinator.openPanel(InfocutterPanelMode.keyword);
    expect(coordinator.sidebar, isNotNull);

    // Same host (SPA route change) keeps the panel open.
    await coordinator.handleHostChange(Uri.parse('https://example.com/other'));
    expect(coordinator.sidebar, isNotNull);

    // A different host closes it.
    await coordinator.handleHostChange(Uri.parse('https://reddit.com/'));
    expect(coordinator.sidebar, isNull);
  });

  test('openPanel returns false when the current tab has no host', () async {
    final coordinator = buildCoordinator(WebViewModel());

    expect(await coordinator.openPanel(InfocutterPanelMode.ai), isFalse);
    expect(coordinator.sidebar, isNull);
  });

  test(
      'openPanel reflects the open mode onto the WebViewModel; '
      'closeSidebar clears it', () async {
    final model = WebViewModel(url: WebUri('https://example.com/page'));
    final coordinator = buildCoordinator(model);

    await coordinator.openPanel(InfocutterPanelMode.keyword);
    expect(model.infocutterOpenPanel, InfocutterPanelMode.keyword);

    await coordinator.closeSidebar();
    expect(model.infocutterOpenPanel, isNull);
  });
}
