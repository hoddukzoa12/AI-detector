import 'package:shared_preferences/shared_preferences.dart';

const String infocutterRuleStoreKey = 'infocutter.ruleStore';
const String infocutterTextBlockStoreKey = 'infocutter.textBlockStore';
const String infocutterNetworkFilterStoreKey = 'infocutter.networkFilterStore';

abstract interface class InfocutterStore {
  Future<String?> loadRuleStoreJson();

  Future<void> saveRuleStoreJson(String raw);
}

class SharedPreferencesInfocutterStore implements InfocutterStore {
  const SharedPreferencesInfocutterStore({
    this.storageKey = infocutterRuleStoreKey,
  });

  final String storageKey;

  @override
  Future<String?> loadRuleStoreJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> saveRuleStoreJson(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}

abstract interface class TextBlockStore {
  Future<String?> loadTextBlockStoreJson();

  Future<void> saveTextBlockStoreJson(String raw);
}

class SharedPreferencesTextBlockStore implements TextBlockStore {
  const SharedPreferencesTextBlockStore({
    this.storageKey = infocutterTextBlockStoreKey,
  });

  final String storageKey;

  @override
  Future<String?> loadTextBlockStoreJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> saveTextBlockStoreJson(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}

abstract interface class NetworkFilterStore {
  Future<String?> loadNetworkFilterStoreJson();

  Future<void> saveNetworkFilterStoreJson(String raw);
}

class SharedPreferencesNetworkFilterStore implements NetworkFilterStore {
  const SharedPreferencesNetworkFilterStore({
    this.storageKey = infocutterNetworkFilterStoreKey,
  });

  final String storageKey;

  @override
  Future<String?> loadNetworkFilterStoreJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> saveNetworkFilterStoreJson(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}
