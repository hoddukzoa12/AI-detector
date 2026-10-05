/// 웹 렌더러 프로세스가 죽었을 때 무엇을 할지 정하는 정책.
///
/// iOS/macOS 의 `onWebContentProcessDidTerminate`, Android 의
/// `onRenderProcessGone` 은 둘 다 "렌더러가 사라졌고 화면은 빈 채로 남았다" 는
/// 같은 사실을 알린다. 이때 조용히 흰 화면을 두면 사용자는 원인을 알 수 없다.
///
/// 정책은 단순하다.
/// - 첫 죽음은 일시적일 수 있으니 한 번 자동으로 다시 싣는다.
/// - 그 직후(기본 30초) 또 죽으면 재시도 고리에 빠진 것이므로 멈추고
///   사용자에게 이유를 보여준다.
/// - 창(window)을 벗어나 한참 뒤에 죽으면 다시 첫 죽음으로 본다.
enum RendererCrashAction {
  /// 한 번 자동으로 다시 싣는다.
  reload,

  /// 반복 중이다 — 화면에 사유를 드러낸다.
  showPanel,
}

class RendererCrashTracker {
  RendererCrashTracker({
    this.repeatWindow = const Duration(seconds: 30),
  });

  /// 이 시간 안에 또 죽으면 "반복" 으로 판정한다.
  final Duration repeatWindow;

  DateTime? _lastCrashAt;

  DateTime? get lastCrashAt => _lastCrashAt;

  RendererCrashAction recordCrash(DateTime now) {
    final previous = _lastCrashAt;
    _lastCrashAt = now;

    if (previous == null) {
      return RendererCrashAction.reload;
    }
    if (now.difference(previous) < repeatWindow) {
      return RendererCrashAction.showPanel;
    }
    return RendererCrashAction.reload;
  }

  /// 페이지가 정상적으로 실린 뒤 호출한다 — 다음 죽음은 다시 첫 죽음이다.
  void recordSuccessfulLoad() {
    _lastCrashAt = null;
  }
}
