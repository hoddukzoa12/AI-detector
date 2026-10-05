// GENERATED — 직접 고치지 마라.
// 원본은 assets/js/*.js 다. 고친 뒤 아래를 실행한다:
//   fvm dart run tool/generate_user_scripts.dart

/// assets/js/infocutter_runtime.js
const String infocutterRuntimeUserScriptSource = r'''
(function () {
  if (window.__infocutterRuntime) return;

  var HIDDEN_ATTR = 'data-infocutter-hidden';
  var STYLE_ID = '__infocutter_runtime_style';
  var state = {
    globalEnabled: true,
    profileEnabled: false,
    rules: []
  };
  var peek = false;
  var renderTimer = null;
  var observer = null;

  function currentFrameScope() {
    if (window.top === window) return null;
    return window.location.origin + window.location.pathname;
  }

  function ensureStyle() {
    var existing = document.getElementById(STYLE_ID);
    if (existing) return existing;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = '[' + HIDDEN_ATTR + '] { display: none !important; }';
    (document.head || document.documentElement).appendChild(style);
    return style;
  }

  function clearMarkers() {
    document.querySelectorAll('[' + HIDDEN_ATTR + ']').forEach(function (element) {
      element.removeAttribute(HIDDEN_ATTR);
    });
  }

  function matchingRules(mode) {
    var frameScope = currentFrameScope();
    var rules = Array.isArray(state.rules) ? state.rules : [];
    return rules.filter(function (rule) {
      return rule &&
        rule.mode === mode &&
        typeof rule.selector === 'string' &&
        rule.selector.trim().length > 0 &&
        (rule.frameScope || null) === frameScope;
    });
  }

  function queryAllSafe(selector) {
    try {
      return Array.prototype.slice.call(document.querySelectorAll(selector));
    } catch (e) {
      return [];
    }
  }

  function collectTargets(rules) {
    var targets = [];
    var seen = new Set();
    rules.forEach(function (rule) {
      queryAllSafe(rule.selector).forEach(function (element) {
        if (!seen.has(element)) {
          seen.add(element);
          targets.push(element);
        }
      });
    });
    return targets;
  }

  function hasExceptionTarget(target, exceptions) {
    for (var i = 0; i < exceptions.length; i++) {
      var exception = exceptions[i];
      if (
        target === exception ||
        target.contains(exception) ||
        exception.contains(target)
      ) {
        return true;
      }
    }
    return false;
  }

  function renderNow() {
    ensureStyle();
    clearMarkers();

    if (!state.globalEnabled || !state.profileEnabled || peek) {
      return;
    }

    var hideTargets = collectTargets(matchingRules('hide'));
    if (hideTargets.length === 0) {
      return;
    }
    var exceptionTargets = collectTargets(matchingRules('unhide'));

    hideTargets.forEach(function (element) {
      if (!hasExceptionTarget(element, exceptionTargets)) {
        element.setAttribute(HIDDEN_ATTR, 'true');
      }
    });
  }

  function scheduleRender() {
    if (renderTimer !== null) {
      window.clearTimeout(renderTimer);
    }
    renderTimer = window.setTimeout(function () {
      renderTimer = null;
      renderNow();
    }, 120);
  }

  function ensureObserver() {
    if (observer) return;
    observer = new MutationObserver(function () {
      scheduleRender();
    });
    observer.observe(document.documentElement, {
      attributes: true,
      characterData: true,
      childList: true,
      subtree: true
    });
  }

  window.__infocutterRuntime = {
    apply: function (nextState) {
      state = nextState || state;
      ensureObserver();
      renderNow();
    },
    render: function () {
      renderNow();
    },
    setPeek: function (enabled) {
      peek = !!enabled;
      renderNow();
    },
    countHidden: function () {
      return document.querySelectorAll('[' + HIDDEN_ATTR + ']').length;
    },
    countMatches: function (selector) {
      return queryAllSafe(selector).length;
    }
  };
  ensureObserver();
})();
''';

