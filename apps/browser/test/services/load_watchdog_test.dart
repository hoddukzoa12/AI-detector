import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/services/load_watchdog.dart';

void main() {
  test('timeout fires once after duration', () async {
    var fired = 0;
    final watchdog = LoadWatchdog(timeout: const Duration(milliseconds: 30));
    watchdog.arm(() => fired++);
    expect(watchdog.isArmed, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, 1);
    expect(watchdog.isArmed, isFalse);
  });

  test('cancel prevents timeout', () async {
    var fired = 0;
    final watchdog = LoadWatchdog(timeout: const Duration(milliseconds: 40));
    watchdog.arm(() => fired++);
    watchdog.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, 0);
  });

  test('re-arm cancels previous timer', () async {
    var fired = 0;
    final watchdog = LoadWatchdog(timeout: const Duration(milliseconds: 40));
    watchdog.arm(() => fired += 10);
    watchdog.arm(() => fired += 1);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, 1);
  });
}
