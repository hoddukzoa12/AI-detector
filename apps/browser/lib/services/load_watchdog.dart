import 'dart:async';

/// 메인 프레임 네비게이션이 `onLoadStop`/`onReceivedError` 없이 멈출 때 감지.
///
/// 렌더러가 시작조차 못 하면 `onReceivedError` 가 안 온다 (#25).
class LoadWatchdog {
  LoadWatchdog({this.timeout = const Duration(seconds: 25)});

  final Duration timeout;

  Timer? _timer;
  int _generation = 0;

  /// 새 메인 프레임 로드를 감시한다. 이전 타이머는 취소된다.
  void arm(void Function() onTimeout) {
    cancel();
    final gen = ++_generation;
    _timer = Timer(timeout, () {
      if (gen != _generation) {
        return;
      }
      onTimeout();
    });
  }

  /// 로드 완료·오류·탭 폐기 시 호출.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }

  bool get isArmed => _timer?.isActive ?? false;
}
