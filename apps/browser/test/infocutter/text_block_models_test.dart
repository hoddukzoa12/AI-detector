import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/text_block_models.dart';

void main() {
  const codec = TextBlockCodec();

  test('decodes Chrome text block store JSON', () {
    final snapshot = codec.decodeJson('''
{
  "version": 1,
  "settings": {
    "globalEnabled": true,
    "hiddenObjectTags": ["ad", "promo", "ad"]
  },
  "profiles": [
    {
      "enabled": true,
      "id": "tp1",
      "matchers": ["https://example.com/*"],
      "name": "Example text",
      "updatedAt": "2026-01-01T00:00:00Z",
      "rules": [
        {
          "createdAt": "2026-01-01T00:00:00Z",
          "enabled": true,
          "fingerprint": "div.card",
          "id": "tr1",
          "keyword": "Sponsored",
          "minMatchCount": 3,
          "objectId": "obj1",
          "objectName": "Ads",
          "objectTags": ["ad"],
          "updatedAt": "2026-01-02T00:00:00Z"
        }
      ]
    }
  ]
}
''');

    expect(snapshot.globalEnabled, isTrue);
    expect(snapshot.hiddenObjectTags, ['ad', 'promo']);
    expect(snapshot.profiles.single.name, 'Example text');
    expect(snapshot.profiles.single.rules.single.keyword, 'Sponsored');
    expect(snapshot.profiles.single.rules.single.minMatchCount, 3);
  });

  test('buildActiveTextBlockState matches profile by URL matcher', () {
    final snapshot = codec.decodeJson('''
{
  "version": 1,
  "settings": {"globalEnabled": true, "hiddenObjectTags": ["ad"]},
  "profiles": [
    {
      "enabled": false,
      "id": "tp1",
      "matchers": ["https://example.com/news/*"],
      "name": "Example text",
      "updatedAt": "2026-01-01T00:00:00Z",
      "rules": [{"id": "r1", "keyword": "Sponsored", "minMatchCount": 1}]
    }
  ]
}
''');

    final state = buildActiveTextBlockState(
      snapshot,
      Uri.parse('https://example.com/news/1'),
    );

    expect(state.activeProfileId, 'tp1');
    expect(state.profileEnabled, isFalse);
    expect(state.ruleCount, 1);
    expect(state.rules.single.minMatchCount, 2);
  });
}
