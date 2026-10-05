import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/services/webview_permission_gate.dart';
import 'package:permission_handler/permission_handler.dart';

PermissionRequest _request(List<PermissionResourceType> resources) {
  return PermissionRequest(
      origin: WebUri('https://example.test'), resources: resources);
}

void main() {
  group('osPermissionsFor', () {
    test('카메라·마이크는 대응하는 OS 권한으로 매핑된다', () {
      expect(
        WebViewPermissionGate.osPermissionsFor(PermissionResourceType.CAMERA),
        [Permission.camera],
      );
      expect(
        WebViewPermissionGate.osPermissionsFor(
          PermissionResourceType.MICROPHONE,
        ),
        [Permission.microphone],
      );
      expect(
        WebViewPermissionGate.osPermissionsFor(
          PermissionResourceType.CAMERA_AND_MICROPHONE,
        ),
        [Permission.camera, Permission.microphone],
      );
    });

    test('OS 권한이 필요 없는 리소스는 빈 목록이다', () {
      expect(
        WebViewPermissionGate.osPermissionsFor(
          PermissionResourceType.MIDI_SYSEX,
        ),
        isEmpty,
      );
    });

    test('여러 리소스의 OS 권한은 중복 없이 합쳐진다', () {
      expect(
        WebViewPermissionGate.osPermissionsForAll([
          PermissionResourceType.CAMERA,
          PermissionResourceType.CAMERA_AND_MICROPHONE,
        ]),
        [Permission.camera, Permission.microphone],
      );
    });
  });

  group('decide', () {
    test('iOS·데스크톱은 앱이 대신 정하지 않고 PROMPT 로 넘긴다', () async {
      final asked = <Permission>[];
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async {
          asked.add(permission);
          return true;
        },
        requiresOsGrant: false,
      );

      final response = await gate.decide(
        _request([PermissionResourceType.CAMERA]),
      );

      expect(response.action, PermissionResponseAction.PROMPT);
      expect(asked, isEmpty);
    });

    test('Android 는 OS 권한을 요청 시점에 묻고 허용되면 GRANT 한다', () async {
      final asked = <Permission>[];
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async {
          asked.add(permission);
          return true;
        },
        requiresOsGrant: true,
      );

      final response = await gate.decide(
        _request([PermissionResourceType.CAMERA_AND_MICROPHONE]),
      );

      expect(response.action, PermissionResponseAction.GRANT);
      expect(asked, [Permission.camera, Permission.microphone]);
    });

    test('OS 가 거절하면 웹 권한도 DENY 한다', () async {
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async => false,
        requiresOsGrant: true,
      );

      final response = await gate.decide(
        _request([PermissionResourceType.MICROPHONE]),
      );

      expect(response.action, PermissionResponseAction.DENY);
    });

    test('첫 권한이 거절되면 나머지를 더 묻지 않는다', () async {
      final asked = <Permission>[];
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async {
          asked.add(permission);
          return false;
        },
        requiresOsGrant: true,
      );

      await gate.decide(
        _request([PermissionResourceType.CAMERA_AND_MICROPHONE]),
      );

      expect(asked, [Permission.camera]);
    });

    test('판정 근거가 없는 리소스는 Android 에서도 PROMPT 다', () async {
      final asked = <Permission>[];
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async {
          asked.add(permission);
          return false;
        },
        requiresOsGrant: true,
      );

      final response = await gate.decide(
        _request([PermissionResourceType.MIDI_SYSEX]),
      );

      expect(response.action, PermissionResponseAction.PROMPT);
      expect(asked, isEmpty);
    });

    test('알 수 있는 리소스에 모르는 리소스가 섞이면 전체를 PROMPT 로 넘긴다', () async {
      final asked = <Permission>[];
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async {
          asked.add(permission);
          return true;
        },
        requiresOsGrant: true,
      );

      final response = await gate.decide(
        _request([
          PermissionResourceType.CAMERA,
          PermissionResourceType.MIDI_SYSEX,
        ]),
      );

      expect(response.action, PermissionResponseAction.PROMPT);
      expect(asked, isEmpty);
    });

    test('리소스가 비어 있으면 조용히 승인하지 않는다', () async {
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async => true,
        requiresOsGrant: true,
      );

      final response = await gate.decide(_request([]));

      expect(response.action, PermissionResponseAction.PROMPT);
    });

    test('응답은 요청받은 리소스를 그대로 되돌려준다', () async {
      final gate = WebViewPermissionGate(
        requestOsPermission: (permission) async => true,
        requiresOsGrant: true,
      );

      final resources = [
        PermissionResourceType.CAMERA,
        PermissionResourceType.MICROPHONE,
      ];
      final response = await gate.decide(_request(resources));

      expect(response.resources, resources);
    });
  });
}
