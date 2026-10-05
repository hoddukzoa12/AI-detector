/// 인증(로그인) origin 판정.
///
/// Google 등 여러 IdP 는 임베디드 웹뷰에서의 계정 로그인을 정책으로 차단한다
/// (`403 disallowed_useragent`). 그리고 그 정책이 막으려는 위협 모델이 바로
/// "인증 페이지에 스크립트를 주입하고 요청을 가로채는 앱" 이다. 따라서 이 앱은
/// 인증 origin 에서 주입·가로채기를 전부 끄고, 사용자에게 안내만 띄운다.
///
/// 순수 함수 — 서비스나 위젯 상태에 의존하지 않는다.
library;

/// 호스트 전체(및 그 서브도메인)가 인증 origin 인 도메인.
const List<String> _authHosts = <String>[
  'accounts.google.com',
  'login.microsoftonline.com',
  'appleid.apple.com',
];

/// 호스트는 공용이고 특정 경로 이하만 인증 흐름인 항목.
const List<(String host, String pathPrefix)> _authHostPaths =
    <(String, String)>[
  ('github.com', '/login'),
  ('gitlab.com', '/users/sign_in'),
];

/// [url] 이 인증(로그인) origin 이면 true.
///
/// 판정 규칙:
/// - `http`/`https` 스킴만 대상. 그 외(about:, data:, file: …)는 false.
/// - 호스트는 대소문자를 무시하고, 뒤따르는 루트 점(`accounts.google.com.`)을
///   정규화한다. 포트는 판정에 영향을 주지 않는다.
/// - 서브도메인은 인증 origin 으로 본다(`x.accounts.google.com`).
///   접미사만 같은 유사 도메인은 아니다(`accounts.google.com.evil.com`,
///   `evilaccounts.google.com`).
/// - 경로 항목은 세그먼트 경계까지 본다. `/login`, `/login/`, `/login/oauth`
///   는 인증이고 `/loginfoo` 는 아니다.
bool isAuthOrigin(Uri? url) {
  if (url == null) return false;

  final scheme = url.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;

  final host = _normalizeHost(url.host);
  if (host.isEmpty) return false;

  for (final authHost in _authHosts) {
    if (_hostMatches(host, authHost)) return true;
  }

  final path = _normalizePath(url.path);
  for (final (authHost, prefix) in _authHostPaths) {
    if (_hostMatches(host, authHost) && _pathMatches(path, prefix)) {
      return true;
    }
  }

  return false;
}

String _normalizeHost(String host) {
  var normalized = host.toLowerCase().trim();
  // 절대 DNS 이름의 루트 점을 떼어낸다: "accounts.google.com." == 같은 호스트.
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String _normalizePath(String path) => path.isEmpty ? '/' : path;

/// [host] 가 [authHost] 자신이거나 그 서브도메인이면 true.
/// 점 경계를 강제하므로 `evilaccounts.google.com` 은 걸리지 않는다.
bool _hostMatches(String host, String authHost) {
  if (host == authHost) return true;
  return host.endsWith('.$authHost');
}

/// [path] 가 [prefix] 자신이거나 그 하위 세그먼트면 true.
bool _pathMatches(String path, String prefix) {
  if (path == prefix) return true;
  return path.startsWith('$prefix/');
}
