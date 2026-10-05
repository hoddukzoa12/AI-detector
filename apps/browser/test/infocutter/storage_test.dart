import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SharedPreferencesInfocutterStore load/save roundtrip', () async {
    const store = SharedPreferencesInfocutterStore();

    expect(await store.loadRuleStoreJson(), isNull);

    await store.saveRuleStoreJson('{"profiles":[]}');

    expect(await store.loadRuleStoreJson(), '{"profiles":[]}');
  });

  test('SharedPreferencesInfocutterStore supports a custom key', () async {
    const store = SharedPreferencesInfocutterStore(storageKey: 'custom.key');

    await store.saveRuleStoreJson('custom');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(infocutterRuleStoreKey), isNull);
    expect(prefs.getString('custom.key'), 'custom');
  });

  test('SharedPreferencesTextBlockStore load/save roundtrip', () async {
    const store = SharedPreferencesTextBlockStore();

    expect(await store.loadTextBlockStoreJson(), isNull);

    await store.saveTextBlockStoreJson('{"version":1}');

    expect(await store.loadTextBlockStoreJson(), '{"version":1}');
  });

  test('SharedPreferencesNetworkFilterStore load/save roundtrip', () async {
    const store = SharedPreferencesNetworkFilterStore();

    expect(await store.loadNetworkFilterStoreJson(), isNull);

    await store.saveNetworkFilterStoreJson('{"version":1}');

    expect(await store.loadNetworkFilterStoreJson(), '{"version":1}');
  });
}
