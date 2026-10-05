// PoC (throwaway spike): verify the Codex-style "Sign in with ChatGPT" flow
// actually yields a usable OpenAI API key.
//
//   fvm dart run tool/openai_oauth_poc.dart
//
// Flow (mirrors Codex CLI):
//   1. browser OAuth (PKCE) -> auth.openai.com/oauth/authorize
//   2. code -> tokens        (grant_type=authorization_code)
//   3. id_token -> API key   (grant_type=token-exchange, requested_token=openai-api-key)
//   4. probe the key against api.openai.com/v1/models
//
// Prints only MASKED secrets. Stores nothing on disk. Delete after verifying.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _clientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
const _authorizeUrl = 'https://auth.openai.com/oauth/authorize';
const _tokenUrl = 'https://auth.openai.com/oauth/token';
const _callbackPort = 1455;
const _redirectUri = 'http://localhost:1455/auth/callback';

Future<void> main(List<String> args) async {
  final verifier = _randomUrlSafe(64);
  final challenge = _b64url(sha256.convert(utf8.encode(verifier)).bytes);
  final state = _randomUrlSafe(32);

  final authorizeUri = Uri.parse(_authorizeUrl).replace(queryParameters: {
    'response_type': 'code',
    'client_id': _clientId,
    'redirect_uri': _redirectUri,
    'scope': 'openid profile email offline_access',
    'code_challenge': challenge,
    'code_challenge_method': 'S256',
    'state': state,
    'id_token_add_organizations': 'true',
    'codex_cli_simplified_flow': 'true',
    'originator': 'codex_cli_rs',
  });

  final server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, _callbackPort);
  stdout.writeln('[1/4] callback server listening on $_redirectUri');

  final codeCompleter = Completer<String>();
  unawaited(_serveCallback(server, state, codeCompleter));

  stdout.writeln('[2/4] opening browser for ChatGPT login...');
  stdout.writeln('       if it does not open, paste this URL manually:\n');
  stdout.writeln('       $authorizeUri\n');
  await Process.run('open', [authorizeUri.toString()]);

  final String code;
  try {
    code = await codeCompleter.future.timeout(const Duration(minutes: 10));
  } on TimeoutException {
    stderr.writeln('ERROR: timed out waiting for the OAuth callback (10 min). '
        'No request ever reached the loopback server -> the browser/login '
        'step did not redirect back. Check the browser for an OpenAI-side error.');
    await server.close(force: true);
    exit(1);
  } catch (e) {
    stderr.writeln('ERROR: OAuth callback failed: $e');
    await server.close(force: true);
    exit(1);
  }
  await server.close(force: true);
  stdout.writeln('[2/4] got authorization code (${_mask(code)})');

  // Step 3a: code -> tokens
  final tokenJson = await _postForm(_tokenUrl, {
    'grant_type': 'authorization_code',
    'client_id': _clientId,
    'code': code,
    'code_verifier': verifier,
    'redirect_uri': _redirectUri,
  });
  final idToken = tokenJson['id_token'] as String?;
  final accessToken = tokenJson['access_token'] as String?;
  final refreshToken = tokenJson['refresh_token'] as String?;
  stdout.writeln('[3/4] token exchange (authorization_code) ->');
  stdout.writeln('       id_token:      ${_mask(idToken)}');
  stdout.writeln('       access_token:  ${_mask(accessToken)}');
  stdout.writeln('       refresh_token: ${_mask(refreshToken)}');
  stdout.writeln('       account claim: ${_accountIdClaim(accessToken)}');
  if (idToken == null) {
    stderr.writeln(
        'ERROR: no id_token returned; cannot exchange for an API key.');
    exit(1);
  }

  // Step 3b: id_token -> API key
  final keyJson = await _postForm(_tokenUrl, {
    'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
    'client_id': _clientId,
    'requested_token': 'openai-api-key',
    'subject_token': idToken,
    'subject_token_type': 'urn:ietf:params:oauth:token-type:id_token',
  });
  stdout.writeln('[4/4] token-exchange (openai-api-key) response keys: '
      '${keyJson.keys.toList()}');
  final apiKey = _extractApiKey(keyJson);
  if (apiKey == null) {
    stderr.writeln('RESULT: no API key field found in the exchange response.');
    stderr.writeln('        raw (masked): ${_maskJson(keyJson)}');
    exit(1);
  }
  stdout.writeln('       API key: ${_mask(apiKey)}  (len ${apiKey.length})');

  // Step 4: probe the key
  stdout.writeln('\n--- probing key against api.openai.com/v1/models ---');
  await _probeKey(apiKey);
}

