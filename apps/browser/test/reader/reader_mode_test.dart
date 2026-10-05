import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/reader/reader_mode.dart';

void main() {
  test('reader extract script mentions article and main', () {
    expect(ReaderMode.extractJs, contains('article'));
    expect(ReaderMode.extractJs, contains('main'));
    expect(ReaderMode.extractJs, contains('JSON.stringify'));
  });
}
