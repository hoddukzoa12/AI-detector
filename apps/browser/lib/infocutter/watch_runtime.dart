const String infocutterWatchUserScriptSource = r'''
(function () {
  if (window.__infocutterWatch) return;

  var HIDDEN_ATTR = 'data-infocutter-watch-hidden';
  var STYLE_ID = '__infocutter_watch_style';
  var state = {
    globalEnabled: true,
    autoMask: true,
    terms: []
  };
  var observer = null;
  var renderTimer = null;
  var reported = new Set();

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

  function normalizedText(value) {
    return String(value || '').replace(/\s+/g, ' ').trim();
  }

  function terms() {
    if (!state.globalEnabled || !Array.isArray(state.terms)) return [];
    return state.terms.filter(function (entry) {
      return entry &&
        typeof entry.term === 'string' &&
        entry.term.trim().length >= 2;
    });
  }

  function closestBlock(node) {
    var element = node && node.nodeType === 3 ? node.parentElement : node;
    while (element && element !== document.body && element !== document.documentElement) {
      var tag = element.tagName ? element.tagName.toLowerCase() : '';
      if (/^(p|li|article|section|aside|div|td|th|blockquote|figcaption|h[1-6])$/.test(tag)) {
        return element;
      }
      element = element.parentElement;
    }
    return node && node.parentElement ? node.parentElement : null;
  }

  function shouldSkip(node) {
    var parent = node.parentElement;
    if (!parent) return true;
    var tag = parent.tagName ? parent.tagName.toLowerCase() : '';
    return /^(script|style|noscript|textarea|input|select)$/.test(tag);
  }

  function reportDetection(entry, text, block) {
    var snippet = normalizedText(text).slice(0, 240);
    var key = window.location.href + '|' + entry.targetId + '|' + entry.term + '|' + snippet;
    if (reported.has(key)) return;
    reported.add(key);
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('infocutter.watchDetection', {
        targetId: entry.targetId || '',
        term: entry.term,
        url: window.location.href,
        pageTitle: document.title || '',
        matchedText: snippet,
        tag: block && block.tagName ? block.tagName.toLowerCase() : ''
      });
    }
  }

  function scanNow() {
    ensureStyle();
    clearMarkers();
    var activeTerms = terms();
    if (activeTerms.length === 0) return;

    var walker = document.createTreeWalker(
      document.body || document.documentElement,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: function (node) {
          if (shouldSkip(node)) return NodeFilter.FILTER_REJECT;
          return normalizedText(node.nodeValue).length > 0
            ? NodeFilter.FILTER_ACCEPT
            : NodeFilter.FILTER_SKIP;
        }
      }
    );

    var node;
    while ((node = walker.nextNode())) {
      var text = normalizedText(node.nodeValue);
      var lower = text.toLowerCase();
      for (var i = 0; i < activeTerms.length; i++) {
        var entry = activeTerms[i];
        if (lower.indexOf(String(entry.term).toLowerCase()) === -1) continue;
        var block = closestBlock(node);
        reportDetection(entry, text, block);
        if (state.autoMask && block) {
          block.setAttribute(HIDDEN_ATTR, 'true');
        }
        break;
      }
    }
  }

  function scheduleScan() {
    if (renderTimer !== null) {
      window.clearTimeout(renderTimer);
    }
    renderTimer = window.setTimeout(function () {
      renderTimer = null;
      scanNow();
    }, 180);
  }

  function ensureObserver() {
    if (observer) return;
    observer = new MutationObserver(scheduleScan);
    observer.observe(document.documentElement, {
      characterData: true,
      childList: true,
      subtree: true
    });
  }

  window.__infocutterWatch = {
    apply: function (nextState) {
      state = nextState || state;
      ensureObserver();
      scanNow();
    },
    scan: function () {
      scanNow();
    },
    countMasked: function () {
      return document.querySelectorAll('[' + HIDDEN_ATTR + ']').length;
    }
  };

  ensureObserver();
})();
''';
