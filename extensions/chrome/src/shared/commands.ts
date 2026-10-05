import { messageTypes } from "./messages.js";
import type { MessageType } from "./messages.js";

export const commandIds = {
  launchPicker: "launch-picker",
  toggleGlobal: "toggle-global",
  toggleSiteProfile: "toggle-site-profile",
  togglePeek: "toggle-peek"
} as const;

export type CommandId = (typeof commandIds)[keyof typeof commandIds];

export function toggleCommandMessage(commandId: string): MessageType | null {
  switch (commandId) {
    case commandIds.toggleGlobal:
      return messageTypes.toggleGlobalEnabled;
    case commandIds.toggleSiteProfile:
      return messageTypes.toggleSiteEnabled;
    case commandIds.togglePeek:
      return messageTypes.togglePeek;
    default:
      return null;
  }
}