Future<void> _serveCallback(
  HttpServer server,
  String expectedState,
  Completer<String> completer,
) async {
  await for (final req in server) {
    // Evidence: log EVERY request that reaches the loopback server so a silent
    // timeout can be told apart from an OAuth error redirect.
    stdout.writeln('       <- ${req.method} ${req.uri.path} '
        'params=${req.uri.queryParameters.keys.toList()}');

    if (req.uri.path != '/auth/callback') {
      // favicon, etc. Keep listening for the real callback.
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      continue;
    }

    final params = req.uri.queryParameters;
    final error = params['error'];
    if (error != null) {
      stderr.writeln('       OAuth error redirect: $error '
          '/ ${params['error_description']}');
      req.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.html
        ..write(
            '<h2>OAuth 오류: $error</h2><p>${params['error_description']}</p>');
      await req.response.close();
      if (!completer.isCompleted) {
        completer.completeError(StateError('oauth error: $error'));
      }
      return;
    }

    final code = params['code'];
    final gotState = params['state'];
    if (code == null) {
      stderr.writeln('       callback without code; params=$params');
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      if (!completer.isCompleted) {
        completer.completeError(StateError('callback without code'));
      }
      return;
    }
    if (gotState != expectedState) {
      stderr.writeln('       state mismatch: got "$gotState" '
          'expected "$expectedState"');
    }
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('<h2>로그인 완료. 이 창을 닫고 터미널로 돌아가세요.</h2>');
    await req.response.close();
    if (!completer.isCompleted) {
      completer.complete(code);
    }
    return;
  }
}

Future<Map<String, dynamic>> _postForm(
    String url, Map<String, String> form) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    final body = form.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    req.write(body);
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 400) {
      stderr.writeln('HTTP ${resp.statusCode} from $url: $text');
    }
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : {'_raw': text};
  } finally {
    client.close(force: true);
  }
}

Future<void> _probeKey(String apiKey) async {
  final client = HttpClient();
  try {
    final req =
        await client.getUrl(Uri.parse('https://api.openai.com/v1/models'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    stdout.writeln('HTTP ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = jsonDecode(text);
      final models = (data is Map && data['data'] is List)
          ? (data['data'] as List).length
          : -1;
      stdout.writeln('SUCCESS: key works. visible models: $models');
    } else {
      stdout.writeln('key rejected. body (masked): ${_truncate(text, 300)}');
    }
  } finally {
    client.close(force: true);
  }
}

String? _extractApiKey(Map<String, dynamic> json) {
  for (final k in ['access_token', 'api_key', 'token', 'key']) {
    final v = json[k];
    if (v is String && v.isNotEmpty) return v;
  }
  // fall back: any string value that looks like an OpenAI key
  for (final v in json.values) {
    if (v is String && (v.startsWith('sk-') || v.startsWith('key-'))) return v;
  }
  return null;
}

String _accountIdClaim(String? jwt) {
  if (jwt == null) return '(none)';
  final parts = jwt.split('.');
  if (parts.length < 2) return '(malformed)';
  try {
    final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final auth = payload['https://api.openai.com/auth'];
    if (auth is Map) {
      return 'plan=${auth['chatgpt_plan_type']} account=${_mask(auth['chatgpt_account_id'] as String?)}';
    }
    return '(no auth claim)';
  } catch (_) {
    return '(undecodable)';
  }
}

String _randomUrlSafe(int bytes) {
  final rng = Random.secure();
  return _b64url(List<int>.generate(bytes, (_) => rng.nextInt(256)));
}

String _b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String _mask(String? s) {
  if (s == null || s.isEmpty) return '(none)';
  if (s.length <= 10) return '${s[0]}***';
  return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
}

String _maskJson(Map<String, dynamic> json) =>
    json.map((k, v) => MapEntry(k, v is String ? _mask(v) : v)).toString();

String _truncate(String s, int n) =>
    s.length <= n ? s : '${s.substring(0, n)}...';
