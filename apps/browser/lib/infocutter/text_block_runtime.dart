const String infocutterTextBlockUserScriptSource = r'''
(function () {
  if (window.__infocutterTextBlocks) return;

  var HIDDEN_ATTR = 'data-infocutter-text-block-hidden';
  var STYLE_ID = '__infocutter_text_block_style';
  var state = {
    globalEnabled: false,
    profileEnabled: false,
    hiddenObjectTags: ['ad'],
    rules: []
  };
  var observer = null;
  var renderTimer = null;

  function ensureStyle() {
    var existing = document.getElementById(STYLE_ID);
    if (existing) return existing;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = '[' + HIDDEN_ATTR + '] { display: none !important; }';
    (document.head || document.documentElement).appendChild(style);
    return style;
  }

  function normalizeText(value) {
    return String(value || '').replace(/\s+/g, ' ').trim().toLowerCase();
  }

  function stableClasses(element) {
    if (!element || !element.classList) return [];
    return Array.prototype.slice.call(element.classList)
      .filter(function (name) {
        return !/^(active|current|hover|focus|selected|open|show|hide|hidden)$/.test(name);
      })
      .slice(0, 2)
      .sort();
  }

  function fingerprint(element) {
    if (!element) return '';
    var parentTag = element.parentElement && element.parentElement.localName
      ? element.parentElement.localName
      : 'root';
    var classes = stableClasses(element).join('.') || '_';
    var children = Array.prototype.slice.call(element.children || [])
      .slice(0, 4)
      .map(function (child) { return child.localName; })
      .join(',') || '_';
    return [element.localName, classes, parentTag, children].join('|');
  }

  function preferredBlockContainer(element) {
    var current = element;
    while (current && current !== document.body && current !== document.documentElement) {
      var tag = current.localName || '';
      if (/^(article|section|aside|li|tr|td|div|p|blockquote)$/.test(tag)) {
        return current;
      }
      current = current.parentElement;
    }
    return element;
  }

  function ignoredTextHost(element) {
    var tag = element && element.localName ? element.localName : '';
    return /^(script|style|noscript|textarea|input|select|option)$/.test(tag);
  }

  function collectTargets(rule) {
    var keyword = normalizeText(rule.keyword);
    if (!keyword) return [];
    var minMatchCount = Math.max(Number(rule.minMatchCount) || 2, 2);
    var expectedFingerprint = rule.fingerprint || null;
    var groups = new Map();

    var walker = document.createTreeWalker(
      document.body || document.documentElement,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: function (node) {
          var parent = node.parentElement;
          if (!parent || ignoredTextHost(parent)) return NodeFilter.FILTER_REJECT;
          var text = normalizeText(node.nodeValue);
          if (!text || text.indexOf(keyword) === -1) return NodeFilter.FILTER_REJECT;
          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );

    var node;
    while ((node = walker.nextNode())) {
      var block = preferredBlockContainer(node.parentElement);
      var fp = fingerprint(block);
      if (expectedFingerprint && fp !== expectedFingerprint) continue;
      var group = groups.get(fp) || [];
      if (group.indexOf(block) === -1) {
        group.push(block);
        groups.set(fp, group);
      }
    }

    var targets = [];
    groups.forEach(function (group) {
      if (group.length >= minMatchCount) {
        targets = targets.concat(group);
      }
    });
    return targets;
  }

  function enabledRules() {
    if (!state.globalEnabled || !state.profileEnabled || !Array.isArray(state.rules)) {
      return [];
    }
    var hiddenTags = new Set(Array.isArray(state.hiddenObjectTags) ? state.hiddenObjectTags : ['ad']);
    return state.rules.filter(function (rule) {
      if (!rule || typeof rule.keyword !== 'string' || rule.keyword.trim().length === 0) {
        return false;
      }
      var tags = Array.isArray(rule.objectTags) ? rule.objectTags : [];
      return tags.some(function (tag) { return hiddenTags.has(tag); });
    });
  }

  function renderNow() {
    ensureStyle();
    var nextTargets = [];
    enabledRules().forEach(function (rule) {
      collectTargets(rule).forEach(function (target) {
        if (nextTargets.indexOf(target) === -1) {
          nextTargets.push(target);
        }
      });
    });

    var nextTargetSet = new Set(nextTargets);
    document.querySelectorAll('[' + HIDDEN_ATTR + ']').forEach(function (element) {
      if (!nextTargetSet.has(element)) {
        element.removeAttribute(HIDDEN_ATTR);
      }
    });
    nextTargets.forEach(function (target) {
      if (target.getAttribute(HIDDEN_ATTR) !== 'true') {
        target.setAttribute(HIDDEN_ATTR, 'true');
      }
    });
  }

  function scheduleRender() {
    if (renderTimer !== null) window.clearTimeout(renderTimer);
    renderTimer = window.setTimeout(function () {
      renderTimer = null;
      renderNow();
    }, 160);
  }

  function ensureObserver() {
    if (observer) return;
    observer = new MutationObserver(scheduleRender);
    observer.observe(document.documentElement, {
      characterData: true,
      childList: true,
      subtree: true
    });
  }

  window.__infocutterTextBlocks = {
    apply: function (nextState) {
      state = nextState || state;
      ensureObserver();
      renderNow();
    },
    render: function () {
      renderNow();
    },
    countHidden: function () {
      return document.querySelectorAll('[' + HIDDEN_ATTR + ']').length;
    }
  };
  ensureObserver();
})();
''';
