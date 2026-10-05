import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/ai_config_service.dart';
import 'package:infocutter_app/infocutter/ai_masking_candidate_collector.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';

class _FakeAiMaskingClient implements AiMaskingClient {
  List<AiPageCandidate> seenCandidates = const [];

  @override
  Future<List<AiMaskingSuggestion>> analyze({
    required List<AiPageCandidate> candidates,
    required AiConfigSnapshot config,
    required Uri url,
  }) async {
    seenCandidates = candidates;
    return [
      const AiMaskingSuggestion(
        selector: '.ad',
        label: 'Ad',
        reason: 'promotional block',
        confidence: 0.82,
      ),
    ];
  }
}

void main() {
  test('parseAiMaskingSuggestions reads direct suggestion payloads', () {
    final suggestions = parseAiMaskingSuggestions(jsonEncode({
      'suggestions': [
        {
          'selector': '.sponsored',
          'label': 'Sponsored',
          'reason': 'sponsored module',
          'confidence': 0.91,
        }
      ],
    }));

    expect(suggestions, hasLength(1));
    expect(suggestions.single.selector, '.sponsored');
    expect(suggestions.single.confidence, 0.91);
  });

  test('parseAiMaskingSuggestions reads OpenAI chat content JSON', () {
    final suggestions = parseAiMaskingSuggestions(jsonEncode({
      'choices': [
        {
          'message': {
            'content': '''
```json
{"suggestions":[{"selector":"#ad","label":"Ad","reason":"ad slot","confidence":0.7}]}
```
''',
          },
        }
      ],
    }));

    expect(suggestions.single.selector, '#ad');
    expect(suggestions.single.label, 'Ad');
  });

  test('AiMaskingService requires config and limits candidates', () async {
    final client = _FakeAiMaskingClient();
    final service = AiMaskingService(client: client);
    final candidates = List.generate(
      100,
      (index) => AiPageCandidate(selector: '.item-$index'),
    );

    await expectLater(
      service.analyze(
        candidates: candidates,
        config: AiConfigSnapshot.empty,
        url: Uri.parse('https://example.com'),
      ),
      throwsStateError,
    );

    final suggestions = await service.analyze(
      candidates: candidates,
      config: const AiConfigSnapshot(
        endpoint: 'https://example.com/ai',
        apiKey: 'key',
        model: 'model',
        analyzedHosts: [],
      ),
      url: Uri.parse('https://example.com'),
    );

    expect(suggestions.single.selector, '.ad');
    expect(client.seenCandidates, hasLength(80));
  });

  test('buildAiMaskingPayload embeds the global prompt + JSON contract', () {
    final payload = buildAiMaskingPayload(
      candidates: const [],
      config: const AiConfigSnapshot(
        endpoint: 'https://example.com/ai',
        apiKey: 'sk-test',
        model: 'gpt-test',
        analyzedHosts: [],
        prompt: 'Hide only cookie consent banners.',
      ),
      url: Uri.parse('https://example.com'),
    );
    final messages = payload['messages'] as List;
    final system = (messages.first as Map)['content'] as String;
    // The user prompt drives the task...
    expect(system, contains('Hide only cookie consent banners.'));
    // ...while the strict-JSON output contract stays pinned.
    expect(system, contains('Return strict JSON only'));
  });

  test('AiPageCandidate.tryParse drops malformed candidates', () {
    expect(AiPageCandidate.tryParse({'selector': ''}), isNull);
    expect(AiPageCandidate.tryParse({'selector': '.ad'})?.selector, '.ad');
  });

  test('parseAiPageCandidates reads WebView JSON results safely', () {
    final candidates = parseAiPageCandidates(jsonEncode([
      {
        'selector': '.ad',
        'tag': 'aside',
        'textLength': 12,
        'width': 320,
      },
      {'selector': ''},
    ]));

    expect(candidates, hasLength(1));
    expect(candidates.single.selector, '.ad');
    expect(candidates.single.tag, 'aside');
    expect(candidates.single.textLength, 12);
    expect(parseAiPageCandidates('not json'), isEmpty);
  });
}
