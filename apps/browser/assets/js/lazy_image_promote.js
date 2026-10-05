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
