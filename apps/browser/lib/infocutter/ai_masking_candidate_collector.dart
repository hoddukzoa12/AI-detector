import 'dart:convert';

import 'ai_masking_service.dart';

const String aiMaskingCandidateCollectorScript = r'''
(() => {
  function esc(value) {
    return String(value || '').replace(/([!"#$%&'()*+,./:;<=>?@[\]^`{|}~])/g, '\\$1');
  }
  function selectorFor(element) {
    if (element.id) {
      var byId = '#' + esc(element.id);
      try {
        if (document.querySelectorAll(byId).length === 1) return byId;
      } catch (_) {}
    }
    var parts = [];
    var current = element;
    while (current && current.nodeType === 1 && current !== document.body && parts.length < 5) {
      var part = current.tagName.toLowerCase();
      if (current.classList && current.classList.length) {
        part += '.' + Array.from(current.classList).slice(0, 2).map(esc).join('.');
      }
      var sibling = current;
      var index = 1;
      while ((sibling = sibling.previousElementSibling)) {
        if (sibling.tagName === current.tagName) index++;
      }
      part += ':nth-of-type(' + index + ')';
      parts.unshift(part);
      current = current.parentElement;
    }
    return parts.join(' > ');
  }
  function visible(element) {
    var rect = element.getBoundingClientRect();
    var style = window.getComputedStyle(element);
    return rect.width >= 80 && rect.height >= 40 &&
      style.display !== 'none' && style.visibility !== 'hidden' &&
      Number(style.opacity || 1) > 0.05;
  }
  function useful(element) {
    var tag = element.tagName.toLowerCase();
    var identity = [
      element.id || '',
      element.className || '',
      element.getAttribute('role') || '',
      element.getAttribute('aria-label') || ''
    ].join(' ').toLowerCase();
    return ['aside', 'article', 'section', 'nav', 'header', 'footer', 'li'].indexOf(tag) >= 0 ||
      /(ad|ads|advert|sponsor|promo|banner|popup|modal|overlay|recommend)/.test(identity);
  }
  var candidates = [];
  var seen = {};
  var nodes = Array.from(document.body ? document.body.querySelectorAll('*') : []);
  for (var i = 0; i < nodes.length && candidates.length < 80; i++) {
    var element = nodes[i];
    if (!useful(element) || !visible(element)) continue;
    var selector = selectorFor(element);
    if (!selector || seen[selector]) continue;
    seen[selector] = true;
    var rect = element.getBoundingClientRect();
    candidates.push({
      selector: selector,
      tag: element.tagName.toLowerCase(),
      id: element.id || '',
      className: String(element.className || '').slice(0, 160),
      role: element.getAttribute('role') || '',
      textLength: String(element.innerText || '').trim().length,
      width: Math.round(rect.width),
      height: Math.round(rect.height)
    });
  }
  return JSON.stringify(candidates);
})()
''';

List<AiPageCandidate> parseAiPageCandidates(Object? raw) {
  final decoded = raw is String ? _tryJsonDecode(raw) : raw;
  if (decoded is! List) return const [];
  return decoded
      .map(AiPageCandidate.tryParse)
      .whereType<AiPageCandidate>()
      .toList();
}

Object? _tryJsonDecode(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}
