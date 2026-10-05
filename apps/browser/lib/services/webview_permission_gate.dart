import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

/// OS 런타임 권한을 요청한다. 허용되면 true.
typedef OsPermissionRequester = Future<bool> Function(Permission permission);

/// 페이지가 카메라·마이크를 요청할 때 OS 권한과 맞물려 판정한다.
///
/// 세 가지를 동시에 고친다.
///
/// 1. 앱 시작 시 카메라·마이크를 미리 묻던 upstream 잔재를 걷어냈다. 브라우저를
///    열자마자 문맥 없이 카메라를 물으면 사용자는 거절하거나 앱을 지운다.
/// 2. 그런데 사전 요청만 지우면 Android 가 조용히 망가진다. WebView 의 권한은 앱이
///    이미 가진 런타임 권한 위에서만 성립하므로, 웹 요청을 GRANT 해도 실제로는
///    아무것도 열리지 않는다. 그래서 요청이 들어온 그 순간에 OS 권한을 묻는다.
/// 3. 기존 핸들러는 모든 사이트의 모든 요청을 무조건 GRANT 했다. 어떤 경로로도
///    이제 조용한 승인은 없다 — OS 가 거절하면 DENY, 우리가 모르는 리소스는 PROMPT.
class WebViewPermissionGate {
  const WebViewPermissionGate({
    required this.requestOsPermission,
    required this.requiresOsGrant,
  });

  final OsPermissionRequester requestOsPermission;

  /// Android 만 true. 앱 런타임 권한이 웹 권한보다 먼저 있어야 한다.
  ///
  /// iOS·데스크톱은 플랫폼이 스스로 사용자에게 묻는다. 그 자리에서 앱이 대신
  /// 결정하면 사용자에게서 선택권을 빼앗는 것이므로 PROMPT 로 넘긴다.
  final bool requiresOsGrant;

  /// 웹 리소스 하나가 필요로 하는 OS 권한.
  ///
  /// 매핑이 없으면 우리가 판정 근거를 갖지 못한 리소스(클립보드·MIDI·화면 캡처 등)다.
  /// 그런 요청은 GRANT 도 DENY 도 우리가 정할 일이 아니라 사용자에게 물을 일이다.
  static List<Permission> osPermissionsFor(PermissionResourceType resource) {
    if (resource == PermissionResourceType.CAMERA) {
      return const [Permission.camera];
    }
    if (resource == PermissionResourceType.MICROPHONE) {
      return const [Permission.microphone];
    }
    if (resource == PermissionResourceType.CAMERA_AND_MICROPHONE) {
      return const [Permission.camera, Permission.microphone];
    }
    if (resource == PermissionResourceType.GEOLOCATION) {
      return const [Permission.locationWhenInUse];
    }
    return const [];
  }

  /// 요청된 리소스 전체가 필요로 하는 OS 권한(중복 제거).
  static List<Permission> osPermissionsForAll(
    List<PermissionResourceType> resources,
  ) {
    final permissions = <Permission>[];
    for (final resource in resources) {
      for (final permission in osPermissionsFor(resource)) {
        if (!permissions.contains(permission)) {
          permissions.add(permission);
        }
      }
    }
    return permissions;
  }

  /// 우리가 OS 권한으로 판정할 수 있는 요청인가.
  static bool isDecidable(List<PermissionResourceType> resources) {
    return resources.isNotEmpty &&
        resources.every((resource) => osPermissionsFor(resource).isNotEmpty);
  }

  Future<PermissionResponse> decide(PermissionRequest request) async {
    final resources = request.resources;
    if (!isDecidable(resources) || !requiresOsGrant) {
      return _respond(resources, PermissionResponseAction.PROMPT);
    }

    for (final permission in osPermissionsForAll(resources)) {
      if (!await requestOsPermission(permission)) {
        return _respond(resources, PermissionResponseAction.DENY);
      }
    }
    return _respond(resources, PermissionResponseAction.GRANT);
  }

  PermissionResponse _respond(
    List<PermissionResourceType> resources,
    PermissionResponseAction action,
  ) {
    return PermissionResponse(resources: resources, action: action);
  }
}

/// 실제 OS 권한 요청. 이미 허용돼 있으면 프롬프트 없이 통과한다.
Future<bool> requestOsPermission(Permission permission) async {
  final status = await permission.request();
  return status.isGranted || status.isLimited;
}
