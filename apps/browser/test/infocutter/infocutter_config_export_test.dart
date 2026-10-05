import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('NetworkFilterService export -> fresh import round-trips', () async {
    final source = NetworkFilterService();
    await source.load();
    await source.importRawList('||ads.example.com^');
    await source.setGlobalEnabled(false);
    expect(source.rules, isNotEmpty);

    final json = source.exportJson();
    final restored = NetworkFilterService();
    await restored.load();
    await restored.importJson(json);

    expect(restored.rules.length, source.rules.length);
    expect(restored.globalEnabled, isFalse);
  });

  test('WatchService export -> fresh import round-trips', () async {
    final source = WatchService();
    await source.load();
    await source.addTarget(name: '홍길동', aliases: const ['길동']);
    expect(source.targets, isNotEmpty);

    final json = source.exportJson();
    final restored = WatchService();
    await restored.load();
    await restored.importJson(json);

    expect(
        restored.targets.map((t) => t.name), source.targets.map((t) => t.name));
  });
}
