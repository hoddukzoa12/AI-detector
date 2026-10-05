#!/usr/bin/env node
// MCP server bridging an MCP client (Claude Desktop / Cursor / Claude Code) to
// the Infocutter app's debug automation bridge (AppAutomationBridge) over HTTP.
//
// Transport chain:
//   MCP client  --stdio/JSON-RPC-->  THIS server  --HTTP loopback-->  app bridge
//
// Config (env):
//   INFOCUTTER_BRIDGE_URL          default http://127.0.0.1:47821
//   INFOCUTTER_AUTOMATION_TOKEN    bearer token if the app was launched with one
//
// The app must be running in debug mode (the bridge is debug-only). On a
// physical device, set up `adb reverse tcp:47821 tcp:47821` (Android) or an
// iproxy/usbmux port map (iOS) first.

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

const BRIDGE = process.env.INFOCUTTER_BRIDGE_URL || 'http://127.0.0.1:47821';
const TOKEN = process.env.INFOCUTTER_AUTOMATION_TOKEN || '';

async function call(method, path, body) {
  const headers = { 'Content-Type': 'application/json' };
  if (TOKEN) headers.Authorization = `Bearer ${TOKEN}`;
  let res;
  try {
    res = await fetch(BRIDGE + path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (e) {
    return {
      ok: false,
      error: `cannot reach app bridge at ${BRIDGE} (${e.message}). Is the app running in debug mode? On a device, did you set up adb reverse / iproxy?`,
    };
  }
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return { ok: false, error: text || `HTTP ${res.status}` };
  }
}

const run = (action, args = {}) => call('POST', '/run', { action, args });
const snapshot = () => call('GET', '/state');

const SEL = { selector: { type: 'string', description: 'CSS selector' } };
const TIMEOUT = {
  timeoutMs: { type: 'number', description: 'timeout in milliseconds' },
};

// Curated, well-typed tools (the Playwright-style core) + a generic escape
// hatch. Every tool maps to one bridge action via toAction().
const TOOLS = [
  {
    name: 'snapshot',
    description:
      'Read the full app state: tabs, current url, infocutter rules/open-panel, AI config, and the list of every automation capability. Call this first to orient.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'new_tab',
    description:
      'Open a new browser tab at a URL or search term (creates and loads it). Use this to start, since page commands need a loaded tab.',
    inputSchema: {
      type: 'object',
      properties: { target: { type: 'string', description: 'URL or search query' } },
      required: ['target'],
    },
  },
  {
    name: 'navigate',
    description: 'Load a URL or search term in the CURRENT tab.',
    inputSchema: {
      type: 'object',
      properties: { target: { type: 'string' } },
      required: ['target'],
    },
  },
  {
    name: 'wait_for_load',
    description: 'Wait until the current page finishes loading (document load).',
    inputSchema: { type: 'object', properties: { ...TIMEOUT } },
  },
  {
    name: 'wait_for_selector',
    description: 'Wait until an element matching the selector appears.',
    inputSchema: {
      type: 'object',
      properties: { ...SEL, ...TIMEOUT },
      required: ['selector'],
    },
  },
  {
    name: 'click',
    description: 'Click the first element matching the CSS selector.',
    inputSchema: { type: 'object', properties: { ...SEL }, required: ['selector'] },
  },
  {
    name: 'fill',
    description: 'Set the value of an input/textarea matching the selector (fires input/change).',
    inputSchema: {
      type: 'object',
      properties: { ...SEL, value: { type: 'string' } },
      required: ['selector', 'value'],
    },
  },
  {
    name: 'get_text',
    description: 'Return innerText of the element matching the selector.',
    inputSchema: { type: 'object', properties: { ...SEL }, required: ['selector'] },
  },
  {
    name: 'eval_js',
    description:
      'Evaluate arbitrary JavaScript in the current page and return its value. The universal primitive — anything Playwright evaluate() does.',
    inputSchema: {
      type: 'object',
      properties: { source: { type: 'string', description: 'JS expression/IIFE' } },
      required: ['source'],
    },
  },
  {
    name: 'screenshot',
    description: 'Capture a PNG screenshot of the current WebView page.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'infocutter_pick',
    description:
      'Infocutter: select a page element by selector (deterministic, click-free) and open its refine/save panel — the picker flow driven programmatically.',
    inputSchema: { type: 'object', properties: { ...SEL }, required: ['selector'] },
  },
  {
    name: 'infocutter_open_panel',
    description: 'Infocutter: open a sidebar panel by mode.',
    inputSchema: {
      type: 'object',
      properties: {
        mode: {
          type: 'string',
          enum: ['block', 'keyword', 'ai', 'watch', 'network', 'manage', 'settings'],
        },
      },
      required: ['mode'],
    },
  },
  {
    name: 'infocutter_add_block_rule',
    description: 'Infocutter: add a hide rule (CSS selector) for the current site.',
    inputSchema: {
      type: 'object',
      properties: { ...SEL, cardName: { type: 'string' } },
      required: ['selector'],
    },
  },
  {
    name: 'infocutter_list_profiles',
    description: 'Infocutter: list saved profiles with their cards/rules (selectors, ids).',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'run',
    description:
      'Escape hatch: invoke any automation capability directly. action = capability name (see snapshot.capabilities), args = its arguments object.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string' },
        args: { type: 'object' },
      },
      required: ['action'],
    },
  },
];

