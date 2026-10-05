import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/ai_rule_service.dart';

class _MemoryAiRuleStore implements AiRuleStore {
  String? raw;

  @override
  Future<String?> loadAiRuleStoreJson() async => raw;

  @override
  Future<void> saveAiRuleStoreJson(String raw) async {
    this.raw = raw;
  }
}

void main() {
  test('addSuggestions stores generated rules by host and dedupes selectors',
      () async {
    final store = _MemoryAiRuleStore();
    final service = AiRuleService(store: store);
    final url = Uri.parse('https://example.com/news');

    await service.addSuggestions(
      url: url,
      suggestions: const [
        AiMaskingSuggestion(
          selector: '.ad',
          label: 'Ad',
          reason: 'ad block',
          confidence: 0.8,
        ),
      ],
    );
    await service.addSuggestions(
      url: url,
      suggestions: const [
        AiMaskingSuggestion(
          selector: '.ad',
          label: 'Updated ad',
          reason: 'updated',
          confidence: 0.9,
        ),
      ],
    );

    expect(service.rulesForHost('example.com'), hasLength(1));
    expect(service.rules.single.label, 'Updated ad');
    expect(service.rules.single.confidence, 0.9);
    expect(store.raw, isNotNull);
  });

  test('markAppliedForSelector records applied state', () async {
    final service = AiRuleService(store: _MemoryAiRuleStore());
    await service.addSuggestions(
      url: Uri.parse('https://example.com'),
      suggestions: const [AiMaskingSuggestion(selector: '.ad')],
    );

    await service.markAppliedForSelector(
      host: 'example.com',
      selector: '.ad',
    );

    expect(service.rules.single.applied, isTrue);
  });
}
