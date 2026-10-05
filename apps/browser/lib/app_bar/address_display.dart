/// 주소창에 "보여줄" 문자열을 만드는 순수 함수 모음.
///
/// 편집 중에는 전체 URL 을 그대로 쓰고, 편집하지 않을 때만 이 변환을 거친다.
/// 접는 대상은 **https 뿐**이다 — http/file/about 처럼 안전하지 않거나 특수한
/// 스킴을 접으면 사용자가 연결 상태를 알 수 없다.
library;

const _wwwPrefix = 'www.';

/// 포커스가 없을 때 주소창에 보여줄 문자열.
///
/// `https://www.example.com/` → `example.com`
/// `http://example.com/` → 원문 그대로 (안전하지 않은 연결은 감추지 않는다)
String displayAddress(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return trimmed;
  }

  final buffer = StringBuffer(_collapseHost(uri.host));
  if (uri.hasPort) {
    buffer.write(':${uri.port}');
  }
  if (uri.path != '/') {
    buffer.write(uri.path);
  }
  if (uri.hasQuery) {
    buffer.write('?${uri.query}');
  }
  if (uri.hasFragment) {
    buffer.write('#${uri.fragment}');
  }
  return buffer.toString();
}

/// [displayAddress] 결과에서 **강조할 호스트 구간**.
///
/// 접기가 일어나지 않은 주소(http 등)는 빈 문자열을 돌려준다 — 강조 없이
/// 원문 전체를 같은 톤으로 보여주라는 뜻이다.
String displayAddressHost(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return '';
  }

  final host = _collapseHost(uri.host);
  return uri.hasPort ? '$host:${uri.port}' : host;
}

String _collapseHost(String host) {
  if (host.length > _wwwPrefix.length && host.startsWith(_wwwPrefix)) {
    return host.substring(_wwwPrefix.length);
  }
  return host;
}
