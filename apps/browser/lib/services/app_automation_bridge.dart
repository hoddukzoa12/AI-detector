import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:infocutter_app/services/app_automation_controller.dart';

typedef AppAutomationRunner = Future<AppAutomationResult> Function(
  String action,
  Map<String, Object?> args,
);
typedef AppAutomationSnapshotReader = Map<String, Object?> Function();

class AppAutomationBridge {
  AppAutomationBridge({
    required AppAutomationRunner run,
    required AppAutomationSnapshotReader snapshot,
  })  : _run = run,
        _snapshot = snapshot;

  factory AppAutomationBridge.forController(
      AppAutomationController controller) {
    return AppAutomationBridge(
      run: controller.run,
      snapshot: controller.snapshot,
    );
  }

  static const defaultPort = int.fromEnvironment(
    'INFOCUTTER_AUTOMATION_PORT',
    defaultValue: 47821,
  );
  static const authToken = String.fromEnvironment(
    'INFOCUTTER_AUTOMATION_TOKEN',
  );

  // Capability tier model.
  //
  // The bridge is debug-only and binds to loopback, but a loopback-only socket
  // is still reachable by any other local process (a malicious helper, a
  // browser page abusing a fetch, etc.). We therefore split actions into two
  // tiers:
  //
  //   * Normal tier  - read/mutating automation (state.read, tab.open, ...).
  //                    Allowed with no token so local tooling stays ergonomic.
  //   * Dangerous tier - actions that are RCE-equivalent or can exfiltrate /
  //                    overwrite secrets. Refused outright when no token is
  //                    configured; only an explicitly-tokened (and authorized)
  //                    caller may invoke them.
  //
  // page.evalJs      -> arbitrary JS in the authenticated page (RCE-equivalent)
  // ai.config        -> can overwrite the stored API key / endpoint
  // page.screenshot  -> can exfiltrate the authenticated page
  // evidence.capture -> can exfiltrate the authenticated page
  static const dangerousActions = <String>{
    'page.evalJs',
    'ai.config',
    'page.screenshot',
    'evidence.capture',
    'cookie.list',
    'cookie.get',
    'cookie.set',
    'cookie.delete',
    'browser.clearData',
  };

  final AppAutomationRunner _run;
  final AppAutomationSnapshotReader _snapshot;

  HttpServer? _server;

  Uri? get uri {
    final server = _server;
    if (server == null) return null;
    return Uri(scheme: 'http', host: '127.0.0.1', port: server.port);
  }

  Future<void> start({int port = defaultPort}) async {
    if (!kDebugMode || _server != null) return;
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: true,
    );
    _server = server;
    unawaited(_serve(server));
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        _writeNoContent(request);
        return;
      }
      if (!_isAuthorized(request)) {
        _writeJson(request, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'unauthorized',
        });
        return;
      }

      final path = request.uri.path;
      if (request.method == 'GET' && path == '/health') {
        _writeJson(request, HttpStatus.ok, {
          'ok': true,
          'name': 'infocutter-automation-bridge',
          'debugOnly': true,
          'authRequired': authToken.isNotEmpty,
        });
        return;
      }
      if (request.method == 'GET' && path == '/state') {
        _writeJson(request, HttpStatus.ok, _snapshot());
        return;
      }
      if (request.method == 'POST' && path == '/run') {
        await _handleRun(request);
        return;
      }

      _writeJson(request, HttpStatus.notFound, {
        'ok': false,
        'error': 'not found',
      });
    } on FormatException catch (error) {
      _writeJson(request, HttpStatus.badRequest, {
        'ok': false,
        'error': error.message,
      });
    } catch (error) {
      _writeJson(request, HttpStatus.internalServerError, {
        'ok': false,
        'error': error.toString(),
      });
    }
  }

  /// Parse + tier-gate + dispatch a `POST /run`. Thrown [FormatException]s
  /// propagate to [_handle]'s error handling.
  Future<void> _handleRun(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final payload = _decodeObject(body);
    final action = payload['action'];
    if (action is! String || action.trim().isEmpty) {
      throw const FormatException('action must be a non-empty string');
    }
    // Tier gate: dangerous actions require an explicitly configured bridge
    // token. With no token, an unauthenticated localhost caller reaches
    // _handle (since _isAuthorized returns true) but must not be able to run
    // RCE/exfiltration/secret actions. When a token IS configured the request
    // already passed _isAuthorized, so all tiers are allowed.
    final trimmedAction = action.trim();
    if (authToken.isEmpty && dangerousActions.contains(trimmedAction)) {
      _writeJson(request, HttpStatus.forbidden, {
        'ok': false,
        'error': 'dangerous action $trimmedAction requires a bridge token',
      });
      return;
    }
    final args = _decodeArgs(payload['args']);
    final result = await _run(action, args);
    _writeJson(
      request,
      result.ok ? HttpStatus.ok : HttpStatus.badRequest,
      result.toJson(),
    );
  }

  bool _isAuthorized(HttpRequest request) {
    if (authToken.isEmpty) return true;
    final bearer = request.headers.value(HttpHeaders.authorizationHeader);
    final token = request.headers.value('x-infocutter-automation-token');
    return bearer == 'Bearer $authToken' || token == authToken;
  }

  Map<String, Object?> _decodeObject(String body) {
    final decoded = jsonDecode(body.isEmpty ? '{}' : body);
    if (decoded is! Map) {
      throw const FormatException('body must be a JSON object');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, Object?> _decodeArgs(Object? value) {
    if (value == null) return const {};
    if (value is! Map) {
      throw const FormatException('args must be a JSON object');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  void _writeNoContent(HttpRequest request) {
    _addCorsHeaders(request);
    request.response.statusCode = HttpStatus.noContent;
    unawaited(request.response.close());
  }

  void _writeJson(
    HttpRequest request,
    int statusCode,
    Map<String, Object?> payload,
  ) {
    _addCorsHeaders(request);
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    unawaited(request.response.close());
  }

  void _addCorsHeaders(HttpRequest request) {
    request.response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, 'http://127.0.0.1')
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET,POST,OPTIONS')
      ..set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'authorization,content-type,x-infocutter-automation-token',
      );
  }
}
