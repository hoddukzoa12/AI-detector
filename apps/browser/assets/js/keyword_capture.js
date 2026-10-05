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