function toAction(name, a = {}) {
  switch (name) {
    case 'snapshot':
      return null; // handled specially
    case 'new_tab':
      return ['tab.open', { target: a.target }];
    case 'navigate':
      return ['page.load', { target: a.target }];
    case 'wait_for_load':
      return ['page.waitForLoad', a.timeoutMs ? { timeoutMs: a.timeoutMs } : {}];
    case 'wait_for_selector':
      return ['page.waitForSelector', { selector: a.selector, ...(a.timeoutMs ? { timeoutMs: a.timeoutMs } : {}) }];
    case 'click':
      return ['page.click', { selector: a.selector }];
    case 'fill':
      return ['page.fill', { selector: a.selector, value: a.value }];
    case 'get_text':
      return ['page.getText', { selector: a.selector }];
    case 'eval_js':
      return ['page.evalJs', { source: a.source }];
    case 'screenshot':
      return ['page.screenshot', {}];
    case 'infocutter_pick':
      return ['infocutter.pick', { selector: a.selector }];
    case 'infocutter_open_panel':
      return ['infocutter.openPanel', { mode: a.mode }];
    case 'infocutter_add_block_rule':
      return ['infocutter.addBlockRule', { selector: a.selector, ...(a.cardName ? { cardName: a.cardName } : {}) }];
    case 'infocutter_list_profiles':
      return ['infocutter.listProfiles', {}];
    case 'run':
      return [a.action, a.args ?? {}];
    default:
      return null;
  }
}

const server = new Server(
  { name: 'infocutter-automation', version: '0.1.0' },
  { capabilities: { tools: {}, resources: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args = {} } = req.params;

  if (name === 'snapshot') {
    const state = await snapshot();
    return { content: [{ type: 'text', text: JSON.stringify(state) }], isError: state.ok === false };
  }

  const mapped = toAction(name, args);
  if (!mapped || !mapped[0]) {
    return { content: [{ type: 'text', text: `unknown tool: ${name}` }], isError: true };
  }

  const result = await run(mapped[0], mapped[1]);

  // Return screenshots as image content so MCP clients can view them.
  if (name === 'screenshot' && result.ok && result.base64Png) {
    return {
      content: [{ type: 'image', data: result.base64Png, mimeType: 'image/png' }],
      isError: false,
    };
  }

  return { content: [{ type: 'text', text: JSON.stringify(result) }], isError: result.ok === false };
});

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: 'infocutter://state',
      name: 'Infocutter app state snapshot',
      description: 'Full app/automation state (tabs, rules, capabilities).',
      mimeType: 'application/json',
    },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (req) => {
  if (req.params.uri === 'infocutter://state') {
    const state = await snapshot();
    return {
      contents: [
        { uri: req.params.uri, mimeType: 'application/json', text: JSON.stringify(state) },
      ],
    };
  }
  throw new Error(`unknown resource: ${req.params.uri}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
// Stderr only — stdout is the JSON-RPC channel.
console.error(`infocutter-automation MCP server ready (bridge: ${BRIDGE}${TOKEN ? ', token set' : ''})`);
