# Infocutter Automation — MCP server

Exposes the Infocutter app's debug automation bridge as **MCP tools**, so an MCP
client (Claude Code, Claude Desktop, Cursor, …) can drive the running app
Playwright-style: `navigate`, `click`, `fill`, `get_text`, `wait_for_selector`,
`eval_js`, `screenshot`, plus Infocutter-specific `infocutter_pick`,
`infocutter_open_panel`, `infocutter_add_block_rule`, and a generic `run`
escape-hatch for any of the ~50 capabilities.

```
MCP client  ──stdio/JSON-RPC──▶  this server  ──HTTP 127.0.0.1──▶  app (AppAutomationBridge)
```

## Prerequisites

1. **Run the app in debug mode** (the bridge is debug-only and starts itself):
   ```bash
   cd ..   # apps/infocutter-app
   fvm flutter run -d macos --debug
   ```
   The bridge listens on `http://127.0.0.1:47821`. Optional bearer token:
   launch with `--dart-define=INFOCUTTER_AUTOMATION_TOKEN=<token>` and set the
   same `INFOCUTTER_AUTOMATION_TOKEN` env for this server.
2. **Node 18+** (uses global `fetch`).
3. Install deps:
   ```bash
   npm install
   ```

On a **physical device** the app's `127.0.0.1` is the device's loopback, so
forward the port to the host first:
- Android: `adb reverse tcp:47821 tcp:47821`
- iOS: `iproxy 47821 47821` (libimobiledevice)

## Verify end-to-end

```bash
node smoke.mjs
# TOOLS: snapshot, new_tab, navigate, ...
# ... infocutter_pick a ... openPanel after pick: block
# SMOKE PASS ✅ MCP -> bridge -> app drives the picker
```

## Wire into a client

**Claude Code** — `.mcp.json` in the project root (or `claude mcp add`):
```json
{
  "mcpServers": {
    "infocutter": {
      "command": "node",
      "args": ["/ABS/PATH/apps/infocutter-app/mcp/index.mjs"],
      "env": { "INFOCUTTER_BRIDGE_URL": "http://127.0.0.1:47821" }
    }
  }
}
```

**Claude Desktop / Cursor** — same object under `mcpServers` in their config
(`claude_desktop_config.json` / Cursor MCP settings). Add
`"INFOCUTTER_AUTOMATION_TOKEN": "<token>"` to `env` if the app uses one.

## Tools

| Tool | Bridge action | Notes |
|---|---|---|
| `snapshot` | `GET /state` | tabs, url, rules, open panel, capabilities |
| `new_tab` / `navigate` | `tab.open` / `page.load` | start here; page tools need a loaded tab |
| `wait_for_load` / `wait_for_selector` | `page.waitFor*` | |
| `click` / `fill` / `get_text` | `page.click/fill/getText` | selector-based |
| `eval_js` | `page.evalJs` | universal primitive |
| `screenshot` | `page.screenshot` | returned as an image |
| `infocutter_pick` | `infocutter.pick` | deterministic, click-free element pick |
| `infocutter_open_panel` | `infocutter.openPanel` | block/keyword/ai/watch/network/manage/settings |
| `infocutter_add_block_rule` | `infocutter.addBlockRule` | |
| `infocutter_list_profiles` | `infocutter.listProfiles` | |
| `run` | any | `{action, args}` for the full surface |

## Security

Debug-only, loopback-bound. `page.evalJs` runs arbitrary JS in whatever page the
WebView is on — treat the bridge port as sensitive (use the token, never expose
the port beyond loopback). See the app's `infocutter-app-automation` skill for
the full guardrail model.
