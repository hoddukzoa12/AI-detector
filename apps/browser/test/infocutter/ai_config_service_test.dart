import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/ai_config_service.dart';

class _MemoryAiConfigStore implements AiConfigStore {
  String? raw;

  @override
  Future<String?> loadAiConfigJson() async => raw;

  @override
  Future<void> saveAiConfigJson(String raw) async {
    this.raw = raw;
  }
}

class _MemoryAiSecretStore implements AiSecretStore {
  String? apiKey;

  @override
  Future<void> deleteApiKey() async {
    apiKey = null;
  }

  @override
  Future<String?> readApiKey() async => apiKey;

  @override
  Future<void> writeApiKey(String value) async {
    apiKey = value;
  }
}

void main() {
  test('saveConfig persists endpoint/model and stores key separately',
      () async {
    final store = _MemoryAiConfigStore();
    final secretStore = _MemoryAiSecretStore();
    final service = AiConfigService(store: store, secretStore: secretStore);

    await service.saveConfig(
      endpoint: ' https://example.com/ai ',
      apiKey: ' sk-test ',
      model: ' gpt-test ',
    );

    expect(service.snapshot.endpoint, 'https://example.com/ai');
    expect(service.snapshot.apiKey, 'sk-test');
    expect(service.snapshot.model, 'gpt-test');
    expect(service.isConfigured, isTrue);
    expect(store.raw, isNotNull);
    expect(store.raw, isNot(contains('sk-test')));
    expect(secretStore.apiKey, 'sk-test');
  });

  test('markHostAnalyzed dedupes hosts and reset clears them', () async {
    final service = AiConfigService(
      store: _MemoryAiConfigStore(),
      secretStore: _MemoryAiSecretStore(),
    );

    await service.markHostAnalyzed(' Example.com ');
    await service.markHostAnalyzed('example.com');

    expect(service.snapshot.analyzedHosts, ['example.com']);

    await service.resetAnalyzedHosts();

    expect(service.snapshot.analyzedHosts, isEmpty);
  });

  test('saveConfig persists the global prompt and reload restores it',
      () async {
    final store = _MemoryAiConfigStore();
    final secretStore = _MemoryAiSecretStore();
    final service = AiConfigService(store: store, secretStore: secretStore);

    expect(service.snapshot.prompt, defaultAiMaskingPrompt);

    await service.saveConfig(
      endpoint: 'https://example.com/ai',
      apiKey: 'sk-test',
      model: 'm',
      prompt: 'Hide only paywalls.',
    );
    expect(service.snapshot.prompt, 'Hide only paywalls.');
    expect(store.raw, contains('Hide only paywalls.'));
    expect(store.raw, isNot(contains('sk-test')));

    final reloaded = AiConfigService(store: store, secretStore: secretStore);
    await reloaded.load();
    expect(reloaded.snapshot.prompt, 'Hide only paywalls.');

    // A blank prompt falls back to the default.
    await service.saveConfig(
      endpoint: 'https://example.com/ai',
      apiKey: 'sk-test',
      model: 'm',
      prompt: '   ',
    );
    expect(service.snapshot.prompt, defaultAiMaskingPrompt);
  });

  test('load migrates legacy api key into secret storage', () async {
    final store = _MemoryAiConfigStore()
      ..raw =
          '{"endpoint":"https://example.com/ai","apiKey":"legacy","model":"m","analyzedHosts":[]}';
    final secretStore = _MemoryAiSecretStore();
    final service = AiConfigService(store: store, secretStore: secretStore);

    await service.load();

    expect(service.snapshot.apiKey, 'legacy');
    expect(secretStore.apiKey, 'legacy');
    expect(store.raw, isNot(contains('legacy')));
  });
}
