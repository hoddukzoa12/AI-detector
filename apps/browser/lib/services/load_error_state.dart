/// 로드 실패 오버레이에 넘길 최소 정보.
class LoadErrorState {
  const LoadErrorState({
    required this.url,
    required this.reason,
  });

  final String? url;
  final String reason;
}
