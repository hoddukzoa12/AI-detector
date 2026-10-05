import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/storage.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';

class _MemoryTextBlockStore implements TextBlockStore {
  String? raw;

  @override
  Future<String?> loadTextBlockStoreJson() async => raw;

  @override
  Future<void> saveTextBlockStoreJson(String raw) async {
    this.raw = raw;
  }
}

void main() {
  test('addRuleForUrl creates a matching profile and runtime state', () async {
    final store = _MemoryTextBlockStore();
    final service = TextBlockService(store: store);

    await service.setGlobalEnabled(true);
    final rule = await service.addRuleForUrl(
      TextBlockRuleRequest(
        url: Uri.parse('https://example.com/news/1'),
        keyword: 'Sponsored',
        objectName: 'Ads',
        minMatchCount: 3,
      ),
    );

    final state = service.buildActiveStateForUrl(
      Uri.parse('https://example.com/next'),
    );
    expect(state.activeProfileName, 'example.com');
    expect(state.ruleCount, 1);
    expect(store.raw, isNotNull);

    final runtime = service.buildRuntimeStateForUrl(
      Uri.parse('https://example.com/next'),
    );
    expect(runtime['globalEnabled'], isTrue);
    expect(runtime['profileEnabled'], isTrue);
    expect(runtime['rules'], [
      {
        'id': rule.id,
        'keyword': 'Sponsored',
        'minMatchCount': 3,
        'fingerprint': null,
        'objectName': 'Ads',
        'objectTags': ['ad'],
      }
    ]);
  });

  test('setRuleEnabled removes disabled rules from runtime state', () async {
    final service = TextBlockService(store: _MemoryTextBlockStore());

    await service.setGlobalEnabled(true);
    final rule = await service.addRuleForUrl(
      TextBlockRuleRequest(
        url: Uri.parse('https://example.com'),
        keyword: 'Sponsored',
      ),
    );
    final profileId = service.profiles.single.id;
    await service.setRuleEnabled(profileId, rule.id, false);

    final runtime = service.buildRuntimeStateForUrl(
      Uri.parse('https://example.com'),
    );

    expect(runtime['rules'], isEmpty);
  });
}
