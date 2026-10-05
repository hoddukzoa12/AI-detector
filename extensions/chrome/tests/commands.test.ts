import test from "node:test";
import assert from "node:assert/strict";

import { commandIds, toggleCommandMessage } from "../src/shared/commands.js";
import { messageTypes } from "../src/shared/messages.js";

void test("toggleCommandMessage maps toggle commands to their message types", () => {
  assert.equal(toggleCommandMessage(commandIds.toggleGlobal), messageTypes.toggleGlobalEnabled);
  assert.equal(toggleCommandMessage(commandIds.toggleSiteProfile), messageTypes.toggleSiteEnabled);
  assert.equal(toggleCommandMessage(commandIds.togglePeek), messageTypes.togglePeek);
});

void test("toggleCommandMessage returns null for non-toggle and unknown ids", () => {
  assert.equal(toggleCommandMessage(commandIds.launchPicker), null);
  assert.equal(toggleCommandMessage("nope"), null);
});
