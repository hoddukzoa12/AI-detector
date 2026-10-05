import { runDoctor } from "@vibecode/ext-build/doctor";

runDoctor({
  requiredPermissions: ["storage", "tabs", "contextMenus", "scripting", "declarativeNetRequest"]
});
