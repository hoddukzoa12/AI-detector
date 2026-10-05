// assets/js/*.js 회귀 그물. 의존성 없이 node 만으로 돈다.
//
//   node tool/js_test.mjs
//
// 이 JS 는 WebView 안에서만 실행되므로 Dart 테스트가 닿지 못한다. 문법 오류나
// 전역 노출 누락이 생겨도 flutter analyze 와 flutter test 는 전부 초록이고,
// 앱은 실기기에서 조용히 망가진다. 그 구멍을 막는다.
//
// 한계: 실제 DOM 이 없으므로 셀렉터 스코어링 같은 알고리즘 자체는 검증하지 않는다.
// 여기서 잡는 것은 "스크립트가 파싱되고 기대한 전역을 노출하는가" 까지다.

import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';

let passed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed += 1;
    console.log(`  ok  ${name}`);
  } catch (error) {
    failures.push({ name, error });
    console.log(`  FAIL ${name}\n       ${error.message}`);
  }
}

/** DOM 없이 스크립트를 끝까지 실행시키기 위한 최소 스텁. */
function makeSandbox() {
  const node = () => ({
    style: {},
    setAttribute() {},
    removeAttribute() {},
    getAttribute: () => null,
    appendChild() {},
    removeChild() {},
    addEventListener() {},
    removeEventListener() {},
    querySelectorAll: () => [],
    getBoundingClientRect: () => ({ top: 0, left: 0, width: 0, height: 0 }),
    getClientRects: () => [],
    classList: { add() {}, remove() {} },
    isConnected: false,
    parentNode: null,
    firstElementChild: null,
    nextElementSibling: null,
  });

  const documentStub = {
    ...node(),
    documentElement: node(),
    head: node(),
    body: node(),
    createElement: () => node(),
    getElementById: () => null,
    createTreeWalker: () => ({ nextNode: () => null }),
  };

  const windowStub = {
    document: documentStub,
    location: { origin: 'https://example.com', pathname: '/' },
    addEventListener() {},
    removeEventListener() {},
    getComputedStyle: () => ({ getPropertyValue: () => '' }),
    setTimeout: () => 0,
    clearTimeout() {},
    requestAnimationFrame: () => 0,
    MutationObserver: class {
      observe() {}
      disconnect() {}
    },
    flutter_inappwebview: { callHandler: () => Promise.resolve() },
  };
  windowStub.window = windowStub;
  windowStub.top = windowStub;
  windowStub.self = windowStub;

  return {
    ...windowStub,
    globalThis: windowStub,
    Set,
    Array,
    Math,
    JSON,
    String,
    Number,
    Boolean,
    Object,
    RegExp,
    Error,
    console,
  };
}

function load(file) {
  const source = readFileSync(new URL(`../assets/js/${file}`, import.meta.url), 'utf8');
  const sandbox = makeSandbox();
  runInNewContext(source, sandbox, { filename: file });
  // 스크립트는 `window.__x = ...` 로 붙는다. sandbox.window 가 그 window 다.
  return sandbox.window;
}

console.log('assets/js 회귀 그물');

test('infocutter_runtime.js 가 파싱되고 __infocutterRuntime 을 노출한다', () => {
  const sandbox = load('infocutter_runtime.js');
  assert.ok(sandbox.__infocutterRuntime, '__infocutterRuntime 전역이 없다');
  assert.equal(typeof sandbox.__infocutterRuntime.apply, 'function');
});

test('picker.js 가 파싱되고 __infocutterPicker 를 노출한다', () => {
  const sandbox = load('picker.js');
  assert.ok(sandbox.__infocutterPicker, '__infocutterPicker 전역이 없다');
  assert.equal(typeof sandbox.__infocutterPicker.start, 'function');
  assert.equal(typeof sandbox.__infocutterPicker.stop, 'function');
});

test('keyword_capture.js 가 파싱되고 __infocutterKeywordCapture 를 노출한다', () => {
  const sandbox = load('keyword_capture.js');
  assert.ok(
    sandbox.__infocutterKeywordCapture,
    '__infocutterKeywordCapture 전역이 없다',
  );
});

test('생성된 .g.dart 가 assets/js 와 같다', () => {
  // .g.dart 만 손으로 고치면 다음 생성 때 조용히 되돌아간다. 어긋남을 여기서 잡는다.
  // Dart 를 부르지 않는 이유: 이 검사 하나 때문에 CI 잡이 Dart 패키지 해석에
  // 묶이면 실패 지점이 늘어난다. 같은 규칙을 여기서 직접 검증한다.
  const generated = readFileSync(
    new URL('../lib/infocutter/generated/user_scripts.g.dart', import.meta.url),
    'utf8',
  );
  const pairs = [
    ['infocutter_runtime.js', 'infocutterRuntimeUserScriptSource'],
    ['picker.js', 'pickerUserScriptSource'],
    ['keyword_capture.js', 'keywordCaptureUserScriptSource'],
  ];
  for (const [file, name] of pairs) {
    const body = readFileSync(new URL(`../assets/js/${file}`, import.meta.url), 'utf8');
    const marker = `const String ${name} = r'''\n`;
    const start = generated.indexOf(marker);
    assert.ok(start >= 0, `${name} 이 .g.dart 에 없다`);
    const from = start + marker.length;
    const end = generated.indexOf("\n''';", from);
    assert.ok(end > from, `${name} 의 raw string 이 닫히지 않았다`);
    assert.equal(
      generated.slice(from, end) + '\n',
      body,
      `${file} 와 .g.dart 의 ${name} 이 다르다. `
        + 'dart run tool/generate_user_scripts.dart 를 실행할 것',
    );
  }
});

test('삼중 따옴표가 없다 (Dart raw string 을 깨뜨린다)', () => {
  for (const file of ['infocutter_runtime.js', 'picker.js', 'keyword_capture.js']) {
    const source = readFileSync(new URL(`../assets/js/${file}`, import.meta.url), 'utf8');
    assert.ok(!source.includes("'''"), `${file} 에 삼중 따옴표가 있다`);
  }
});

console.log(`\n${passed} passed, ${failures.length} failed`);
process.exit(failures.length === 0 ? 0 : 1);
