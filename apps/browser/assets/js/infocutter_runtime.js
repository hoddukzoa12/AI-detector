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
