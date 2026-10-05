import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/services/app_runtime.dart';
import 'package:infocutter_app/util.dart';

class DeveloperStorageService {
  const DeveloperStorageService({
    required this.cookies,
    required this.webStorage,
    required this.httpAuthCredentials,
  });

  factory DeveloperStorageService.fromRuntime(AppRuntime runtime) {
    final isWindows = Util.isWindows();
    return DeveloperStorageService(
      cookies: InAppWebViewCookieStorage(
        CookieManager.instance(
          webViewEnvironment: runtime.webViewEnvironment,
        ),
      ),
      webStorage: isWindows
          ? null
          : InAppWebViewPlatformWebStorage(WebStorageManager.instance()),
      httpAuthCredentials: isWindows
          ? null
          : InAppWebViewHttpAuthCredentials(
              HttpAuthCredentialDatabase.instance(),
            ),
    );
  }

  final CookieStorage cookies;
  final BrowserWebStorage? webStorage;
  final HttpAuthCredentials? httpAuthCredentials;
}

class CookieSetRequest {
  const CookieSetRequest({
    required this.url,
    required this.name,
    required this.value,
    this.domain,
    this.path = '/',
    this.expiresDate,
    this.isSecure,
  });

  final WebUri url;
  final String name;
  final String value;
  final String? domain;
  final String path;
  final int? expiresDate;
  final bool? isSecure;
}

abstract class CookieStorage {
  Future<List<Cookie>> getCookies({required WebUri url});

  Future<Cookie?> getCookie({
    required WebUri url,
    required String name,
  });

  Future<void> setCookie(CookieSetRequest request);

  Future<void> deleteCookie({
    required WebUri url,
    required String name,
  });

  Future<void> deleteCookies({required WebUri url});

  Future<void> deleteAllCookies();
}

class InAppWebViewCookieStorage implements CookieStorage {
  const InAppWebViewCookieStorage(this._cookieManager);

  final CookieManager _cookieManager;

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) {
    return _cookieManager.getCookies(url: url);
  }

  @override
  Future<Cookie?> getCookie({
    required WebUri url,
    required String name,
  }) {
    return _cookieManager.getCookie(url: url, name: name);
  }

  @override
  Future<void> setCookie(CookieSetRequest request) async {
    await _cookieManager.setCookie(
      url: request.url,
      name: request.name,
      value: request.value,
      domain: request.domain,
      path: request.path,
      expiresDate: request.expiresDate,
      isSecure: request.isSecure,
    );
  }

  @override
  Future<void> deleteCookie({
    required WebUri url,
    required String name,
  }) async {
    await _cookieManager.deleteCookie(url: url, name: name);
  }

  @override
  Future<void> deleteCookies({required WebUri url}) async {
    await _cookieManager.deleteCookies(url: url);
  }

  @override
  Future<void> deleteAllCookies() async {
    await _cookieManager.deleteAllCookies();
  }
}

abstract class BrowserWebStorage {
  Future<int> getQuotaForOrigin({required String origin});

  Future<int> getUsageForOrigin({required String origin});

  Future<void> deleteOrigin({required String origin});

  Future<List<WebsiteDataRecord>> fetchDataRecords({
    required Set<WebsiteDataType> dataTypes,
  });

  Future<void> removeDataFor({
    required Set<WebsiteDataType> dataTypes,
    required List<WebsiteDataRecord> dataRecords,
  });

  Future<void> removeDataModifiedSince({
    required Set<WebsiteDataType> dataTypes,
    required DateTime date,
  });
}

class InAppWebViewPlatformWebStorage implements BrowserWebStorage {
  const InAppWebViewPlatformWebStorage(this._webStorageManager);

  final WebStorageManager _webStorageManager;

  @override
  Future<int> getQuotaForOrigin({required String origin}) {
    return _webStorageManager.getQuotaForOrigin(origin: origin);
  }

  @override
  Future<int> getUsageForOrigin({required String origin}) {
    return _webStorageManager.getUsageForOrigin(origin: origin);
  }

  @override
  Future<void> deleteOrigin({required String origin}) {
    return _webStorageManager.deleteOrigin(origin: origin);
  }

  @override
  Future<List<WebsiteDataRecord>> fetchDataRecords({
    required Set<WebsiteDataType> dataTypes,
  }) {
    return _webStorageManager.fetchDataRecords(dataTypes: dataTypes);
  }

  @override
  Future<void> removeDataFor({
    required Set<WebsiteDataType> dataTypes,
    required List<WebsiteDataRecord> dataRecords,
  }) {
    return _webStorageManager.removeDataFor(
      dataTypes: dataTypes,
      dataRecords: dataRecords,
    );
  }

  @override
  Future<void> removeDataModifiedSince({
    required Set<WebsiteDataType> dataTypes,
    required DateTime date,
  }) {
    return _webStorageManager.removeDataModifiedSince(
      dataTypes: dataTypes,
      date: date,
    );
  }
}

abstract class HttpAuthCredentials {
  Future<List<URLProtectionSpaceHttpAuthCredentials>> getAllAuthCredentials();

  Future<void> removeHttpAuthCredential({
    required URLProtectionSpace protectionSpace,
    required URLCredential credential,
  });

  Future<void> clearAllAuthCredentials();
}

class InAppWebViewHttpAuthCredentials implements HttpAuthCredentials {
  const InAppWebViewHttpAuthCredentials(this._database);

  final HttpAuthCredentialDatabase _database;

  @override
  Future<List<URLProtectionSpaceHttpAuthCredentials>> getAllAuthCredentials() {
    return _database.getAllAuthCredentials();
  }

  @override
  Future<void> removeHttpAuthCredential({
    required URLProtectionSpace protectionSpace,
    required URLCredential credential,
  }) {
    return _database.removeHttpAuthCredential(
      protectionSpace: protectionSpace,
      credential: credential,
    );
  }

  @override
  Future<void> clearAllAuthCredentials() {
    return _database.clearAllAuthCredentials();
  }
}
