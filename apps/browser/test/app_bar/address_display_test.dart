import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/app_bar/address_display.dart';

void main() {
  group('displayAddress', () {
    test('collapses https and www', () {
      expect(displayAddress('https://www.example.com/'), 'example.com');
      expect(displayAddress('https://example.com/'), 'example.com');
    });

    test('keeps path, query and fragment', () {
      expect(
        displayAddress('https://www.example.com/a/b?q=1#top'),
        'example.com/a/b?q=1#top',
      );
    });

    test('keeps a non-default port', () {
      expect(
          displayAddress('https://example.com:8443/x'), 'example.com:8443/x');
    });

    test('does NOT collapse http — insecure connections stay visible', () {
      expect(displayAddress('http://example.com/'), 'http://example.com/');
      expect(
        displayAddress('http://www.example.com/a'),
        'http://www.example.com/a',
      );
    });

    test('leaves special schemes untouched', () {
      expect(displayAddress('about:blank'), 'about:blank');
      expect(displayAddress('file:///tmp/a.html'), 'file:///tmp/a.html');
      expect(displayAddress('data:text/html,hi'), 'data:text/html,hi');
    });

    test('handles empty and whitespace input', () {
      expect(displayAddress(''), '');
      expect(displayAddress('   '), '');
    });

    test('leaves plain search text untouched', () {
      expect(displayAddress('flutter bottom bar'), 'flutter bottom bar');
    });

    test('does not strip a host that is exactly "www."-like', () {
      expect(displayAddress('https://wwwx.example.com/'), 'wwwx.example.com');
    });
  });

  group('displayAddressHost', () {
    test('returns the collapsed host for https', () {
      expect(displayAddressHost('https://www.example.com/a'), 'example.com');
      expect(
        displayAddressHost('https://example.com:8443/a'),
        'example.com:8443',
      );
    });

    test('returns empty when nothing was collapsed', () {
      expect(displayAddressHost('http://example.com/'), '');
      expect(displayAddressHost('about:blank'), '');
      expect(displayAddressHost(''), '');
    });

    test('is always a prefix of displayAddress when non-empty', () {
      const raw = 'https://www.example.com/a/b?q=1';
      expect(displayAddress(raw).startsWith(displayAddressHost(raw)), isTrue);
    });
  });
}
