import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/services/app_automation_bridge.dart';
import 'package:infocutter_app/services/app_automation_controller.dart';

void main() {
  test('debug bridge serves state and dispatches commands over localhost',
      () async {
    final bridge = AppAutomationBridge(
      snapshot: () => {
        'tabs': 1,
        'capabilities': ['state.read', 'tab.open'],
      },
      run: (action, args) async {
        return AppAutomationResult.success(action, {
          'received': args,
        });
      },
    );

    await bridge.start(port: 0);
    addTearDown(bridge.stop);

    final base = bridge.uri;
    expect(base, isNotNull);

    final client = HttpClient();
    addTearDown(client.close);

    final health = await _getJson(client, base!.resolve('/health'));
    expect(health['ok'], isTrue);
    expect(health['debugOnly'], isTrue);

    final state = await _getJson(client, base.resolve('/state'));
    expect(state['tabs'], 1);
    expect(state['capabilities'], contains('tab.open'));

    final result = await _postJson(client, base.resolve('/run'), {
      'action': 'tab.open',
      'args': {'target': 'https://example.com'},
    });
    expect(result['ok'], isTrue);
    expect(result['action'], 'tab.open');
    expect(result['received'], {'target': 'https://example.com'});
  });

  test('debug bridge tier gate rejects dangerous actions without a token',
      () async {
    // No INFOCUTTER_AUTOMATION_TOKEN is defined in the test run, so the bridge
    // is in the "no token configured" tier: normal actions are allowed but
    // dangerous (RCE/exfiltration/secret) actions must be refused with 403.
    expect(AppAutomationBridge.authToken, isEmpty);

    var dispatched = false;
    final bridge = AppAutomationBridge(
      snapshot: () => {'tabs': 0},
      run: (action, args) async {
        dispatched = true;
        return AppAutomationResult.success(action, {'received': args});
      },
    );

    await bridge.start(port: 0);
    addTearDown(bridge.stop);

    final base = bridge.uri;
    expect(base, isNotNull);

    final client = HttpClient();
    addTearDown(client.close);

    // Dangerous action -> 403, controller never invoked.
    for (final action in AppAutomationBridge.dangerousActions) {
      final response = await _postRun(client, base!.resolve('/run'), {
        'action': action,
        'args': const <String, Object?>{},
      });
      expect(response.statusCode, HttpStatus.forbidden,
          reason: '$action should be rejected without a token');
      expect(response.body['ok'], isFalse);
      expect(response.body['error'],
          'dangerous action $action requires a bridge token');
    }
    expect(dispatched, isFalse,
        reason: 'dangerous actions must not reach the controller');

    // Benign action -> 200, controller invoked.
    final allowed = await _postRun(client, base!.resolve('/run'), {
      'action': 'state.read',
      'args': const <String, Object?>{},
    });
    expect(allowed.statusCode, HttpStatus.ok);
    expect(allowed.body['ok'], isTrue);
    expect(dispatched, isTrue);
  });
}

class _RunResponse {
  _RunResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object?> body;
}

Future<_RunResponse> _postRun(
  HttpClient client,
  Uri uri,
  Map<String, Object?> payload,
) async {
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(payload));
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  return _RunResponse(response.statusCode, _decodeJson(body));
}

Future<Map<String, Object?>> _getJson(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  expect(response.statusCode, HttpStatus.ok);
  return _decodeJson(body);
}

Future<Map<String, Object?>> _postJson(
  HttpClient client,
  Uri uri,
  Map<String, Object?> payload,
) async {
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(payload));
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  expect(response.statusCode, HttpStatus.ok);
  return _decodeJson(body);
}

Map<String, Object?> _decodeJson(String body) {
  final decoded = jsonDecode(body);
  expect(decoded, isA<Map>());
  return (decoded as Map).map((key, value) => MapEntry(key.toString(), value));
}
