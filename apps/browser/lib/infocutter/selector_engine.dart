// WebView 에 주입할 Infocutter JS user script 들.
//
// 실제 JS 본문은 `assets/js/*.js` 에 있고, 이 파일이 재수출하는 const 는
// `tool/generate_user_scripts.dart` 가 그것을 구워 만든다. JS 를 고칠 때는
// assets/js 를 고치고 생성기를 다시 돌린다 — .g.dart 를 직접 고치지 않는다.
//
// - infocutter_runtime.js — DOM 에 marker attribute 와 style node 를 심고
//   MutationObserver 로 동적 DOM 을 다시 렌더링한다.
// - picker.js — 요소 선택 오버레이. 결과는 `infocutter.pickerResult` 핸들러로.
// - keyword_capture.js — 텍스트 선택을 `infocutter.keywordResult` 로 전달.
//   picker 와 달리 preventDefault 를 부르지 않아 페이지 동작에 영향이 없다.
export 'generated/user_scripts.g.dart'
    show
        infocutterRuntimeUserScriptSource,
        keywordCaptureUserScriptSource,
        lazyImagePromoteUserScriptSource,
        pickerUserScriptSource;

/// JS picker 결과를 Dart 로 전달할 때의 payload.
class PickerCandidate {
  const PickerCandidate({
    required this.index,
    required this.selector,
    required this.selectorCandidates,
    required this.tag,
    required this.id,
    required this.classes,
    required this.label,
    required this.relationship,
    required this.kind,
    required this.matchCount,
    required this.applyAllowed,
    required this.qualityLabel,
  });

  final int index;
  final String selector;
  final List<String> selectorCandidates;
  final String tag;
  final String? id;
  final List<String> classes;
  final String label;
  final String relationship;
  final String kind;
  final int matchCount;
  final bool applyAllowed;
  final String qualityLabel;

  static PickerCandidate? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final selector = _stringValue(raw['selector']);
    if (selector == null || selector.isEmpty) return null;
    return PickerCandidate(
      index: _intValue(raw['index']) ?? 0,
      selector: selector,
      selectorCandidates: _stringListValue(raw['selectorCandidates']),
      tag: _stringValue(raw['tag']) ?? '',
      id: _nonEmptyStringValue(raw['id']),
      classes: _stringListValue(raw['classes']),
      label: _stringValue(raw['label']) ?? selector,
      relationship: _stringValue(raw['relationship']) ?? '',
      kind: _stringValue(raw['kind']) ?? '',
      matchCount: _intValue(raw['matchCount']) ?? 0,
      applyAllowed: raw['applyAllowed'] == true,
      qualityLabel: _stringValue(raw['qualityLabel']) ?? '',
    );
  }
}

class PickerDepthTarget {
  const PickerDepthTarget({
    required this.index,
    required this.label,
    required this.elementLabel,
    required this.selector,
    required this.selectorCandidates,
    required this.tag,
    required this.id,
    required this.classes,
    required this.matchCount,
    required this.applyAllowed,
    required this.qualityLabel,
  });

  final int index;
  final String label;
  final String elementLabel;
  final String selector;
  final List<String> selectorCandidates;
  final String tag;
  final String? id;
  final List<String> classes;
  final int matchCount;
  final bool applyAllowed;
  final String qualityLabel;

  static PickerDepthTarget? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final selector = _stringValue(raw['selector']);
    if (selector == null || selector.isEmpty) return null;
    return PickerDepthTarget(
      index: _intValue(raw['index']) ?? 0,
      label: _stringValue(raw['label']) ?? '',
      elementLabel: _stringValue(raw['elementLabel']) ?? selector,
      selector: selector,
      selectorCandidates: _stringListValue(raw['selectorCandidates']),
      tag: _stringValue(raw['tag']) ?? '',
      id: _nonEmptyStringValue(raw['id']),
      classes: _stringListValue(raw['classes']),
      matchCount: _intValue(raw['matchCount']) ?? 0,
      applyAllowed: raw['applyAllowed'] == true,
      qualityLabel: _stringValue(raw['qualityLabel']) ?? '',
    );
  }
}

class PickerResult {
  const PickerResult({
    required this.selector,
    required this.tag,
    required this.id,
    required this.classes,
    required this.matchCount,
    required this.alternatives,
    this.frameScope,
    this.candidates = const [],
    this.selectedCandidateIndex = 0,
    this.depthTargets = const [],
    this.selectedDepthIndex = 0,
    this.selectorCandidates = const [],
  });

