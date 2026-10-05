import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/site_protection_bypass.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('host bypass is normalized without www', () async {
    final bypass = SiteProtectionBypass();
    await bypass.ensureLoaded();
    await bypass.setBypassed(Uri.parse('https://www.example.com/a'),
        bypassed: true);
    expect(bypass.isBypassed(Uri.parse('https://example.com/b')), isTrue);
    expect(bypass.isBypassed(Uri.parse('https://other.com')), isFalse);
  });

  test('clear removes host', () async {
    final bypass = SiteProtectionBypass();
    await bypass.ensureLoaded();
    final url = Uri.parse('https://m.naver.com/');
    await bypass.setBypassed(url, bypassed: true);
    await bypass.setBypassed(url, bypassed: false);
    expect(bypass.isBypassed(url), isFalse);
  });
}
