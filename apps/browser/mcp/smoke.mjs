#!/usr/bin/env node
// End-to-end smoke test: spawns the MCP server as a real MCP client (over
// stdio) and drives the live app through it. Requires the app running in debug
// mode (bridge on 127.0.0.1:47821).
//
//   node smoke.mjs

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const transport = new StdioClientTransport({
  command: 'node',
  args: ['index.mjs'],
  env: { ...process.env },
});
const client = new Client({ name: 'smoke', version: '0.0.0' }, { capabilities: {} });

const text = (r) => (r.content?.[0]?.text ?? JSON.stringify(r)).slice(0, 240);

await client.connect(transport);
try {
  const { tools } = await client.listTools();
  console.log('TOOLS:', tools.map((t) => t.name).join(', '));

  const snap = await client.callTool({ name: 'snapshot', arguments: {} });
  const s = JSON.parse(snap.content[0].text);
  console.log('snapshot ok:', !!s.capabilities, '| caps:', (s.capabilities || []).length);

  console.log('new_tab:', text(await client.callTool({ name: 'new_tab', arguments: { target: 'example.com' } })));
  console.log('wait_for_load:', text(await client.callTool({ name: 'wait_for_load', arguments: { timeoutMs: 20000 } })));
  console.log('get_text h1:', text(await client.callTool({ name: 'get_text', arguments: { selector: 'h1' } })));
  console.log('eval_js title:', text(await client.callTool({ name: 'eval_js', arguments: { source: 'document.title' } })));
  console.log('infocutter_pick a:', text(await client.callTool({ name: 'infocutter_pick', arguments: { selector: 'a' } })));

  const after = JSON.parse((await client.callTool({ name: 'snapshot', arguments: {} })).content[0].text);
  console.log('openPanel after pick:', after.infocutter?.openPanel);
  console.log(after.infocutter?.openPanel === 'block' ? '\nSMOKE PASS ✅ MCP -> bridge -> app drives the picker' : '\nSMOKE: openPanel not block');
} finally {
  await client.close();
}