/// assets/js/picker.js
const String pickerUserScriptSource = r'''
(function () {
  if (window.__infocutterPicker) return;

  var active = false;
  var overlay = null;
  var hoverCandidates = [];
  var hoverIndex = 0;
  var lastPoint = null;

  // Persistent numbered-highlight layer for the multi-select session. Separate
  // from the hover `overlay` (which is wiped on every mousemove), so committed
  // selections stay visible while the human keeps picking. Driven from Dart via
  // applySessionHighlights(); the session itself is owned on the Dart side.
  var sessionLayer = null;
  var sessionEntries = [];
  var SESSION_COLORS = [
    { bg: 'rgba(37, 99, 235, 0.14)', border: 'rgba(37, 99, 235, 0.95)' },
    { bg: 'rgba(220, 38, 38, 0.14)', border: 'rgba(220, 38, 38, 0.95)' },
    { bg: 'rgba(22, 163, 74, 0.14)', border: 'rgba(22, 163, 74, 0.95)' },
    { bg: 'rgba(202, 138, 4, 0.14)', border: 'rgba(202, 138, 4, 0.95)' },
    { bg: 'rgba(147, 51, 234, 0.14)', border: 'rgba(147, 51, 234, 0.95)' }
  ];

  // This IIFE is a separate injected script from the runtime one, so it cannot
  // see that script's currentFrameScope(). Without this local copy,
  // emitCurrent() throws ReferenceError and NO pick is ever reported (breaks
  // both real clicks and programmatic picks).
  function currentFrameScope() {
    if (window.top === window) return null;
    return window.location.origin + window.location.pathname;
  }

  function isExtensionUiElement(el) {
    if (!el || el.nodeType !== 1) return false;
    var id = el.getAttribute('id') || '';
    return id.indexOf('infocutter-') === 0 || id.indexOf('__infocutter_') === 0;
  }

  function createRectBox(rect, background, border) {
    var box = document.createElement('div');
    box.style.position = 'fixed';
    box.style.left = rect.left + 'px';
    box.style.top = rect.top + 'px';
    box.style.width = rect.width + 'px';
    box.style.height = rect.height + 'px';
    box.style.pointerEvents = 'none';
    box.style.background = background;
    box.style.border = border;
    box.style.boxSizing = 'border-box';
    box.style.borderRadius = '2px';
    return box;
  }

  function rectsForElement(el) {
    if (!el || !el.getClientRects) return [];
    return Array.prototype.slice.call(el.getClientRects()).filter(function (rect) {
      return rect.width > 0 && rect.height > 0;
    }).slice(0, 8);
  }

  function setOverlayRects(el) {
    ensureOverlay();
    overlay.replaceChildren();
    rectsForElement(el).forEach(function (rect) {
      overlay.appendChild(createRectBox(
        rect,
        'rgba(217, 119, 6, 0.12)',
        '2px solid rgba(217, 119, 6, 0.95)'
      ));
    });
  }

  function hoverCurrentTarget() {
    return hoverCandidates[hoverIndex] || null;
  }

  function highlightCurrent() {
    var target = hoverCurrentTarget();
    if (target) setOverlayRects(target);
  }

  function ensureOverlay() {
    if (overlay && overlay.isConnected) return overlay;
    overlay = document.createElement('div');
    overlay.id = '__infocutter_picker_overlay';
    overlay.setAttribute('aria-hidden', 'true');
    overlay.style.position = 'fixed';
    overlay.style.inset = '0';
    overlay.style.zIndex = '2147483647';
    overlay.style.background = 'transparent';
    overlay.style.cursor = 'crosshair';
    overlay.style.pointerEvents = 'auto';
    overlay.style.touchAction = 'none';
    overlay.addEventListener('mousemove', handleMouseMove, true);
    overlay.addEventListener('mousedown', handlePointerStart, true);
    overlay.addEventListener('mouseup', handlePointerEnd, true);
    overlay.addEventListener('click', handleClick, true);
    overlay.addEventListener('dblclick', handleBlockedEvent, true);
    overlay.addEventListener('auxclick', handleBlockedEvent, true);
    overlay.addEventListener('contextmenu', handleBlockedEvent, true);
    (document.body || document.documentElement).appendChild(overlay);
    return overlay;
  }

  function removeOverlay() {
    if (overlay && overlay.parentNode) {
      overlay.parentNode.removeChild(overlay);
    }
    overlay = null;
  }

  function ensureSessionLayer() {
    if (sessionLayer && sessionLayer.isConnected) return sessionLayer;
    sessionLayer = document.createElement('div');
    sessionLayer.id = '__infocutter_picker_session';
    sessionLayer.setAttribute('aria-hidden', 'true');
    sessionLayer.style.position = 'fixed';
    sessionLayer.style.inset = '0';
    // One below the hover overlay so the crosshair/hover box always wins.
    sessionLayer.style.zIndex = '2147483646';
    sessionLayer.style.pointerEvents = 'none';
    sessionLayer.style.background = 'transparent';
    (document.body || document.documentElement).appendChild(sessionLayer);
    return sessionLayer;
  }

  function removeSessionLayer() {
    if (sessionLayer && sessionLayer.parentNode) {
      sessionLayer.parentNode.removeChild(sessionLayer);
    }
    sessionLayer = null;
  }

  function makeSessionBadge(number, rect, color) {
    var badge = document.createElement('div');
    badge.textContent = String(number);
    badge.style.position = 'fixed';
    badge.style.left = Math.max(0, rect.left - 1) + 'px';
    badge.style.top = Math.max(0, rect.top - 1) + 'px';
    badge.style.minWidth = '18px';
    badge.style.height = '18px';
    badge.style.padding = '0 4px';
    badge.style.borderRadius = '9px';
    badge.style.background = color.border;
    badge.style.color = '#ffffff';
    badge.style.font = '700 11px/18px -apple-system, system-ui, sans-serif';
    badge.style.textAlign = 'center';
    badge.style.pointerEvents = 'none';
    badge.style.boxSizing = 'border-box';
    badge.style.boxShadow = '0 1px 3px rgba(0, 0, 0, 0.35)';
    return badge;
  }

  function renderSessionHighlights() {
    if (!sessionLayer || !sessionLayer.isConnected) return;
    sessionLayer.replaceChildren();
    sessionEntries.forEach(function (entry) {
      var color = SESSION_COLORS[(entry.index - 1) % SESSION_COLORS.length] || SESSION_COLORS[0];
      var els;
      try { els = document.querySelectorAll(entry.selector); } catch (e) { els = []; }
      var labelled = false;
      Array.prototype.forEach.call(els, function (el) {
        if (isExtensionUiElement(el)) return;
        rectsForElement(el).forEach(function (rect) {
          sessionLayer.appendChild(createRectBox(rect, color.bg, '2px solid ' + color.border));
        });
        if (!labelled) {
          var anchor = (el.getClientRects && el.getClientRects()[0]) || null;
          if (anchor) {
            sessionLayer.appendChild(makeSessionBadge(entry.index, anchor, color));
            labelled = true;
          }
        }
      });
    });
  }

  function swallowEvent(e) {
    if (!active) return false;
    e.preventDefault();
    e.stopPropagation();
    if (e.stopImmediatePropagation) {
      e.stopImmediatePropagation();
    }
    return true;
  }

  function eventPoint(e) {
    if (typeof e.clientX === 'number' && typeof e.clientY === 'number') {
      return { x: e.clientX, y: e.clientY };
    }
    var touch = null;
    if (e.touches && e.touches[0]) {
      touch = e.touches[0];
    } else if (e.changedTouches && e.changedTouches[0]) {
      touch = e.changedTouches[0];
    }
    if (!touch) return null;
    return { x: touch.clientX, y: touch.clientY };
  }

  function withOverlayTransparent(fn) {
    var blocker = overlay;
    var previousPointerEvents = blocker ? blocker.style.pointerEvents : null;
    if (blocker) blocker.style.pointerEvents = 'none';
    try {
      return fn();
    } finally {
      if (blocker) blocker.style.pointerEvents = previousPointerEvents || 'auto';
    }
  }

  function elementsAtPoint(x, y) {
    return withOverlayTransparent(function () {
      var raw = document.elementsFromPoint
        ? document.elementsFromPoint(x, y)
        : [document.elementFromPoint(x, y)];
      return raw.filter(function (el) {
        return el && el.nodeType === 1 && !isExtensionUiElement(el);
      });
    });
  }

  function updateHoverFromEvent(e) {
    var point = eventPoint(e);
    if (!point) return;
    lastPoint = point;
    var targets = elementsAtPoint(point.x, point.y);
    hoverCandidates = targets.slice().sort(function (left, right) {
      var leftIndex = targets.indexOf(left);
      var rightIndex = targets.indexOf(right);
      return candidateTargetScore(right, rightIndex) - candidateTargetScore(left, leftIndex);
    });
    hoverIndex = 0;
    highlightCurrent();
  }

  function stableClasses(el) {
    var out = [];
    var list = el.classList;
    for (var i = 0; i < list.length && out.length < 3; i++) {
      var c = list[i];
      if (/^[a-z][a-z0-9_-]{1,40}$/i.test(c)) {
        var digits = (c.match(/\d/g) || []).length;
        if (digits <= 3) out.push(c);
      }
    }
    return out;
  }

  function maybeStableClassName(className) {
    if (!/^[a-z][a-z0-9_-]{1,40}$/i.test(className)) return false;
    var digits = (className.match(/\d/g) || []).length;
    return digits <= 3;
  }

  function nthOfType(el) {
    var parent = el.parentElement;
    if (!parent) return el.localName;
    var n = 0;
    for (var c = parent.firstElementChild; c; c = c.nextElementSibling) {
      if (c.localName !== el.localName) continue;
      n++;
      if (c === el) {
        break;
      }
    }
    return el.localName + ':nth-of-type(' + n + ')';
  }

  function escapeAttr(v) {
    return v.replace(/"/g, '\\"');
  }

  function attrSelector(el) {
    var attrs = ['data-testid', 'data-test', 'data-qa', 'aria-label', 'title', 'alt'];
    for (var i = 0; i < attrs.length; i++) {
      var v = el.getAttribute(attrs[i]);
      if (v && v.length <= 80) {
        return el.localName + '[' + attrs[i] + '="' + escapeAttr(v) + '"]';
      }
    }
    return null;
  }

  function isUnique(sel) {
    try {
      return document.querySelectorAll(sel).length === 1;
    } catch (e) {
      return false;
    }
  }

  function matchCountForSelector(sel) {
    try {
      return document.querySelectorAll(sel).length;
    } catch (e) {
      return -1;
    }
  }

  function selectorAssessment(sel) {
    var count = matchCountForSelector(sel);
    if (count < 0) {
      return {
        applyAllowed: false,
        label: '잘못된 선택자',
        matchCount: -1
      };
    }
    if (count === 0) {
      return {
        applyAllowed: false,
        label: '대상 없음',
        matchCount: 0
      };
    }
    if (count === 1) {
      return {
        applyAllowed: true,
        label: '정확히 1개 대상',
        matchCount: 1
      };
    }
    return {
      applyAllowed: true,
      label: '같은 구조 여러 대상',
      matchCount: count
    };
  }

  function isBareTagSelector(sel) {
    return /^[a-z][a-z0-9-]*$/i.test(sel);
  }

  function selectorSpecificityScore(sel) {
    var score = 0;
    score += (sel.match(/#/g) || []).length * 1000;
    score += (sel.match(/[.[\]:]/g) || []).length * 100;
    score += sel.split('>').length * 10;
    score += (sel.match(/:nth-of-type/g) || []).length;
    if (isBareTagSelector(sel)) score -= 600;
    return score;
  }

  function selectorCandidateScoreForHiding(sel) {
    var count = matchCountForSelector(sel);
    if (count <= 0) return -10000;
    var score = 0;
    if (count === 1) score += 24;
    if (count > 1 && count <= 24) score += 72;
    if (count > 24 && count <= 80) score += 16;
    if (/[a-z][a-z0-9-]*\.[a-z0-9_-]+/i.test(sel)) score += 34;
    if (/\[(data-testid|data-test|data-qa|aria-label|title|alt)=/.test(sel)) score += 24;
    if (sel.indexOf('#') >= 0) score -= 18;
    score -= (sel.match(/:nth-of-type/g) || []).length * 28;
    score -= Math.max(0, sel.split('>').length - 1) * 8;
    if (isBareTagSelector(sel)) score -= 220;
    score -= Math.min(sel.length / 10, 12);
    return score;
  }

  function sortSelectorsForHiding(selectors) {
    return uniqueStrings(selectors).sort(function (left, right) {
      var diff = selectorCandidateScoreForHiding(right) - selectorCandidateScoreForHiding(left);
      if (diff !== 0) return diff;
      return selectorSpecificityScore(right) - selectorSpecificityScore(left);
    });
  }

  function simpleCandidates(el, allowNth) {
    if (!el || el.nodeType !== 1) return [];
    var out = [];
    if (el.id && /^[a-zA-Z][\w-]*$/.test(el.id)) {
      out.push('#' + el.id);
    }
    var attr = attrSelector(el);
    if (attr) out.push(attr);

    var classes = stableClasses(el);
    if (classes.length) {
      out.push(el.localName + '.' + classes[0]);
      if (classes.length > 1) {
        out.push(el.localName + '.' + classes.slice(0, 2).join('.'));
      }
      out.push(el.localName + '.' + classes.map(function (c) { return c; }).join('.'));
    }
    if (allowNth) out.push(nthOfType(el));
    out.push(el.localName);
    return uniqueStrings(out);
  }

  function uniqueStrings(values) {
    var seen = {};
    var out = [];
    values.forEach(function (value) {
      if (typeof value === 'string' && value.trim() && !seen[value]) {
        seen[value] = true;
        out.push(value);
      }
    });
    return out;
  }

  function preferredSegmentSelector(el) {
    var candidates = simpleCandidates(el, true).sort(function (left, right) {
      return selectorSpecificityScore(right) - selectorSpecificityScore(left);
    });
    return candidates[0] || el.localName;
  }

  function pathSelector(ancestor, target) {
    var parts = [];
    var node = target;
    while (node && node !== ancestor) {
      parts.unshift(preferredSegmentSelector(node));
      node = node.parentElement;
    }

    var anchor = simpleCandidates(ancestor, true)
      .filter(function (candidate) { return !isBareTagSelector(candidate); })
      .find(function (candidate) { return isUnique(candidate); }) || nthOfType(ancestor);
    return [anchor].concat(parts).join(' > ');
  }

  function buildSelectorCandidates(el) {
    var out = [];
    var seen = {};
    function push(sel) {
      if (!sel || seen[sel]) return;
      seen[sel] = true;
      out.push(sel);
    }

    simpleCandidates(el, true)
      .sort(function (left, right) { return selectorSpecificityScore(right) - selectorSpecificityScore(left); })
      .forEach(function (candidate) {
        if (isUnique(candidate)) push(candidate);
      });

    var ancestor = el.parentElement;
    var depth = 0;
    while (ancestor && ancestor !== document.body && ancestor !== document.documentElement && depth < 4) {
      var path = pathSelector(ancestor, el);
      push(path);
      if (isUnique(path)) break;
      ancestor = ancestor.parentElement;
      depth++;
    }

    simpleCandidates(el, false)
      .filter(function (candidate) { return !isBareTagSelector(candidate); })
      .sort(function (left, right) { return selectorSpecificityScore(right) - selectorSpecificityScore(left); })
      .forEach(function (candidate) {
        var count = matchCountForSelector(candidate);
        if (count > 1 && count <= 24) push(candidate);
      });

    if (out.length === 0) {
      push(nthOfType(el));
    }
    return sortSelectorsForHiding(out);
  }

  function generateSelector(el) {
    return buildSelectorCandidates(el)[0] || '';
  }

  function buildDepthChain(el) {
    var chain = [];
    var current = el;
    var depth = 0;
    while (current && current !== document.body && current !== document.documentElement && depth < 5) {
      chain.push(current);
      current = current.parentElement;
      depth++;
    }
    return chain;
  }

  function elementShortLabel(el) {
    var id = el.getAttribute('id');
    if (id) return el.localName + '#' + id;
    for (var i = 0; i < el.classList.length; i++) {
      if (maybeStableClassName(el.classList[i])) {
        return el.localName + '.' + el.classList[i];
      }
    }
    return el.localName;
  }

  function depthLabel(index) {
    return index === 0 ? '현재 요소' : '부모 ' + index + '단계';
  }

  function candidateRelationshipLabel(candidate, currentTarget) {
    if (candidate === currentTarget) return '현재 타깃';
    if (candidate.contains(currentTarget)) return '부모 후보';
    if (currentTarget.contains(candidate)) return '자식 후보';
    return '대체 후보';
  }

  function candidateKindLabel(el) {
    if (el.matches('button, [role="button"]')) return '버튼';
    if (el.matches('a, [role="link"]')) return '링크';
    if (el.matches('input, textarea, select, option')) return '입력';
    if (el.matches('img, picture, svg, video, canvas')) return '미디어';
    if (el.children.length === 0) return '리프';
    return '컨테이너';
  }

  function candidateTargetScore(el, stackIndex) {
    var selector = generateSelector(el) || el.localName;
    var assessment = selectorAssessment(selector);
    var rect = el.getBoundingClientRect();
    var viewportArea = Math.max(1, window.innerWidth * window.innerHeight);
    var rectArea = Math.max(1, rect.width * rect.height);
    var areaRatio = rectArea / viewportArea;
    var areaScore = Math.min(rectArea / 500, 16);
    var stackBonus = Math.max(0, 28 - stackIndex * 6);
    var applyBonus = assessment.applyAllowed ? 50 : 0;
    var matchPenalty = assessment.matchCount < 0 ? 20 : Math.min(assessment.matchCount, 20);
    var selectorScore = Math.min(selectorSpecificityScore(selector), 80);
    var directInteractive = el.matches('button, a, input, textarea, select, option, label, [role="button"], [role="link"]');
    var interactivePenalty = directInteractive && el.children.length === 0 ? 28 : 0;
    var containerBonus = el.children.length > 0 ? 18 : 0;
    var tinyPenalty = rect.width < 24 || rect.height < 18 ? 8 : 0;
    var containerPenalty = areaRatio > 0.45 ? 80 : areaRatio > 0.25 ? 36 : areaRatio > 0.12 ? 14 : 0;
    var oversizedBlockPenalty = rect.width >= window.innerWidth * 0.8 && rect.height >= window.innerHeight * 0.22 ? 24 : 0;
    return applyBonus + selectorScore + areaScore + stackBonus + containerBonus - matchPenalty - tinyPenalty - containerPenalty - oversizedBlockPenalty - interactivePenalty;
  }

  function depthTargetScore(el, index) {
    var selector = generateSelector(el) || el.localName;
    var assessment = selectorAssessment(selector);
    var rect = el.getBoundingClientRect();
    var viewportArea = Math.max(1, window.innerWidth * window.innerHeight);
    var areaRatio = Math.max(1, rect.width * rect.height) / viewportArea;
    var score = 0;
    if (assessment.applyAllowed) score += 30;
    if (assessment.matchCount > 1 && assessment.matchCount <= 24) score += 36;
    if (el.children.length > 0) score += 30;
    if (el.matches('article, section, aside, nav, li, [role="article"], [role="listitem"]')) score += 24;
    if (/(card|item|article|post|ad|ads|sponsor|promo|banner|result|feed)/i.test(el.className || '')) score += 22;
    if (areaRatio >= 0.004 && areaRatio <= 0.18) score += 28;
    if (rect.width < 60 || rect.height < 32) score -= 42;
    if (areaRatio > 0.35) score -= 80;
    if (el.matches('a, button, input, textarea, select, option, [role="button"], [role="link"]') && el.children.length === 0) score -= 36;
    score -= index * 4;
    return score;
  }

  function chooseDefaultDepthIndex(chain) {
    var bestIndex = 0;
    var bestScore = -Infinity;
    for (var i = 0; i < chain.length; i++) {
      var score = depthTargetScore(chain[i], i);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  function candidatePayload(el, currentTarget, index) {
    var selectors = buildSelectorCandidates(el);
    var selector = selectors[0] || el.localName;
    var assessment = selectorAssessment(selector);
    return {
      index: index,
      selector: selector,
      selectorCandidates: selectors,
      tag: el.tagName,
      id: el.id || null,
      classes: Array.prototype.slice.call(el.classList),
      label: elementShortLabel(el),
      relationship: candidateRelationshipLabel(el, currentTarget),
      kind: candidateKindLabel(el),
      matchCount: assessment.matchCount,
      applyAllowed: assessment.applyAllowed,
      qualityLabel: assessment.label
    };
  }

  function depthPayload(el, index) {
    var selectors = buildSelectorCandidates(el);
    var selector = selectors[0] || el.localName;
    var assessment = selectorAssessment(selector);
    return {
      index: index,
      label: depthLabel(index),
      elementLabel: elementShortLabel(el),
      selector: selector,
      selectorCandidates: selectors,
      tag: el.tagName,
      id: el.id || null,
      classes: Array.prototype.slice.call(el.classList),
      matchCount: assessment.matchCount,
      applyAllowed: assessment.applyAllowed,
      qualityLabel: assessment.label
    };
  }

  function emitCurrent() {
    var current = hoverCurrentTarget();
    if (!current) return;
    var depthChain = buildDepthChain(current);
    var selectedDepthIndex = chooseDefaultDepthIndex(depthChain);
    var depthTargets = depthChain.map(depthPayload);
    var selectedDepth = depthTargets[selectedDepthIndex] || depthTargets[0] || depthPayload(current, 0);
    var candidates = hoverCandidates.map(function (candidate, index) {
      return candidatePayload(candidate, current, index);
    });
    var sel = selectedDepth.selector;
    var meta = {
      tag: current.tagName,
      id: current.id || null,
      classes: Array.prototype.slice.call(current.classList),
      frameScope: currentFrameScope(),
      matchCount: selectedDepth.matchCount,
      candidates: candidates,
      selectedCandidateIndex: hoverIndex,
      depthTargets: depthTargets,
      selectedDepthIndex: selectedDepth.index,
      selectorCandidates: selectedDepth.selectorCandidates
    };
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('infocutter.pickerResult', sel, meta, selectedDepth.selectorCandidates);
    }
  }

  function handleTouchStart(e) {
    if (!swallowEvent(e)) return;
    updateHoverFromEvent(e);
  }

  function handleTouchMove(e) {
    if (!swallowEvent(e)) return;
    updateHoverFromEvent(e);
  }

  function handleTouchEnd(e) {
    if (!swallowEvent(e)) return;
    updateHoverFromEvent(e);
    emitCurrent();
  }

  function handleMouseMove(e) {
    if (!swallowEvent(e)) return;
    updateHoverFromEvent(e);
  }

  function handlePointerStart(e) {
    if (!swallowEvent(e)) return;
    updateHoverFromEvent(e);
  }

  function handlePointerEnd(e) {
    if (!swallowEvent(e)) return;
  }

  function handleBlockedEvent(e) {
    swallowEvent(e);
  }

  function handleClick(e) {
    if (!swallowEvent(e)) return;
    updateHoverFromEvent(e);
    emitCurrent();
  }

  document.addEventListener('touchstart', handleTouchStart, { capture: true, passive: false });
  document.addEventListener('touchmove', handleTouchMove, { capture: true, passive: false });
  document.addEventListener('touchend', handleTouchEnd, { capture: true, passive: false });
  document.addEventListener('pointerdown', handlePointerStart, { capture: true, passive: false });
  document.addEventListener('pointerup', handlePointerEnd, { capture: true, passive: false });
  document.addEventListener('mousedown', handlePointerStart, { capture: true, passive: false });
  document.addEventListener('mouseup', handlePointerEnd, { capture: true, passive: false });
  document.addEventListener('mousemove', handleMouseMove, { capture: true, passive: false });
  document.addEventListener('click', handleClick, { capture: true, passive: false });
  document.addEventListener('dblclick', handleBlockedEvent, { capture: true, passive: false });
  document.addEventListener('auxclick', handleBlockedEvent, { capture: true, passive: false });
  document.addEventListener('contextmenu', handleBlockedEvent, { capture: true, passive: false });
  // Session boxes use viewport (fixed) coordinates, so they must be repainted
  // when the page scrolls or the viewport resizes — independent of picker state.
  window.addEventListener('scroll', renderSessionHighlights, true);
  window.addEventListener('resize', renderSessionHighlights, true);

  document.addEventListener('keydown', function (e) {
    if (!active) return;
    if (e.key === 'Tab' && hoverCandidates.length > 1) {
      e.preventDefault();
      e.stopPropagation();
      if (e.stopImmediatePropagation) e.stopImmediatePropagation();
      hoverIndex = e.shiftKey
        ? (hoverIndex - 1 + hoverCandidates.length) % hoverCandidates.length
        : (hoverIndex + 1) % hoverCandidates.length;
      highlightCurrent();
      return;
    }
    if (e.key === 'Escape') {
      window.__infocutterPicker.stop();
    }
  }, { capture: true, passive: false });

  window.__infocutterPicker = {
    start: function () {
      active = true;
      document.documentElement.style.cursor = 'crosshair';
      ensureOverlay();
    },
    stop: function () {
      active = false;
      hoverCandidates = [];
      hoverIndex = 0;
      lastPoint = null;
      removeOverlay();
      document.documentElement.style.cursor = '';
    },
    moveToParent: function () {
      var current = hoverCurrentTarget();
      if (current && current.parentElement && current.parentElement.tagName !== 'BODY') {
        hoverCandidates = [current.parentElement];
        hoverIndex = 0;
        highlightCurrent();
      }
    },
    moveToFirstChild: function () {
      var current = hoverCurrentTarget();
      if (current && current.firstElementChild) {
        hoverCandidates = [current.firstElementChild];
        hoverIndex = 0;
        highlightCurrent();
      }
    },
    countMatches: function (sel) {
      return matchCountForSelector(sel);
    },
    pickSelector: function (sel) {
      var el;
      try { el = document.querySelector(sel); } catch (e) { return false; }
      if (!el) return false;
      ensureOverlay();
      hoverCandidates = [el];
      hoverIndex = 0;
      lastPoint = null;
      highlightCurrent();
      emitCurrent();
      return true;
    },
    // Paint persistent numbered boxes for the current selection session.
    // entries: [{ selector, index, name }]. index drives the badge number and
    // the palette color; missing index falls back to position. Returns the
    // count actually rendered. Idempotent — call again to refresh after any
    // session change (add / remove / refine).
    applySessionHighlights: function (entries) {
      sessionEntries = (Array.isArray(entries) ? entries : [])
        .filter(function (e) { return e && typeof e.selector === 'string' && e.selector.trim(); })
        .map(function (e, i) {
          return {
            selector: e.selector,
            index: (typeof e.index === 'number' && e.index > 0) ? e.index : i + 1,
            name: e.name || ''
          };
        });
      if (sessionEntries.length === 0) {
        if (sessionLayer) sessionLayer.replaceChildren();
        return 0;
      }
      ensureSessionLayer();
      renderSessionHighlights();
      return sessionEntries.length;
    },
    clearSessionHighlights: function () {
      sessionEntries = [];
      removeSessionLayer();
    }
  };
})();
''';

