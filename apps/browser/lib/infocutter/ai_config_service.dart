import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String infocutterAiConfigKey = 'infocutter.aiConfig';
const String infocutterAiApiKeySecretKey = 'infocutter.aiConfig.apiKey';
const String defaultAiDetectionEndpoint =
    'https://api.openai.com/v1/chat/completions';

/// The user-editable task instruction sent to the AI (the global prompt). The
/// strict-JSON output contract is enforced separately by the masking service,
/// so editing this only changes WHAT the AI is asked to hide.
const String defaultAiMaskingPrompt =
    'Suggest only selectors that likely hide ads, sponsored blocks, '
    'promotional modules, overlays, or repeated clutter. Do not suggest '
    'selectors for main article/content blocks.';

@immutable
class AiConfigSnapshot {
  const AiConfigSnapshot({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.analyzedHosts,
    this.prompt = defaultAiMaskingPrompt,
  });

  final String endpoint;
  final String apiKey;
  final String model;
  final List<String> analyzedHosts;

  /// The global task prompt sent to the AI (what to hide). User-editable.
  final String prompt;

  bool get isConfigured =>
      endpoint.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  AiConfigSnapshot copyWith({
    String? endpoint,
    String? apiKey,
    String? model,
    List<String>? analyzedHosts,
    String? prompt,
  }) =>
      AiConfigSnapshot(
        endpoint: endpoint ?? this.endpoint,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        analyzedHosts: analyzedHosts ?? this.analyzedHosts,
        prompt: prompt ?? this.prompt,
      );

  static const empty = AiConfigSnapshot(
    endpoint: defaultAiDetectionEndpoint,
    apiKey: '',
    model: '',
    analyzedHosts: [],
  );
}

abstract interface class AiConfigStore {
  Future<String?> loadAiConfigJson();

  Future<void> saveAiConfigJson(String raw);
}

class SharedPreferencesAiConfigStore implements AiConfigStore {
  const SharedPreferencesAiConfigStore({
    this.storageKey = infocutterAiConfigKey,
  });

  final String storageKey;

  @override
  Future<String?> loadAiConfigJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> saveAiConfigJson(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}

abstract interface class AiSecretStore {
  Future<String?> readApiKey();

  Future<void> writeApiKey(String value);

  Future<void> deleteApiKey();
}

class SecureStorageAiSecretStore implements AiSecretStore {
  const SecureStorageAiSecretStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readApiKey() {
    return _storage.read(key: infocutterAiApiKeySecretKey);
  }

  @override
  Future<void> writeApiKey(String value) {
    return _storage.write(key: infocutterAiApiKeySecretKey, value: value);
  }

  @override
  Future<void> deleteApiKey() {
    return _storage.delete(key: infocutterAiApiKeySecretKey);
  }
}

class AiConfigService extends ChangeNotifier {
  AiConfigService({
    AiSecretStore? secretStore,
    AiConfigStore? store,
  })  : _secretStore = secretStore ?? const SecureStorageAiSecretStore(),
        _store = store ?? const SharedPreferencesAiConfigStore();

  final AiSecretStore _secretStore;
  final AiConfigStore _store;

  AiConfigSnapshot _snapshot = AiConfigSnapshot.empty;
  bool _loaded = false;

  AiConfigSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;
  bool get isConfigured => _snapshot.isConfigured;

  Future<void> load() async {
    final raw = await _store.loadAiConfigJson();
    if (raw != null && raw.isNotEmpty) {
      _snapshot = _decodeJson(raw);
    }
    final storedApiKey = await _secretStore.readApiKey();
    final legacyApiKey = _snapshot.apiKey;
    if (storedApiKey != null && storedApiKey.isNotEmpty) {
      _snapshot = _snapshot.copyWith(apiKey: storedApiKey);
    } else if (legacyApiKey.isNotEmpty) {
      await _secretStore.writeApiKey(legacyApiKey);
    }
    if (legacyApiKey.isNotEmpty) {
      await _store.saveAiConfigJson(_encodeJson(_snapshot));
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveConfig({
    required String endpoint,
    required String apiKey,
    required String model,
    String? prompt,
  }) async {
    final normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      await _secretStore.deleteApiKey();
    } else {
      await _secretStore.writeApiKey(normalizedApiKey);
    }
    return _commit(
      _snapshot.copyWith(
        endpoint: _nonEmpty(endpoint) ?? defaultAiDetectionEndpoint,
        apiKey: normalizedApiKey,
        model: model.trim(),
        // null -> keep current; blank -> fall back to the default prompt.
        prompt: prompt == null
            ? null
            : (_nonEmpty(prompt) ?? defaultAiMaskingPrompt),
      ),
    );
  }

  Future<void> markHostAnalyzed(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty || _snapshot.analyzedHosts.contains(normalized)) {
      return Future.value();
    }
    return _commit(
      _snapshot.copyWith(
        analyzedHosts: [..._snapshot.analyzedHosts, normalized],
      ),
    );
  }

  Future<void> resetAnalyzedHosts() {
    return _commit(_snapshot.copyWith(analyzedHosts: const []));
  }

  Future<void> clearConfig() async {
    await _secretStore.deleteApiKey();
    return _commit(AiConfigSnapshot.empty);
  }

  Future<void> _commit(AiConfigSnapshot snapshot) async {
    _snapshot = snapshot;
    await _store.saveAiConfigJson(_encodeJson(snapshot));
    notifyListeners();
  }

  static AiConfigSnapshot _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AiConfigSnapshot.empty;
      return AiConfigSnapshot(
        endpoint: decoded['endpoint'] is String &&
                (decoded['endpoint'] as String).trim().isNotEmpty
            ? decoded['endpoint'] as String
            : defaultAiDetectionEndpoint,
        apiKey: decoded['apiKey'] is String ? decoded['apiKey'] as String : '',
        model: decoded['model'] is String ? decoded['model'] as String : '',
        analyzedHosts: decoded['analyzedHosts'] is List
            ? (decoded['analyzedHosts'] as List).whereType<String>().toList()
            : const [],
        prompt: decoded['prompt'] is String &&
                (decoded['prompt'] as String).trim().isNotEmpty
            ? decoded['prompt'] as String
            : defaultAiMaskingPrompt,
      );
    } on FormatException {
      return AiConfigSnapshot.empty;
    }
  }

  static String _encodeJson(AiConfigSnapshot snapshot) => jsonEncode({
        'endpoint': snapshot.endpoint,
        'apiKey': '',
        'model': snapshot.model,
        'analyzedHosts': snapshot.analyzedHosts,
        'prompt': snapshot.prompt,
      });

  static String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
