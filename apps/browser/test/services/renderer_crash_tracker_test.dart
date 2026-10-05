import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/services/renderer_crash_tracker.dart';

void main() {
  final t0 = DateTime(2026, 8, 4, 12);

  group('RendererCrashTracker', () {
    test('첫 죽음은 한 번 자동으로 다시 싣는다', () {
      final tracker = RendererCrashTracker();
      expect(tracker.recordCrash(t0), RendererCrashAction.reload);
    });

    test('창 안에서 또 죽으면 재시도 고리 대신 화면을 보여준다', () {
      final tracker = RendererCrashTracker();
      tracker.recordCrash(t0);
      expect(
        tracker.recordCrash(t0.add(const Duration(seconds: 5))),
        RendererCrashAction.showPanel,
      );
    });

    test('창을 벗어나 한참 뒤에 죽으면 다시 첫 죽음으로 본다', () {
      final tracker = RendererCrashTracker();
      tracker.recordCrash(t0);
      expect(
        tracker.recordCrash(t0.add(const Duration(seconds: 31))),
        RendererCrashAction.reload,
      );
    });

    test('정상 로드가 끼면 직전 죽음을 잊는다', () {
      final tracker = RendererCrashTracker();
      tracker.recordCrash(t0);
      tracker.recordSuccessfulLoad();
      expect(tracker.lastCrashAt, isNull);
      expect(
        tracker.recordCrash(t0.add(const Duration(seconds: 2))),
        RendererCrashAction.reload,
      );
    });

    test('반복 창 길이는 주입할 수 있다', () {
      final tracker = RendererCrashTracker(
        repeatWindow: const Duration(seconds: 2),
      );
      tracker.recordCrash(t0);
      expect(
        tracker.recordCrash(t0.add(const Duration(seconds: 3))),
        RendererCrashAction.reload,
      );
    });
  });
}
