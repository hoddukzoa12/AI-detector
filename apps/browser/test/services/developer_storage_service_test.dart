import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/services/developer_storage_service.dart';

void main() {
  group('DeveloperStorageService', () {
    test('exposes storage gateways through interfaces', () {
      final cookies = _FakeCookieStorage();
      final webStorage = _FakePlatformWebStorage();
      final httpAuthCredentials = _FakeHttpAuthCredentials();

      final service = DeveloperStorageService(
        cookies: cookies,
        webStorage: webStorage,
        httpAuthCredentials: httpAuthCredentials,
      );

      expect(service.cookies, same(cookies));
      expect(service.webStorage, same(webStorage));
      expect(service.httpAuthCredentials, same(httpAuthCredentials));
    });
  });
}

class _FakeCookieStorage implements CookieStorage {
  @override
  Future<void> deleteAllCookies() async {}

  @override
  Future<void> deleteCookie({
    required WebUri url,
    required String name,
  }) async {}

  @override
  Future<void> deleteCookies({required WebUri url}) async {}

  @override
  Future<Cookie?> getCookie({
    required WebUri url,
    required String name,
  }) async {
    return null;
  }

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) async {
    return <Cookie>[];
  }

  @override
  Future<void> setCookie(CookieSetRequest request) async {}
}

class _FakePlatformWebStorage implements BrowserWebStorage {
  @override
  Future<void> deleteOrigin({required String origin}) async {}

  @override
  Future<List<WebsiteDataRecord>> fetchDataRecords({
    required Set<WebsiteDataType> dataTypes,
  }) async {
    return <WebsiteDataRecord>[];
  }

  @override
  Future<int> getQuotaForOrigin({required String origin}) async {
    return 0;
  }

  @override
  Future<int> getUsageForOrigin({required String origin}) async {
    return 0;
  }

  @override
  Future<void> removeDataFor({
    required Set<WebsiteDataType> dataTypes,
    required List<WebsiteDataRecord> dataRecords,
  }) async {}

  @override
  Future<void> removeDataModifiedSince({
    required Set<WebsiteDataType> dataTypes,
    required DateTime date,
  }) async {}
}

class _FakeHttpAuthCredentials implements HttpAuthCredentials {
  @override
  Future<void> clearAllAuthCredentials() async {}

  @override
  Future<List<URLProtectionSpaceHttpAuthCredentials>>
      getAllAuthCredentials() async {
    return <URLProtectionSpaceHttpAuthCredentials>[];
  }

  @override
  Future<void> removeHttpAuthCredential({
    required URLProtectionSpace protectionSpace,
    required URLCredential credential,
  }) async {}
}