/// assets/js/keyword_capture.js
const String keywordCaptureUserScriptSource = r'''
(function () {
  if (window.__infocutterKeywordCapture) return;
  var active = false; var lastSent = ''; var timer = null;
  function emit() {
    if (!active) return;
    var sel = window.getSelection ? String(window.getSelection()).replace(/\s+/g, ' ').trim() : '';
    if (!sel || sel === lastSent) return;
    lastSent = sel;
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('infocutter.keywordResult', sel);
    }
  }
  function schedule() { if (timer) clearTimeout(timer); timer = setTimeout(emit, 250); }
  document.addEventListener('mouseup', function () { if (active) schedule(); }, true);
  document.addEventListener('touchend', function () { if (active) schedule(); }, true);
  document.addEventListener('selectionchange', function () { if (active) schedule(); }, true);
  window.__infocutterKeywordCapture = {
    start: function () { active = true; lastSent = ''; },
    stop: function () { active = false; lastSent = ''; }
  };
})();
''';

/// assets/js/lazy_image_promote.js
const String lazyImagePromoteUserScriptSource = r'''
// Infocutter: promote lazy-load attributes so placeholders do not stay broken.
// m.naver.com and similar mobile sites often set a tiny placeholder src plus
// data-src / CSS background; WebView timing can leave "?" icons forever.
(function () {
  if (window.__infocutterLazyImagePromote) {
    return;
  }
  window.__infocutterLazyImagePromote = true;

  var ATTRS = [
    'data-src',
    'data-original',
    'data-lazy-src',
    'data-lazy',
    'data-url',
    'data-img',
    'data-image',
    'data-img-src',
    'data-image-src',
    'data-original-src',
    'data-lazysrc',
    'data-src-mobile',
    'data-bg',
    'data-background',
    'data-background-image',
  ];
  var SRCSET_ATTRS = [
    'data-srcset',
    'data-lazy-srcset',
    'data-original-set',
  ];

  function isPlaceholderSrc(src) {
    if (!src) return true;
    var s = String(src).trim().toLowerCase();
    if (s === '' || s === 'about:blank' || s === 'null' || s === 'undefined') {
      return true;
    }
    if (s.indexOf('data:image') === 0) return true;
    if (s.indexOf('blank.') !== -1 || s.indexOf('placeholder') !== -1) {
      return true;
    }
    if (s.indexOf('1x1') !== -1 || s.indexOf('spacer') !== -1) return true;
    // transparent GIF common path fragments
    if (s.indexOf('transparent') !== -1 && s.indexOf('.gif') !== -1) {
      return true;
    }
    return false;
  }

  function firstAttr(el, names) {
    for (var i = 0; i < names.length; i++) {
      var v = el.getAttribute(names[i]);
      if (v && String(v).trim()) return String(v).trim();
    }
    return null;
  }

  function promoteImg(img) {
    if (!img || img.tagName !== 'IMG') return;
    var src = img.getAttribute('src');
    if (isPlaceholderSrc(src)) {
      var next = firstAttr(img, ATTRS);
      if (next && next.indexOf('data:') !== 0) {
        img.setAttribute('src', next);
      }
    }
    if (!img.getAttribute('srcset')) {
      var set = firstAttr(img, SRCSET_ATTRS);
      if (set) img.setAttribute('srcset', set);
    }
    if (img.getAttribute('loading') === 'lazy') {
      img.setAttribute('loading', 'eager');
    }
    // Naver 등 사이트 자체 lazy 옵저버가 안 도는 경우 대비: 로드 실패 시 data-* 재시도
    if (!img.__infocutterLazyErrBound) {
      img.__infocutterLazyErrBound = true;
      img.addEventListener(
        'error',
        function () {
          var retry = firstAttr(img, ATTRS);
          var cur = img.getAttribute('src');
          if (retry && retry !== cur && retry.indexOf('data:') !== 0) {
            img.setAttribute('src', retry);
          }
        },
        { once: true }
      );
    }
    // Force decode attempt for already-in-DOM images.
    try {
      if (typeof img.decode === 'function') {
        img.decode().catch(function () {});
      }
    } catch (e) {}
  }

  function promoteBg(el) {
    if (!el || el.nodeType !== 1) return;
    var bg = firstAttr(el, [
      'data-bg',
      'data-background',
      'data-background-image',
      'data-lazy-background',
      'data-src',
    ]);
    if (!bg) return;
    var style = el.getAttribute('style') || '';
    if (style.indexOf('background') !== -1 && style.indexOf('url(') !== -1) {
      return;
    }
    var url = bg;
    if (url.indexOf('url(') === -1) {
      url = "url('" + bg.replace(/'/g, "\\'") + "')";
    }
    el.style.backgroundImage = url;
  }

  function promoteSource(source) {
    if (!source || source.tagName !== 'SOURCE') return;
    if (!source.getAttribute('srcset')) {
      var set = firstAttr(source, SRCSET_ATTRS.concat(['data-src']));
      if (set) source.setAttribute('srcset', set);
    }
  }

  function promote(el) {
    if (!el || el.nodeType !== 1) return;
    if (el.tagName === 'IMG') promoteImg(el);
    else if (el.tagName === 'SOURCE') promoteSource(el);
    else promoteBg(el);
  }

  function scan(root) {
    var scope = root || document;
    if (!scope.querySelectorAll) return;
    var imgs = scope.querySelectorAll('img');
    for (var i = 0; i < imgs.length; i++) promoteImg(imgs[i]);
    var sources = scope.querySelectorAll('source');
    for (var s = 0; s < sources.length; s++) promoteSource(sources[s]);
    var bgs = scope.querySelectorAll(
      '[data-bg],[data-background],[data-background-image],[data-lazy-background]'
    );
    for (var b = 0; b < bgs.length; b++) promoteBg(bgs[b]);
  }

  function nudgePageLazy() {
    // 페이지 자체 IntersectionObserver / scroll-lazy 를 깨운다.
    try {
      window.dispatchEvent(new Event('scroll'));
      window.dispatchEvent(new Event('resize'));
      if (document.documentElement) {
        document.documentElement.dispatchEvent(new Event('scroll'));
      }
    } catch (e) {}
  }

  function boot() {
    scan(document);
    nudgePageLazy();
    // Retry a few times — SPA/lazy modules mount after first paint.
    var tries = 0;
    var timer = setInterval(function () {
      scan(document);
      nudgePageLazy();
      tries += 1;
      if (tries >= 12) clearInterval(timer);
    }, 350);

    if (typeof MutationObserver === 'undefined') return;
    var mo = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === 'attributes' && m.target) {
          promote(m.target);
        }
        if (m.addedNodes) {
          for (var j = 0; j < m.addedNodes.length; j++) {
            var n = m.addedNodes[j];
            if (n.nodeType !== 1) continue;
            promote(n);
            if (n.querySelectorAll) scan(n);
          }
        }
      }
    });
    var root = document.documentElement || document.body;
    if (root) {
      mo.observe(root, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ATTRS.concat(SRCSET_ATTRS).concat([
          'src',
          'srcset',
          'style',
          'class',
        ]),
      });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
''';
