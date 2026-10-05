part of '../app_automation_controller.dart';

/// `watch.*` command implementations, split out of
/// [_AppAutomationInfocutterCommands] to keep that file small.
extension _AppAutomationWatchCommands on _AppAutomationInfocutterCommands {
  Future<AppAutomationResult> setWatchGlobalEnabled(bool enabled) async {
    await _watch.setGlobalEnabled(enabled);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('watch.global', {'enabled': enabled});
  }

  Future<AppAutomationResult> setWatchAutoMask(bool enabled) async {
    await _watch.setAutoMask(enabled);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('watch.autoMask', {'enabled': enabled});
  }

  Future<AppAutomationResult> addWatchTarget({
    required String name,
    List<String> aliases = const [],
  }) async {
    final target = await _watch.addTarget(name: name, aliases: aliases);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('watch.addTarget', {
      'id': target.id,
      'name': target.name,
      'aliases': target.aliases,
    });
  }

  Future<AppAutomationResult> listWatchTargets() async {
    final targets = _watch.targets
        .map((target) => {
              'id': target.id,
              'name': target.name,
              'aliases': target.aliases,
              'enabled': target.enabled,
            })
        .toList();
    return AppAutomationResult.success('watch.listTargets', {
      'targets': targets,
      'count': targets.length,
    });
  }

  Future<AppAutomationResult> listWatchDetections() async {
    final detections = _watch.recentDetections
        .map((detection) => {
              'targetId': detection.targetId,
              'term': detection.term,
              'url': detection.url,
              'pageTitle': detection.pageTitle,
              'matchedText': detection.matchedText,
              'tag': detection.tag,
              'detectedAt': detection.detectedAt.toIso8601String(),
            })
        .toList();
    return AppAutomationResult.success('watch.listDetections', {
      'detections': detections,
      'count': detections.length,
    });
  }

  Future<AppAutomationResult> setWatchTargetEnabled({
    required String id,
    required bool enabled,
  }) async {
    await _watch.setTargetEnabled(id, enabled);
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('watch.setTargetEnabled', {
      'id': id,
      'enabled': enabled,
    });
  }

  Future<AppAutomationResult> removeWatchTarget(String id) async {
    final before = _watch.targets.length;
    await _watch.removeTarget(id);
    final removed = _watch.targets.length < before;
    await refreshCurrentInfocutterRuntime();
    return AppAutomationResult.success('watch.removeTarget', {
      'id': id,
      'removed': removed,
    });
  }
}
