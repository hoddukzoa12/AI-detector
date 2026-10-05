import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/infocutter/auth_origin_policy.dart';
import 'package:infocutter_app/infocutter/infocutter_runtime_contributors.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/site_protection_bypass.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/infocutter/webview_integration.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:provider/provider.dart';

class InfocutterRuntimeApplier {
  const InfocutterRuntimeApplier({
    required BuildContext Function() context,
    required WebViewModel webViewModel,
  })  : _context = context,
        _webViewModel = webViewModel;

  final BuildContext Function() _context;
  final WebViewModel _webViewModel;

  Future<void> applySettingsForUrl(
    InAppWebViewController controller,
    InfocutterService infocutter,
    Uri? url,
  ) async {
    final networkFilters = Provider.of<NetworkFilterService>(
      _context(),
      listen: false,
    );
    final settings = await controller.getSettings() ?? _webViewModel.settings;
    if (settings != null) {
      applyInfocutterSettings(
        settings,
        infocutter,
        url,
        networkFilters: networkFilters,
      );
      await controller.setSettings(settings: settings);
      _webViewModel.settings = settings;
    }
  }

  Future<void> applyRuntimeForUrl(
    InAppWebViewController controller,
    InfocutterService infocutter,
    Uri? url,
  ) async {
    if (isAuthOrigin(url)) return;
    if (SiteProtectionBypass.instance.isBypassed(url)) return;
    await applyInfocutterRuntimeForUrl(controller, infocutter, url);
  }

  Future<void> applyTextBlockRuntimeForUrl(
    InAppWebViewController controller,
    TextBlockService textBlocks,
    Uri? url,
  ) async {
    if (isAuthOrigin(url)) return;
    if (SiteProtectionBypass.instance.isBypassed(url)) return;
    await applyInfocutterTextBlockRuntimeForUrl(controller, textBlocks, url);
  }

  Future<void> applyWatchRuntime(
    InAppWebViewController controller,
    WatchService watch,
  ) async {
    // watch 런타임은 URL 인자를 받지 않으므로 현재 탭 URL 로 판정한다.
    if (isAuthOrigin(_webViewModel.url)) return;
    if (SiteProtectionBypass.instance.isBypassed(_webViewModel.url)) return;
    await applyInfocutterWatchRuntime(controller, watch);
  }

  Future<void> refreshForCurrentUrl(
    InAppWebViewController? controller, {
    bool reload = false,
  }) async {
    if (controller == null) return;
    final context = _context();
    final infocutter = Provider.of<InfocutterService>(context, listen: false);
    final url = _webViewModel.url;
    // 인증 origin 에서는 주입을 하지 않는다. settings 는 그대로 적용해
    // 이전 페이지에서 남은 ContentBlocker 를 비우고(어댑터가 빈 목록으로
    // 덮는다), contributor 루프(= 주입 choke point)만 건너뛴다.
    await applySettingsForUrl(controller, infocutter, url);
    if (isAuthOrigin(url) || SiteProtectionBypass.instance.isBypassed(url)) {
      if (reload) {
        await controller.reload();
      }
      return;
    }
    for (final contributor in infocutterRuntimeContributors) {
      final runtimeContext = _context();
      if (!runtimeContext.mounted) return;
      await contributor.apply(runtimeContext, controller, url);
    }
    if (reload) {
      await controller.reload();
    }
  }
}
