import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final request = _ControlRequest.parse(args);
  final service =
      await vmServiceConnectUri(_toWebSocketUri(request.vmServiceUri));

  try {
    final vm = await service.getVM();
    final isolateId = vm.isolates?.firstOrNull?.id;
    if (isolateId == null) {
      throw StateError('No running Dart isolate found.');
    }

    final response = await service.callServiceExtension(
      'ext.infocutter_app.control',
      isolateId: isolateId,
      args: request.extensionArgs,
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(response.json));
  } finally {
    await service.dispose();
  }
}

String _toWebSocketUri(String rawUri) {
  final uri = Uri.parse(rawUri);
  final scheme = switch (uri.scheme) {
    'http' => 'ws',
    'https' => 'wss',
    'ws' || 'wss' => uri.scheme,
    _ =>
      throw ArgumentError('Unsupported VM service URI scheme: ${uri.scheme}'),
  };

  final path = uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
  return uri.replace(scheme: scheme, path: path).toString();
}

class _ControlRequest {
  const _ControlRequest({
    required this.vmServiceUri,
    required this.extensionArgs,
  });

  final String vmServiceUri;
  final Map<String, String> extensionArgs;

  static _ControlRequest parse(List<String> args) {
    String? vmServiceUri;
    final positional = <String>[];

    for (var i = 0; i < args.length; i += 1) {
      final arg = args[i];
      if (arg == '--vm-service-uri') {
        if (i + 1 >= args.length) {
          _usage('Missing value for --vm-service-uri.');
        }
        vmServiceUri = args[++i];
      } else if (arg.startsWith('--vm-service-uri=')) {
        vmServiceUri = arg.substring('--vm-service-uri='.length);
      } else {
        positional.add(arg);
      }
    }

    if (vmServiceUri == null || vmServiceUri.isEmpty) {
      _usage('Missing --vm-service-uri.');
    }
    if (positional.isEmpty) {
      _usage('Missing command.');
    }

    switch (positional[0]) {
      case 'get-state':
        return _ControlRequest(
          vmServiceUri: vmServiceUri,
          extensionArgs: const {'command': 'getState'},
        );
      case 'open-url':
        if (positional.length < 2) {
          _usage('open-url requires a URL or search value.');
        }
        return _ControlRequest(
          vmServiceUri: vmServiceUri,
          extensionArgs: {'command': 'openUrl', 'url': positional[1]},
        );
      default:
        _usage('Unsupported command: ${positional[0]}');
    }
  }
}

Never _usage(String error) {
  stderr.writeln(error);
  stderr.writeln();
  stderr.writeln('Usage:');
  stderr.writeln(
    '  dart run tool/infocutter_control.dart --vm-service-uri <uri> get-state',
  );
  stderr.writeln(
    '  dart run tool/infocutter_control.dart --vm-service-uri <uri> open-url naver.com',
  );
  exit(64);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
