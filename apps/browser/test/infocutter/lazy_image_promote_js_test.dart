import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/generated/user_scripts.g.dart';

void main() {
  test('lazy_image_promote source is baked from assets/js', () {
    final asset = File('assets/js/lazy_image_promote.js').readAsStringSync();
    expect(lazyImagePromoteUserScriptSource.trim(), asset.trim());
  });

  test('lazy promote covers placeholder src and data-bg paths', () {
    final source = lazyImagePromoteUserScriptSource;
    expect(source, contains('isPlaceholderSrc'));
    expect(source, contains('data-bg'));
    expect(source, contains('data-lazysrc'));
    expect(source, contains('data-img-src'));
    expect(source, contains('nudgePageLazy'));
    expect(source, contains('loading'));
    expect(source, contains('eager'));
  });
}
