import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 깨진 사이트에서 hide/filter/watch 를 호스트 단위로 잠깐 끈다 (#20).
///
/// 프로필을 영구 비활성하지 않는다 — 호스트 집합만 prefs 에 둔다.
/// WebView 어댑터가 Provider 없이도 읽도록 싱글톤 `instance` 를 쓴다.
class SiteProtectionBypass extends ChangeNotifier {
  SiteProtectionBypass({SharedPreferences? prefs}) : _prefs = prefs;

  static final SiteProtectionBypass instance = SiteProtectionBypass();

  static const _prefsKey = 'infocutter.site_protection_bypass_hosts';

  SharedPreferences? _prefs;
  final Set<String> _hosts = <String>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Set<String> get hosts => Set.unmodifiable(_hosts);

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _prefs ??= await SharedPreferences.getInstance();
    final list = _prefs!.getStringList(_prefsKey) ?? const <String>[];
    _hosts
      ..clear()
      ..addAll(list.map(_normalizeHost).where((h) => h.isNotEmpty));
    _loaded = true;
  }

  bool isBypassed(Uri? url) {
    final host = _normalizeHost(url?.host);
    if (host.isEmpty) {
      return false;
    }
    return _hosts.contains(host);
  }

  Future<void> setBypassed(Uri? url, {required bool bypassed}) async {
    await ensureLoaded();
    final host = _normalizeHost(url?.host);
    if (host.isEmpty) {
      return;
    }
    final changed = bypassed ? _hosts.add(host) : _hosts.remove(host);
    if (!changed && bypassed == _hosts.contains(host)) {
      // add returns false if already present; still persist if first load race
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    if (_hosts.isEmpty) {
      return;
    }
    _hosts.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(_prefsKey, _hosts.toList()..sort());
  }

  static String _normalizeHost(String? host) {
    final h = (host ?? '').trim().toLowerCase();
    if (h.startsWith('www.')) {
      return h.substring(4);
    }
    return h;
  }
}