  final String selector;
  final String tag;
  final String? id;
  final List<String> classes;
  final int matchCount;
  final List<String> alternatives;
  final String? frameScope;
  final List<PickerCandidate> candidates;
  final int selectedCandidateIndex;
  final List<PickerDepthTarget> depthTargets;
  final int selectedDepthIndex;
  final List<String> selectorCandidates;

  PickerCandidate? get selectedCandidate {
    if (selectedCandidateIndex < 0 ||
        selectedCandidateIndex >= candidates.length) {
      return candidates.isEmpty ? null : candidates.first;
    }
    return candidates[selectedCandidateIndex];
  }

  PickerDepthTarget? get selectedDepthTarget {
    if (selectedDepthIndex < 0 || selectedDepthIndex >= depthTargets.length) {
      return depthTargets.isEmpty ? null : depthTargets.first;
    }
    return depthTargets[selectedDepthIndex];
  }

  /// JS 측에서 보낸 args 배열 (selector, info, alternatives) 을 파싱.
  /// 잘못된 모양이면 null 반환 (throw 안 함).
  static PickerResult? tryParse(List<Object?> args) {
    if (args.isEmpty) return null;
    final selector = args[0];
    if (selector is! String || selector.isEmpty) return null;
    final info = _PickerInfo.from(args.length > 1 ? args[1] : null);
    return PickerResult(
      selector: selector,
      tag: info.tag,
      id: info.id,
      classes: info.classes,
      matchCount: info.matchCount,
      alternatives: _stringListValue(args.length > 2 ? args[2] : null),
      frameScope: info.frameScope,
      candidates: info.candidates,
      selectedCandidateIndex: info.selectedCandidateIndex,
      depthTargets: info.depthTargets,
      selectedDepthIndex: info.selectedDepthIndex,
      selectorCandidates: info.selectorCandidates,
    );
  }
}

class _PickerInfo {
  const _PickerInfo({
    required this.tag,
    required this.id,
    required this.classes,
    required this.matchCount,
    required this.frameScope,
    required this.candidates,
    required this.selectedCandidateIndex,
    required this.depthTargets,
    required this.selectedDepthIndex,
    required this.selectorCandidates,
  });

  final String tag;
  final String? id;
  final List<String> classes;
  final int matchCount;
  final String? frameScope;
  final List<PickerCandidate> candidates;
  final int selectedCandidateIndex;
  final List<PickerDepthTarget> depthTargets;
  final int selectedDepthIndex;
  final List<String> selectorCandidates;

  static _PickerInfo from(Object? raw) {
    if (raw is! Map) return _empty;
    return _PickerInfo(
      tag: _stringValue(raw['tag']) ?? '',
      id: _nonEmptyStringValue(raw['id']),
      classes: _stringListValue(raw['classes']),
      matchCount: _intValue(raw['matchCount']) ?? 0,
      frameScope: _nonEmptyStringValue(raw['frameScope']),
      candidates: _parseCandidates(raw['candidates']),
      selectedCandidateIndex: _intValue(raw['selectedCandidateIndex']) ?? 0,
      depthTargets: _parseDepthTargets(raw['depthTargets']),
      selectedDepthIndex: _intValue(raw['selectedDepthIndex']) ?? 0,
      selectorCandidates: _stringListValue(raw['selectorCandidates']),
    );
  }

  static const _empty = _PickerInfo(
    tag: '',
    id: null,
    classes: [],
    matchCount: 0,
    frameScope: null,
    candidates: [],
    selectedCandidateIndex: 0,
    depthTargets: [],
    selectedDepthIndex: 0,
    selectorCandidates: [],
  );
}

String? _stringValue(Object? value) => value is String ? value : null;

String? _nonEmptyStringValue(Object? value) {
  final text = _stringValue(value);
  return text == null || text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

List<String> _stringListValue(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().where((item) => item.isNotEmpty).toList();
}

List<PickerCandidate> _parseCandidates(Object? value) {
  if (value is! List) return const [];
  return value
      .map(PickerCandidate.tryParse)
      .whereType<PickerCandidate>()
      .toList();
}

List<PickerDepthTarget> _parseDepthTargets(Object? value) {
  if (value is! List) return const [];
  return value
      .map(PickerDepthTarget.tryParse)
      .whereType<PickerDepthTarget>()
      .toList();
}
