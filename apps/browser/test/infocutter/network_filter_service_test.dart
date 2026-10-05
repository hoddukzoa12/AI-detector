import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/network_filter_models.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/storage.dart';

class _MemoryNetworkFilterStore implements NetworkFilterStore {
  String? raw;

  @override
  Future<String?> loadNetworkFilterStoreJson() async => raw;

  @override
  Future<void> saveNetworkFilterStoreJson(String raw) async {
    this.raw = raw;
  }
}

void main() {
  test('imports supported rules and blocks domain anchored URLs', () async {
    final store = _MemoryNetworkFilterStore();
    final service = NetworkFilterService(store: store);

    final summary = await service.importRawList(r'''
||ads.example.com^$script
example.com##.ad
''');

    expect(summary.imported, 1);
    expect(summary.skipped, 1);
    expect(store.raw, isNotNull);
    expect(
      service.shouldBlock(Uri.parse('https://ads.example.com/banner.js')),
      isTrue,
    );
    expect(
      service.shouldBlock(Uri.parse('https://sub.ads.example.com/a.js')),
      isTrue,
    );
    expect(
      service.shouldBlock(Uri.parse('https://example.com/news')),
      isFalse,
    );
  });

  test('allow rules override block rules', () async {
    final service = NetworkFilterService(store: _MemoryNetworkFilterStore());

    await service.importRawList(r'''
||example.com^
@@||cdn.example.com^
''');

    expect(
      service.shouldBlock(Uri.parse('https://www.example.com/ad.js')),
      isTrue,
    );
    expect(
      service.shouldBlock(Uri.parse('https://cdn.example.com/app.js')),
      isFalse,
    );
  });

  test('disabled rules and global disabled state do not block', () async {
    final service = NetworkFilterService(store: _MemoryNetworkFilterStore());
    await service.importRawList(r'||ads.example.com^');

    final ruleId = service.rules.single.id;
    await service.setRuleEnabled(ruleId, false);
    expect(
      service.shouldBlock(Uri.parse('https://ads.example.com/banner.js')),
      isFalse,
    );

    await service.setRuleEnabled(ruleId, true);
    await service.setGlobalEnabled(false);
    expect(
      service.shouldBlock(Uri.parse('https://ads.example.com/banner.js')),
      isFalse,
    );
  });

  test('matches prefix, wildcard, and substring patterns', () {
    NetworkFilterRule rule(String pattern) => NetworkFilterRule(
          allow: false,
          kind: NetworkFilterKind.network,
          modifiers: const [],
          pattern: pattern,
          raw: pattern,
          skipReason: null,
        );

    expect(
      matchesNetworkFilterRule(
        rule('|https://example.com/ad'),
        Uri.parse('https://example.com/ad/1'),
      ),
      isTrue,
    );
    expect(
      matchesNetworkFilterRule(
        rule('https://*/sponsor.js'),
        Uri.parse('https://cdn.example.com/sponsor.js'),
      ),
      isTrue,
    );
    expect(
      matchesNetworkFilterRule(
        rule('tracking_pixel'),
        Uri.parse('https://example.com/tracking_pixel.gif'),
      ),
      isTrue,
    );
  });
}
