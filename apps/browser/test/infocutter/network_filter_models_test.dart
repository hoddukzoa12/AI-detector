import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/network_filter_models.dart';

void main() {
  const parser = NetworkFilterParser();

  test('parses supported network block and allow filters', () {
    final result = parser.parse(r'''
||ads.example.com^$image,script
@@||cdn.example.com^$script
''');

    expect(result.supportedCount, 2);
    expect(result.skippedCount, 0);
    expect(result.rules.first.allow, isFalse);
    expect(result.rules.first.pattern, '||ads.example.com^');
    expect(result.rules.first.modifiers, ['image', 'script']);
    expect(result.rules.last.allow, isTrue);
  });

  test('keeps unsupported modifier skip reason', () {
    final result = parser.parse(r'||ads.example.com^$redirect-rule');

    expect(result.supportedCount, 0);
    expect(result.skippedCount, 1);
    expect(result.rules.single.skipReason, contains('unsupported modifier'));
  });

  test('separates cosmetic and text rules from network rules', () {
    final result = parser.parse('''
example.com##.ad
example.com#?#.item:contains("Sponsored")
''');

    expect(result.rules, hasLength(2));
    expect(result.rules.first.kind, NetworkFilterKind.cosmetic);
    expect(result.rules.first.skipReason, 'not a network request rule');
    expect(result.rules.last.kind, NetworkFilterKind.text);
  });
}
